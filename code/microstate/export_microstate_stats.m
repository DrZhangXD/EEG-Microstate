function T = export_microstate_stats(cfg, stats)
% EXPORT_MICROSTATE_STATS  将每个被试的微状态统计整理为宽表 CSV。
%                          Flatten per-subject microstate stats into wide CSVs.
%
%   T = export_microstate_stats(cfg)          % 自动读取 microstate_stats.mat
%   T = export_microstate_stats(cfg, stats)   % 直接传入 microstate_backfit 的输出
%
%   生成文件 / writes:
%       results/microstate_measures.csv     每被试每微状态的参数 (宽表)
%       results/microstate_transitions.csv  转移概率矩阵 (长表)
%
%   微状态参数 (由 pop_micro_stats 计算) / measures from pop_micro_stats:
%       Duration  - 平均持续时间 / mean duration
%       Occurence - 出现频率 / occurrence per second
%       Coverage  - 时间覆盖率 / fraction of time covered
%       GEV       - 各态全局解释方差 / per-map global explained variance
%       MGFP      - 各态平均 GFP / mean GFP per map
%   注意单位以所用工具箱版本为准 (Duration 多为 ms 或 s) / verify units per version.

    if nargin < 1, cfg = pipeline_config(); end
    if nargin < 2
        f = fullfile(cfg.paths.results, 'microstate_stats.mat');
        if exist(f, 'file') ~= 2
            error('export_microstate_stats:noStats', ...
                ['未找到 %s，请先运行 microstate_backfit(cfg)。'], f);
        end
        S = load(f); stats = S.stats;
    end

    n = numel(stats);
    % 微状态数 K (取自第一个被试的 Duration 长度) / number of microstates
    K = numel(stats(1).micro.Duration);
    labels = microstate_labels(K);   % {'A','B','C','D',...}

    % 逐被试逐参数展开 / build wide table row by row
    perMapMeasures = {'Duration', 'Occurence', 'Coverage', 'GEV', 'MGFP'};
    rows = cell(n, 1);
    for i = 1:n
        m = stats(i).micro;
        r = struct();
        % 文本列用 string 类型，确保 struct2table 生成干净的文本列 /
        % string type so struct2table makes clean text columns
        r.subject_id = string(stats(i).subject_id);
        r.group      = string(stats(i).group);
        r.condition  = string(stats(i).condition);

        % 全局量 / global scalars (字段不存在则跳过)
        if isfield(m, 'GEVtotal'), r.GEVtotal = m.GEVtotal; end
        if isfield(m, 'Gfp'),      r.GFP_mean = mean(m.Gfp(:)); end

        % 各态参数 / per-map measures
        for mm = 1:numel(perMapMeasures)
            meas = perMapMeasures{mm};
            if ~isfield(m, meas), continue; end
            v = m.(meas);
            for k = 1:K
                r.(sprintf('%s_%s', meas, labels{k})) = v(k);
            end
        end
        rows{i} = r;
    end
    T = struct2table([rows{:}]);

    measuresCsv = fullfile(cfg.paths.results, 'microstate_measures.csv');
    writetable(T, measuresCsv);
    log_msg(cfg, '已导出参数宽表 / wrote %s (%d 行)', measuresCsv, height(T));

    % ---------------------------------------------------------------------
    % 转移概率 (长表) / transition probabilities (long format)
    % ---------------------------------------------------------------------
    if isfield(stats(1).micro, 'TP')
        tpRows = {};
        for i = 1:n
            TP = stats(i).micro.TP;   % KxK
            for a = 1:K
                for b = 1:K
                    tpRows{end+1} = struct( ...
                        'subject_id', string(stats(i).subject_id), ...
                        'group',      string(stats(i).group), ...
                        'condition',  string(stats(i).condition), ...
                        'from',       string(labels{a}), ...
                        'to',         string(labels{b}), ...
                        'prob',       TP(a, b)); %#ok<AGROW>
                end
            end
        end
        TPt = struct2table([tpRows{:}]);
        tpCsv = fullfile(cfg.paths.results, 'microstate_transitions.csv');
        writetable(TPt, tpCsv);
        log_msg(cfg, '已导出转移概率 / wrote %s (%d 行)', tpCsv, height(TPt));
    end
end

function labels = microstate_labels(K)
% 生成微状态字母标签 A,B,C,...，超过 26 个则用 MS1,MS2,...
    if K <= 26
        labels = arrayfun(@(k) char('A' + k - 1), 1:K, 'UniformOutput', false);
    else
        labels = arrayfun(@(k) sprintf('MS%d', k), 1:K, 'UniformOutput', false);
    end
end
