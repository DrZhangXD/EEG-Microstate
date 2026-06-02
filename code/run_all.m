% RUN_ALL  PD 患者 EEG 微状态分析：端到端主流程。
%          PD-EEG microstate analysis: end-to-end master script.
%
%   逐步运行预处理 -> 组聚类 -> 回拟合 -> 导出 -> 统计。
%   Runs preprocessing -> segmentation -> back-fit -> export -> statistics.
%
%   运行前 / before running:
%     1. 在 config/pipeline_config.m 中设置 cfg.paths.eeglab (及微状态工具箱)。
%     2. 复制 config/subjects_template.csv 为 config/subjects.csv 并填入数据。
%     3. 将原始 .mff 放入 data/raw/ (或 subjects.csv 指定的路径)。
%
%   用法 / usage:  在本文件所在目录运行 `run_all`，或逐节执行 (Ctrl+Enter)。

%% 0. 初始化 / setup
clear; clc;
thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(thisDir));                          % code/ 下所有函数
addpath(fullfile(fileparts(thisDir), 'config'));    % config/
cfg = pipeline_config();
init_eeglab(cfg);

%% 1. 预处理 / preprocessing (导入->滤波->清理->ICA->插补)
batch_preprocess(cfg);

%% 2. 组水平微状态聚类 / group-level microstate segmentation
[prototypes, segInfo] = microstate_segment(cfg);

%% 3. 回拟合并提取每被试参数 / back-fit & per-subject statistics
stats = microstate_backfit(cfg);

%% 4. 导出参数表 (CSV) / export measures to CSV
T = export_microstate_stats(cfg, stats);

%% 5. 组间/条件间统计 + 绘图 / group statistics & figures
results = group_statistics(cfg, T);

disp('===== 全流程完成 / pipeline finished =====');
disp('结果见 results/ 目录 / see the results/ directory.');
