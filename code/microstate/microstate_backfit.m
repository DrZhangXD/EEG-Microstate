function stats = microstate_backfit(cfg)
% MICROSTATE_BACKFIT  将组原型回拟合到每个被试，提取微状态时间参数。
%                     Back-fit group prototypes to each subject and compute
%                     per-subject microstate statistics.
%
%   stats = microstate_backfit(cfg)
%
%   步骤 / steps (Microstate EEGlab toolbox, Poulsen et al. 2018):
%       1. 载入组原型 (microstate_segment 的产物) / load group prototypes
%       2. 对每个被试连续数据按空间相关性逐时刻标记 / back-fit (pop_micro_fit)
%       3. 时间平滑：剔除过短片段 / temporal smoothing (pop_micro_smooth)
%       4. 计算统计量 / compute statistics (pop_micro_stats):
%          - Duration  平均持续时间 (ms)
%          - Occurence 出现频率 (次/秒)
%          - Coverage  时间覆盖率 (比例)
%          - GEV       全局解释方差
%          - TP        转移概率矩阵 / transition-probability matrix
%
%   输出 / output:
%       stats - 1xN 结构体数组，每个被试一项，含 .subject_id/.group/
%               .condition 及 .micro (EEG.microstate.stats)
%
%   生成文件 / writes:
%       data/derivatives/<id>_micro.set   每个被试的标注数据集
%       results/microstate_stats.mat       汇总统计

    if nargin < 1, cfg = pipeline_config(); end

    protoFile = fullfile(cfg.paths.results, 'group_prototypes.set');
    if exist(protoFile, 'file') ~= 2
        error('microstate_backfit:noProto', ...
            ['未找到组原型: %s\n请先运行 microstate_segment(cfg)。\n' ...
             'Run microstate_segment first.'], protoFile);
    end

    subjects = load_subjects(cfg);
    n = numel(subjects);
    log_msg(cfg, '###### 回拟合 / back-fitting：%d 个被试 ######', n);

    % ---------------------------------------------------------------------
    % 载入所有被试 + 原型数据集到 ALLEEG / load subjects + prototype set
    % ---------------------------------------------------------------------
    ALLEEG = [];
    for i = 1:n
        [p, nme, ext] = fileparts(subjects(i).deriv_path);
        EEG = pop_loadset('filename', [nme ext], 'filepath', p);
        EEG.setname = subjects(i).id;
        ALLEEG = eeg_store(ALLEEG, EEG, i);
    end
    EEGproto = pop_loadset('filename', 'group_prototypes.set', 'filepath', cfg.paths.results);
    protoIdx = n + 1;
    ALLEEG = eeg_store(ALLEEG, EEGproto, protoIdx);

    stats = struct('subject_id', cell(1, n), 'group', [], 'condition', [], ...
                   'id', [], 'micro', []);

    for i = 1:n
        log_msg(cfg, '回拟合 %s ...', subjects(i).id);
        EEG = ALLEEG(i);

        % 1. 导入组原型 / import group prototypes from prototype dataset
        EEG = pop_micro_import_proto(EEG, ALLEEG, protoIdx);

        % 2. 回拟合 (空间相关，忽略极性) / back-fit
        EEG = pop_micro_fit(EEG, 'polarity', cfg.micro.fit.polarity);

        % 3. 时间平滑 (剔除过短片段) / temporal smoothing
        EEG = pop_micro_smooth(EEG, ...
            'label_type', cfg.micro.smooth.label_type, ...
            'smooth_type', cfg.micro.smooth.smooth_type, ...
            'minTime',     cfg.micro.smooth.minTime, ...
            'polarity',    cfg.micro.smooth.polarity);

        % 4. 计算统计量 / statistics
        EEG = pop_micro_stats(EEG, ...
            'label_type', cfg.micro.smooth.label_type, ...
            'polarity',   cfg.micro.fit.polarity);

        % 保存标注数据集 / save labelled dataset
        outName = sprintf('%s_micro.set', subjects(i).id);
        pop_saveset(EEG, 'filename', outName, 'filepath', cfg.paths.derivatives);

        stats(i).subject_id = subjects(i).subject_id;
        stats(i).group      = subjects(i).group;
        stats(i).condition  = subjects(i).condition;
        stats(i).id         = subjects(i).id;
        stats(i).micro      = EEG.microstate.stats;
        ALLEEG(i) = EEG;
    end

    save(fullfile(cfg.paths.results, 'microstate_stats.mat'), 'stats');
    log_msg(cfg, '###### 回拟合完成，统计已保存: results/microstate_stats.mat ######');
end
