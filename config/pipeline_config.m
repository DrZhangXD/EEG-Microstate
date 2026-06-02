function cfg = pipeline_config()
% PIPELINE_CONFIG  集中管理整个 EEG 微状态分析流程的所有参数。
%                  Central configuration for the EEG microstate pipeline.
%
%   所有脚本都通过 `cfg = pipeline_config();` 读取参数，避免参数散落在各处。
%   修改路径 / 参数时只需编辑本文件。
%
%   All scripts read their parameters from this single struct, so you only
%   need to edit paths and parameters in one place.
%
%   用法 / Usage:
%       cfg = pipeline_config();
%
%   作者 / Author: 张小黑 (zhangxudong) ; 整理与扩展 by pipeline refactor.

% =========================================================================
% 1. 路径设置 / PATHS
% =========================================================================
% 项目根目录（自动定位到本文件上一级目录）/ project root (one level above /config)
cfg.paths.project = fileparts(fileparts(mfilename('fullpath')));

% --- 必填：EEGLAB 安装目录 / REQUIRED: path to your EEGLAB installation ---
% 例如 / e.g. 'C:\toolbox\eeglab2024.0' 或 '/home/user/eeglab'
cfg.paths.eeglab = '';   % <-- 请修改为你的 EEGLAB 路径 / SET ME

% --- 必填：Microstate EEGlab toolbox (Poulsen et al., 2018) 目录 ---
% 下载地址 / download: https://github.com/atpoulsen/Microstate-EEGlab-toolbox
% 若已作为 EEGLAB 插件安装在 eeglab/plugins/ 下，可留空，init_eeglab 会自动加载。
cfg.paths.microstate_toolbox = '';   % 可选 / optional

% 输入输出目录 / I/O directories (relative to project root)
cfg.paths.raw          = fullfile(cfg.paths.project, 'data', 'raw');
cfg.paths.derivatives  = fullfile(cfg.paths.project, 'data', 'derivatives');
cfg.paths.results      = fullfile(cfg.paths.project, 'results');

% 被试清单 / subject manifest (CSV). 见 config/subjects_template.csv
cfg.paths.subjects_csv = fullfile(cfg.paths.project, 'config', 'subjects.csv');

% =========================================================================
% 2. 导入 / IMPORT
% =========================================================================
% 原始数据格式 / raw format: 'mff' (EGI) | 'set' (already in EEGLAB) | 'edf' | 'bdf'
cfg.import.format = 'mff';
% pop_mffimport 的事件类型参数 / event field codes ('' = 默认 default)
cfg.import.mff_typefield = '';

% =========================================================================
% 3. 滤波 / FILTERING  (保留原 pipeline 参数 / faithful to original)
% =========================================================================
cfg.filter.bandpass_lo = 1;     % 高通 / high-pass cutoff (Hz)
cfg.filter.bandpass_hi = 40;    % 低通 / low-pass cutoff (Hz)
cfg.filter.notch_lo    = 48;    % 陷波下限 / notch lower edge (Hz)
cfg.filter.notch_hi    = 52;    % 陷波上限 / notch upper edge (Hz)
cfg.filter.plotfreqz   = 0;     % 是否绘制频响 (批处理建议 0) / plot filter response

% =========================================================================
% 4. 重采样 / RESAMPLE
% =========================================================================
cfg.resample.srate = 500;       % 目标采样率 / target sampling rate (Hz)

% =========================================================================
% 5. clean_rawdata / ASR  (保留原 pipeline 参数 / faithful to original)
% =========================================================================
cfg.clean.FlatlineCriterion        = 5;
cfg.clean.ChannelCriterion         = 0.8;
cfg.clean.LineNoiseCriterion       = 4;
cfg.clean.Highpass                 = 'off';   % 高通已在滤波步骤完成 / done above
cfg.clean.BurstCriterion           = 20;
cfg.clean.WindowCriterion          = 0.25;
cfg.clean.BurstRejection           = 'on';
cfg.clean.Distance                 = 'Euclidian';
cfg.clean.WindowCriterionTolerances= [-Inf 7];

% =========================================================================
% 6. 重参考 / RE-REFERENCE
% =========================================================================
cfg.reref.type = 'average';     % 'average' (平均参考, 推荐用于微状态) | [] | 通道索引
% 是否在插补坏导后再做一次平均参考 (微状态分析强烈推荐) /
% re-reference again AFTER interpolation (recommended for microstates)
cfg.reref.after_interp = true;

% =========================================================================
% 7. ICA  (保留原 pipeline 参数 / faithful to original)
% =========================================================================
cfg.ica.type      = 'runica';
cfg.ica.extended  = 1;
cfg.ica.interrupt = 'off';      % 批处理用 'off' / 'off' for batch (was 'on')
% PCA 降维维数 / PCA dimensionality reduction.
%   []   = 自动用数据有效秩 (推荐, 防止过/欠定) / auto = effective data rank (recommended)
%   253  = 原 pipeline 固定值 (256 导联系统) / original fixed value
cfg.ica.pca = [];

% =========================================================================
% 8. ICLabel 自动去伪迹 / automatic component rejection
% =========================================================================
% pop_icflag 阈值矩阵，每行一类，[下限 上限] 概率，NaN=不依此类剔除。
% rows: Brain | Muscle | Eye | Heart | LineNoise | ChannelNoise | Other
% 原 pipeline: 对 Muscle/Eye/Heart/LineNoise/ChannelNoise 用 0.7-1 阈值剔除。
cfg.iclabel.flag_thresholds = [ ...
    NaN NaN;   % Brain        - 永不剔除 / never reject
    0.7 1;     % Muscle
    0.7 1;     % Eye
    0.7 1;     % Heart
    0.7 1;     % Line Noise
    0.7 1;     % Channel Noise
    NaN NaN];  % Other        - 永不剔除 / never reject

% =========================================================================
% 9. 插补 / INTERPOLATION
% =========================================================================
cfg.interp.method = 'spherical';   % 球面样条插补 / spherical spline

% =========================================================================
% 10. 微状态分析 / MICROSTATE ANALYSIS  (Poulsen et al., 2018 toolbox)
% =========================================================================
% --- GFP 峰提取 (用于聚类) / GFP-peak extraction for clustering ---
cfg.micro.select.datatype   = 'spontaneous';  % 静息态 / resting-state
cfg.micro.select.avgref     = 1;              % 聚类前平均参考 / average ref
cfg.micro.select.normalise  = 1;              % 按被试 GFP 归一化 / per-subject GFP norm
cfg.micro.select.MinPeakDist= 10;             % GFP 峰最小间隔 (ms)
cfg.micro.select.Npeaks     = 1000;           % 每被试抽取峰数 / peaks per subject
cfg.micro.select.GFPthresh  = 1;              % 剔除 > N 倍标准差的峰 / GFP outlier thresh

% --- 聚类 / Segmentation (clustering) ---
cfg.micro.segment.algorithm    = 'modkmeans';  % 修正 k-means / modified k-means
cfg.micro.segment.Nmicrostates = 3:8;          % 候选微状态数范围 / candidate K range
cfg.micro.segment.Nrepetitions = 50;           % 随机初始化次数 / random restarts
cfg.micro.segment.max_iterations = 1000;
cfg.micro.segment.threshold    = 1e-6;         % 收敛阈值 / convergence threshold
cfg.micro.segment.fitmeas      = 'CV';         % 模型选择指标 / criterion (CV)
cfg.micro.segment.normalise    = 0;            % 数据已归一化 / already normalised
cfg.micro.segment.optimised    = 1;            % 使用优化实现 / optimised modkmeans

% 最终采用的微状态数 / final number of microstates.
%   []   = 由 cfg.micro.segment.fitmeas (CV) 自动选择 / auto via criterion
%   4    = 经典 A/B/C/D 四态 / classic four maps
cfg.micro.Nmicro_final = 4;

% --- 回拟合 / Back-fitting (label whole continuous EEG) ---
cfg.micro.fit.polarity = 0;        % 忽略极性 (静息态标准做法) / polarity-invariant

% --- 时间平滑 / Temporal smoothing ---
cfg.micro.smooth.label_type = 'backfit';
cfg.micro.smooth.smooth_type= 'reject segments'; % 短段重标记 / reject short segments
cfg.micro.smooth.minTime    = 30;                % 最短微状态时长 (ms)
cfg.micro.smooth.polarity   = 0;

% =========================================================================
% 11. 组间统计 / GROUP STATISTICS
% =========================================================================
% 主比较因子 / main contrast: 列名见 subjects.csv 的 'condition' / 'group'
cfg.stats.factor = 'condition';        % 'condition' (被试内条件) 或 'group' (组别)
% 比较设计 / design: 'paired' (被试内, 同一被试的两个条件) | 'independent' (组间)
cfg.stats.design = 'paired';
cfg.stats.alpha  = 0.05;
% 多重比较校正 / multiple-comparison correction: 'fdr' | 'bonferroni' | 'none'
cfg.stats.correction = 'fdr';
% 待比较的微状态参数 / microstate parameters to test
cfg.stats.measures = {'Duration', 'Occurence', 'Coverage', 'GEV'};

% =========================================================================
% 12. 运行选项 / RUNTIME OPTIONS
% =========================================================================
cfg.run.overwrite = false;   % 是否覆盖已存在的中间结果 / overwrite existing outputs
cfg.run.verbose   = true;    % 详细日志 / verbose logging

end
