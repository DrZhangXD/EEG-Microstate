function [prototypes, info] = microstate_segment(cfg)
% MICROSTATE_SEGMENT  组水平微状态聚类，得到一组共享原型图 (A/B/C/D...)。
%                     Group-level microstate clustering -> shared prototype maps.
%
%   [prototypes, info] = microstate_segment(cfg)
%
%   步骤 / steps (Microstate EEGlab toolbox, Poulsen et al. 2018):
%       1. 载入所有被试的预处理数据 / load all preprocessed datasets
%       2. 提取各被试 GFP 峰处的地形图 / extract maps at GFP peaks
%       3. 在汇集的 GFP 峰上做修正 k-means 聚类 / modified k-means over pooled peaks
%       4. 依据 CV 等指标选定微状态数 K / choose K (default 4)
%       5. 保存组原型图 (.set + .mat) 并绘制地形图 /
%          save group prototypes and plot topographies
%
%   输出 / outputs:
%       prototypes - [nchan x K] 组原型图矩阵 / group prototype maps
%       info       - 结构体，含 K、被试列表、保存路径等 / metadata
%
%   生成文件 / writes:
%       results/group_prototypes.set   (含 .microstate.prototypes 的数据集)
%       results/group_prototypes.mat   (prototypes, Nmicro, subject ids)
%       results/fig_microstate_prototypes.png

    if nargin < 1, cfg = pipeline_config(); end
    if exist(cfg.paths.results, 'dir') ~= 7, mkdir(cfg.paths.results); end

    subjects = load_subjects(cfg);
    n = numel(subjects);
    log_msg(cfg, '###### 微状态聚类 / segmentation：%d 个数据集 ######', n);

    % ---------------------------------------------------------------------
    % 1. 载入所有预处理数据到 ALLEEG / load all preprocessed sets
    % ---------------------------------------------------------------------
    ALLEEG = [];
    for i = 1:n
        if exist(subjects(i).deriv_path, 'file') ~= 2
            error('microstate_segment:noDeriv', ...
                ['缺少预处理结果: %s\n请先运行 batch_preprocess(cfg)。\n' ...
                 'Run preprocessing first.'], subjects(i).deriv_path);
        end
        [p, nme, ext] = fileparts(subjects(i).deriv_path);
        EEG = pop_loadset('filename', [nme ext], 'filepath', p);
        EEG.setname = subjects(i).id;
        ALLEEG = eeg_store(ALLEEG, EEG, i);
    end

    % ---------------------------------------------------------------------
    % 2. 提取 GFP 峰 -> 生成汇集数据集 / select GFP peaks (pooled dataset)
    % ---------------------------------------------------------------------
    EEG = ALLEEG(1);
    [EEG, ALLEEG] = pop_micro_selectdata(EEG, ALLEEG, ...
        'datatype',    cfg.micro.select.datatype, ...
        'avgref',      cfg.micro.select.avgref, ...
        'normalise',   cfg.micro.select.normalise, ...
        'MinPeakDist', cfg.micro.select.MinPeakDist, ...
        'Npeaks',      cfg.micro.select.Npeaks, ...
        'GFPthresh',   cfg.micro.select.GFPthresh, ...
        'dataset_idx', 1:n);

    % pop_micro_selectdata 把汇集的 GFP 峰返回到 EEG (不会自动入 ALLEEG)，
    % 需手动存为新数据集 (索引 n+1) / pooled peaks are returned in EEG; store them.
    gfpIdx = n + 1;
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, gfpIdx);
    log_msg(cfg, 'GFP 峰汇集完成，共 %d 个地形图样本', size(EEG.data, 2));

    % ---------------------------------------------------------------------
    % 3. 修正 k-means 聚类 / modified k-means segmentation
    % ---------------------------------------------------------------------
    log_msg(cfg, '聚类中 (K=%s, 重复 %d 次) ...', ...
        mat2str(cfg.micro.segment.Nmicrostates), cfg.micro.segment.Nrepetitions);
    EEG = pop_micro_segment(EEG, ...
        'algorithm',      cfg.micro.segment.algorithm, ...
        'sorting',        'Global explained variance', ...
        'Nmicrostates',   cfg.micro.segment.Nmicrostates, ...
        'verbose',        double(cfg.run.verbose), ...
        'normalise',      cfg.micro.segment.normalise, ...
        'Nrepetitions',   cfg.micro.segment.Nrepetitions, ...
        'max_iterations', cfg.micro.segment.max_iterations, ...
        'threshold',      cfg.micro.segment.threshold, ...
        'fitmeas',        cfg.micro.segment.fitmeas, ...
        'optimised',      cfg.micro.segment.optimised);
    ALLEEG = eeg_store(ALLEEG, EEG, gfpIdx);

    % ---------------------------------------------------------------------
    % 4. 选定微状态数 K / select number of microstates
    % ---------------------------------------------------------------------
    if ~isempty(cfg.micro.Nmicro_final)
        % 直接指定 K (与工具箱教程一致) / select K explicitly
        EEG = pop_micro_selectNmicro(EEG, 'Nmicro', cfg.micro.Nmicro_final);
    else
        % 不指定则弹出度量曲线供交互选择 /
        % no K given -> interactive selection from the criterion curve
        warning('microstate_segment:autoK', ...
            ['cfg.micro.Nmicro_final 为空：将弹出 %s 度量曲线供交互选择 K。\n' ...
             '选定后建议在 config 中固定该 K 以保证可复现。'], cfg.micro.segment.fitmeas);
        EEG = pop_micro_selectNmicro(EEG);
    end
    ALLEEG = eeg_store(ALLEEG, EEG, gfpIdx);
    prototypes = EEG.microstate.prototypes;
    Nmicro = size(prototypes, 2);          % 由原型矩阵列数确定 K
    log_msg(cfg, '选定微状态数 K = %d', Nmicro);

    % ---------------------------------------------------------------------
    % 5. 保存 + 绘图 / save & plot
    % ---------------------------------------------------------------------
    EEG.setname = 'group_prototypes';
    pop_saveset(EEG, 'filename', 'group_prototypes.set', 'filepath', cfg.paths.results);

    info = struct();
    info.Nmicro       = Nmicro;
    info.subject_ids  = {subjects.id};
    info.chanlocs     = EEG.chanlocs;
    info.fitmeas      = cfg.micro.segment.fitmeas;
    info.date         = datestr(now);
    save(fullfile(cfg.paths.results, 'group_prototypes.mat'), ...
        'prototypes', 'Nmicro', 'info');

    try
        figure('Visible', 'off', 'Color', 'w');
        pop_micro_plottopo(EEG, 'plot_range', []);
        saveas(gcf, fullfile(cfg.paths.results, 'fig_microstate_prototypes.png'));
        close(gcf);
        log_msg(cfg, '原型地形图已保存: results/fig_microstate_prototypes.png');
    catch ME
        warning('microstate_segment:plot', '绘图失败: %s', ME.message);
    end

    log_msg(cfg, '###### 聚类完成，原型已保存 ######');
end
