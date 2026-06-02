function EEG = preprocess_subject(subject, cfg)
% PREPROCESS_SUBJECT  对单个被试/条件运行完整 EEG 预处理。
%                     Full EEG preprocessing for one subject/condition.
%
%   EEG = preprocess_subject(subject, cfg)
%
%   实现的流程 (忠实于原 pipeline) / pipeline (faithful to the original):
%       1. 导入 .mff (EGI)                         pop_mffimport
%       2. 带通滤波 1-40 Hz                         pop_eegfiltnew
%       3. 陷波 48-52 Hz (反向滤波)                 pop_eegfiltnew (revfilt)
%       4. 重采样到 500 Hz                          pop_resample
%       5. clean_rawdata / ASR 清理坏导与坏段        pop_clean_rawdata
%       6. 平均参考                                  pop_reref
%       7. ICA (runica, extended, PCA 降维)         pop_runica
%       8. ICLabel 自动分类                          pop_iclabel
%       9. 按阈值标记伪迹成分并剔除                   pop_icflag + pop_subcomp
%      10. 球面插补被 clean_rawdata 移除的坏导        pop_interp
%      11. (推荐) 插补后再次平均参考                  pop_reref
%
%   输入 / inputs:
%       subject - load_subjects() 返回的单个结构体元素
%       cfg     - pipeline_config()
%
%   输出 / output:
%       EEG     - 预处理后的 EEGLAB 数据集 (同时保存到 cfg.paths.derivatives)

    if nargin < 2, cfg = pipeline_config(); end

    log_msg(cfg, '==== 预处理 / preprocessing: %s ====', subject.id);

    % 已存在且不覆盖则跳过 / skip if already done
    if exist(subject.deriv_path, 'file') == 2 && ~cfg.run.overwrite
        log_msg(cfg, '已存在，跳过 (cfg.run.overwrite=false): %s', subject.deriv_path);
        EEG = pop_loadset('filename', subject.deriv_path);
        return;
    end

    % ---------------------------------------------------------------------
    % 1. 导入 / import
    % ---------------------------------------------------------------------
    if exist(subject.raw_path, 'file') ~= 2 && exist(subject.raw_path, 'dir') ~= 7
        error('preprocess_subject:noRaw', '找不到原始文件: %s', subject.raw_path);
    end
    EEG = import_raw(subject.raw_path, cfg);
    EEG.setname = subject.id;
    EEG = eeg_checkset(EEG);

    % 保存"完整通道"布局，供后续插补使用 /
    % keep the FULL channel layout (before any channel is removed) for interpolation
    full_selected_channels = EEG.chanlocs;
    nChanOrig = EEG.nbchan;
    log_msg(cfg, '导入完成: %d 通道, %g Hz, %.1f s', ...
        EEG.nbchan, EEG.srate, EEG.pnts / EEG.srate);

    % ---------------------------------------------------------------------
    % 2. 带通滤波 1-40 Hz / band-pass
    % ---------------------------------------------------------------------
    EEG = pop_eegfiltnew(EEG, 'locutoff', cfg.filter.bandpass_lo, ...
        'hicutoff', cfg.filter.bandpass_hi, 'plotfreqz', cfg.filter.plotfreqz);

    % ---------------------------------------------------------------------
    % 3. 陷波滤波 48-52 Hz (工频) / notch (line noise), reverse filter
    % ---------------------------------------------------------------------
    EEG = pop_eegfiltnew(EEG, 'locutoff', cfg.filter.notch_lo, ...
        'hicutoff', cfg.filter.notch_hi, 'revfilt', 1, 'plotfreqz', cfg.filter.plotfreqz);

    % ---------------------------------------------------------------------
    % 4. 重采样 / resample
    % ---------------------------------------------------------------------
    if EEG.srate ~= cfg.resample.srate
        EEG = pop_resample(EEG, cfg.resample.srate);
    end

    % ---------------------------------------------------------------------
    % 5. clean_rawdata / ASR  (移除坏导 + 突发伪迹段)
    % ---------------------------------------------------------------------
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion',         cfg.clean.FlatlineCriterion, ...
        'ChannelCriterion',          cfg.clean.ChannelCriterion, ...
        'LineNoiseCriterion',        cfg.clean.LineNoiseCriterion, ...
        'Highpass',                  cfg.clean.Highpass, ...
        'BurstCriterion',            cfg.clean.BurstCriterion, ...
        'WindowCriterion',           cfg.clean.WindowCriterion, ...
        'BurstRejection',            cfg.clean.BurstRejection, ...
        'Distance',                  cfg.clean.Distance, ...
        'WindowCriterionTolerances', cfg.clean.WindowCriterionTolerances);
    nRemoved = nChanOrig - EEG.nbchan;
    log_msg(cfg, 'clean_rawdata 后: %d 通道 (移除 %d 个坏导)', EEG.nbchan, nRemoved);

    % ---------------------------------------------------------------------
    % 6. 平均参考 / average reference
    % ---------------------------------------------------------------------
    EEG = apply_reref(EEG, cfg);

    % ---------------------------------------------------------------------
    % 7. ICA  (runica, extended, PCA 降维)
    % ---------------------------------------------------------------------
    pcaDim = resolve_pca_dim(EEG, cfg);
    log_msg(cfg, '运行 ICA (runica, extended=%d, pca=%d) ...', cfg.ica.extended, pcaDim);
    EEG = pop_runica(EEG, 'icatype', cfg.ica.type, 'extended', cfg.ica.extended, ...
        'interrupt', cfg.ica.interrupt, 'pca', pcaDim);

    % ---------------------------------------------------------------------
    % 8-9. ICLabel 分类 + 自动剔除伪迹成分
    % ---------------------------------------------------------------------
    EEG = pop_iclabel(EEG, 'default');
    EEG = pop_icflag(EEG, cfg.iclabel.flag_thresholds);
    nReject = sum(EEG.reject.gcompreject);
    log_msg(cfg, 'ICLabel 标记伪迹成分: %d 个', nReject);
    EEG = pop_subcomp(EEG, [], 0);   % 剔除被标记成分 / remove flagged comps
    EEG = eeg_checkset(EEG);

    % ---------------------------------------------------------------------
    % 10. 球面插补被移除的坏导 / interpolate removed channels (spherical)
    % ---------------------------------------------------------------------
    if EEG.nbchan < nChanOrig
        EEG = pop_interp(EEG, full_selected_channels, cfg.interp.method);
        log_msg(cfg, '插补后恢复至 %d 通道', EEG.nbchan);
    end

    % ---------------------------------------------------------------------
    % 11. (推荐) 插补后再次平均参考 / re-reference again after interpolation
    %     微状态分析对参考敏感，插补会引入新通道，故重做平均参考。
    % ---------------------------------------------------------------------
    if cfg.reref.after_interp && strcmpi(cfg.reref.type, 'average')
        EEG = apply_reref(EEG, cfg);
    end

    EEG = eeg_checkset(EEG);

    % 记录处理信息到 EEG.etc / store provenance
    EEG.etc.preprocessing.cfg          = cfg;
    EEG.etc.preprocessing.subject      = subject;
    EEG.etc.preprocessing.nChanOrig    = nChanOrig;
    EEG.etc.preprocessing.nChanRemoved = nRemoved;
    EEG.etc.preprocessing.nICreject    = nReject;
    EEG.etc.preprocessing.date         = datestr(now);

    % ---------------------------------------------------------------------
    % 保存 / save
    % ---------------------------------------------------------------------
    if exist(cfg.paths.derivatives, 'dir') ~= 7
        mkdir(cfg.paths.derivatives);
    end
    [outDir, outName] = fileparts(subject.deriv_path);
    EEG = pop_saveset(EEG, 'filename', [outName '.set'], 'filepath', outDir);
    log_msg(cfg, '已保存: %s', subject.deriv_path);
end

% =========================================================================
% 局部函数 / local helpers
% =========================================================================
function EEG = import_raw(rawPath, cfg)
    switch lower(cfg.import.format)
        case 'mff'
            EEG = pop_mffimport({rawPath}, cfg.import.mff_typefield, 0, 0);
        case 'set'
            [p, n, e] = fileparts(rawPath);
            EEG = pop_loadset('filename', [n e], 'filepath', p);
        case 'edf'
            EEG = pop_biosig(rawPath);
        case 'bdf'
            EEG = pop_biosig(rawPath, 'importevent', 'on');
        otherwise
            error('preprocess_subject:format', ...
                '不支持的导入格式 / unsupported format: %s', cfg.import.format);
    end
end

function EEG = apply_reref(EEG, cfg)
    if strcmpi(cfg.reref.type, 'average') || isempty(cfg.reref.type)
        EEG = pop_reref(EEG, []);            % 平均参考 / average reference
    else
        EEG = pop_reref(EEG, cfg.reref.type);% 指定参考通道 / explicit reference
    end
end

function pcaDim = resolve_pca_dim(EEG, cfg)
% 决定 ICA 的 PCA 维数：cfg 指定则用之，否则用数据有效秩 (防止过定/欠定)。
    if ~isempty(cfg.ica.pca)
        pcaDim = min(cfg.ica.pca, EEG.nbchan);
        return;
    end
    % 估计有效秩 / estimate effective data rank
    dataRank = rank(double(EEG.data(:, 1:min(EEG.pnts, 20000))) * ...
                    double(EEG.data(:, 1:min(EEG.pnts, 20000)))');
    % 平均参考会使秩减 1 / average reference removes one degree of freedom
    pcaDim = min([dataRank, EEG.nbchan]);
    pcaDim = max(pcaDim, 1);
end
