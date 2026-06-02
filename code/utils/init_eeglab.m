function init_eeglab(cfg)
% INIT_EEGLAB  启动 EEGLAB (无界面) 并加载所需插件路径。
%              Start EEGLAB (no GUI) and make required plugins available.
%
%   init_eeglab(cfg)
%
%   依赖 / requires:
%       - EEGLAB                 (Delorme & Makeig, 2004)
%       - clean_rawdata 插件     (ASR; Mullen et al., 2015)   -> EEGLAB 自带
%       - ICLabel 插件           (Pion-Tonachini et al., 2019)-> EEGLAB 自带
%       - MFFMatlabIO 插件       (导入 .mff) -> EEGLAB 自带 / built-in
%       - Microstate EEGlab toolbox (Poulsen et al., 2018)
%
%   见 / see: config/pipeline_config.m  (cfg.paths.*)

    if nargin < 1
        cfg = pipeline_config();
    end

    % ---- 添加并启动 EEGLAB / add & launch EEGLAB ----
    if isempty(cfg.paths.eeglab)
        if exist('eeglab', 'file') ~= 2
            error('init_eeglab:noEEGLAB', ...
                ['未设置 cfg.paths.eeglab，且 EEGLAB 不在 MATLAB 路径中。\n' ...
                 'Set cfg.paths.eeglab in config/pipeline_config.m, ' ...
                 'or add EEGLAB to the path manually.']);
        end
    else
        if exist(cfg.paths.eeglab, 'dir') ~= 7
            error('init_eeglab:badPath', ...
                'cfg.paths.eeglab 不存在: %s', cfg.paths.eeglab);
        end
        addpath(cfg.paths.eeglab);
    end

    % 无界面启动，仅初始化全局变量与插件 / start headless
    eeglab nogui;

    % ---- 可选：手动添加微状态工具箱 / optionally add microstate toolbox ----
    if ~isempty(cfg.paths.microstate_toolbox)
        if exist(cfg.paths.microstate_toolbox, 'dir') ~= 7
            warning('init_eeglab:microstate', ...
                '未找到微状态工具箱目录: %s', cfg.paths.microstate_toolbox);
        else
            addpath(genpath(cfg.paths.microstate_toolbox));
        end
    end

    % ---- 检查关键函数是否可用 / verify key functions are on the path ----
    required = {'pop_eegfiltnew', 'pop_clean_rawdata', 'pop_runica', ...
                'pop_iclabel', 'pop_icflag', 'pop_interp'};
    missing = required(cellfun(@(f) exist(f, 'file') ~= 2, required));
    if ~isempty(missing)
        warning('init_eeglab:missingFcns', ...
            ['以下 EEGLAB 函数不可用，请确认相关插件已安装:\n  %s'], ...
            strjoin(missing, ', '));
    end

    % 微状态工具箱函数 / microstate toolbox functions
    micro_fcns = {'pop_micro_selectdata', 'pop_micro_segment', ...
                  'pop_micro_fit', 'pop_micro_stats'};
    if any(cellfun(@(f) exist(f, 'file') ~= 2, micro_fcns))
        warning('init_eeglab:microstate', ...
            ['未检测到 Microstate EEGlab toolbox (Poulsen et al., 2018)。\n' ...
             '预处理仍可运行，但微状态步骤需要该工具箱:\n' ...
             '  https://github.com/atpoulsen/Microstate-EEGlab-toolbox']);
    end
end
