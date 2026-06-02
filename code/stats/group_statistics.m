function results = group_statistics(cfg, T)
% GROUP_STATISTICS  对微状态参数做组间/条件间比较。
%                   Group/condition comparison of microstate measures.
%
%   results = group_statistics(cfg)        % 读取 results/microstate_measures.csv
%   results = group_statistics(cfg, T)     % 直接传入参数宽表
%
%   依据 cfg.stats / driven by cfg.stats:
%       .factor      对比因子列名 ('condition' 或 'group')
%       .design      'paired' (被试内, 按 subject_id 配对) | 'independent'
%       .measures    要检验的参数 {'Duration','Occurence','Coverage','GEV'}
%       .correction  'fdr' | 'bonferroni' | 'none'
%       .alpha       显著性水平
%
%   不依赖 Statistics Toolbox：t 分布 p 值用 betainc 计算 (基础 MATLAB)。
%   No Statistics Toolbox required: t p-values via betainc.
%
%   生成文件 / writes:
%       results/microstate_group_stats.csv
%       results/fig_<measure>_by_<factor>.png

    if nargin < 1, cfg = pipeline_config(); end
    if nargin < 2
        f = fullfile(cfg.paths.results, 'microstate_measures.csv');
        if exist(f, 'file') ~= 2
            error('group_statistics:noCsv', ...
                '未找到 %s，请先运行 export_microstate_stats(cfg)。', f);
        end
        T = readtable(f);
    end

    factor = cfg.stats.factor;
    if ~ismember(factor, T.Properties.VariableNames)
        error('group_statistics:badFactor', '表中无对比因子列: %s', factor);
    end
    % 统一为 cellstr，兼容 T 来自内存(string列)或 CSV(cellstr列) /
    % normalise to cellstr regardless of how T was produced
    levels = cellstr(unique(string(T.(factor)), 'stable'));
    if numel(levels) ~= 2
        error('group_statistics:twoLevels', ...
            ['对比因子 %s 需恰好 2 个水平，当前为 %d 个: %s\n' ...
             '请调整 subjects.csv 或 cfg.stats.factor。'], ...
            factor, numel(levels), strjoin(levels, ', '));
    end
    log_msg(cfg, '###### 组间统计 / statistics：%s = {%s vs %s}, 设计=%s ######', ...
        factor, levels{1}, levels{2}, cfg.stats.design);

    % 找出所有"参数_微状态"列 / find all measure columns
    allVars = T.Properties.VariableNames;
    rows = {};
    for mi = 1:numel(cfg.stats.measures)
        meas = cfg.stats.measures{mi};
        cols = allVars(startsWith(allVars, [meas '_']));
        for ci = 1:numel(cols)
            col = cols{ci};
            ms  = extractAfter(col, [meas '_']);   % 微状态标签 / map label
            [x1, x2] = split_by_level(T, factor, levels, col, cfg);
            st = run_test(x1, x2, cfg.stats.design);
            st.measure   = string(meas);
            st.microstate= string(ms);
            st.column    = string(col);
            st.level1    = string(levels{1});
            st.level2    = string(levels{2});
            rows{end+1} = st; %#ok<AGROW>
        end
    end

    results = struct2table([rows{:}]);

    % ---------------------------------------------------------------------
    % 多重比较校正 / multiple-comparison correction
    % ---------------------------------------------------------------------
    p = results.p;
    switch lower(cfg.stats.correction)
        case 'fdr'
            results.p_corrected = bh_fdr(p);
        case 'bonferroni'
            results.p_corrected = min(p * numel(p), 1);
        otherwise
            results.p_corrected = p;
    end
    results.significant = results.p_corrected < cfg.stats.alpha;

    % 重排列顺序便于阅读 / reorder columns
    front = {'measure','microstate','level1','level2','mean1','sd1','mean2','sd2', ...
             't','df','p','p_corrected','cohens_d','significant'};
    front = front(ismember(front, results.Properties.VariableNames));
    results = results(:, [front, setdiff(results.Properties.VariableNames, front, 'stable')]);

    outCsv = fullfile(cfg.paths.results, 'microstate_group_stats.csv');
    writetable(results, outCsv);
    log_msg(cfg, '统计结果已保存 / wrote %s', outCsv);

    nSig = sum(results.significant);
    if nSig > 0
        log_msg(cfg, '校正后显著的比较 (%d 项):', nSig);
        sigT = results(results.significant, {'measure','microstate','p_corrected'});
        disp(sigT);
    else
        log_msg(cfg, '校正后无显著差异 / no significant differences after correction.');
    end

    % ---------------------------------------------------------------------
    % 绘图 / plotting (best-effort)
    % ---------------------------------------------------------------------
    for mi = 1:numel(cfg.stats.measures)
        try
            plot_measure(cfg, T, factor, levels, cfg.stats.measures{mi}, results);
        catch ME
            warning('group_statistics:plot', '绘图 %s 失败: %s', ...
                cfg.stats.measures{mi}, ME.message);
        end
    end
    log_msg(cfg, '###### 统计完成 ######');
end

% =========================================================================
% 局部函数 / local helpers
% =========================================================================
function [x1, x2] = split_by_level(T, factor, levels, col, cfg)
    isL1 = strcmp(T.(factor), levels{1});
    isL2 = strcmp(T.(factor), levels{2});
    if strcmpi(cfg.stats.design, 'paired')
        % 按 subject_id 配对 / match by subject id
        s1 = T.subject_id(isL1);  v1 = T.(col)(isL1);
        s2 = T.subject_id(isL2);  v2 = T.(col)(isL2);
        [common, i1, i2] = intersect(s1, s2, 'stable');
        if isempty(common)
            warning('group_statistics:noPairs', ...
                '配对设计但 %s 两水平无共同 subject_id。', factor);
        end
        x1 = v1(i1);  x2 = v2(i2);
        % 成对去除缺失 (保持配对) / drop pairs where either value is NaN
        valid = ~isnan(x1) & ~isnan(x2);
        x1 = x1(valid);  x2 = x2(valid);
    else
        x1 = T.(col)(isL1);  x2 = T.(col)(isL2);
        x1 = x1(~isnan(x1));  x2 = x2(~isnan(x2));
    end
end

function st = run_test(x1, x2, design)
% 返回均值、标准差、t、df、p (双侧)、Cohen's d / two-sample or paired t-test.
    st = struct('mean1',NaN,'sd1',NaN,'mean2',NaN,'sd2',NaN, ...
                't',NaN,'df',NaN,'p',NaN,'cohens_d',NaN,'n1',numel(x1),'n2',numel(x2));
    st.mean1 = mean(x1); st.sd1 = std(x1);
    st.mean2 = mean(x2); st.sd2 = std(x2);

    if strcmpi(design, 'paired')
        if numel(x1) ~= numel(x2) || isempty(x1), return; end
        d  = x1 - x2;
        nd = numel(d);
        sd = std(d);
        if sd == 0, return; end
        st.t  = mean(d) / (sd / sqrt(nd));
        st.df = nd - 1;
        st.cohens_d = mean(d) / sd;        % Cohen's dz
    else
        n1 = numel(x1); n2 = numel(x2);
        if n1 < 2 || n2 < 2, return; end
        v1 = var(x1);  v2 = var(x2);
        % Welch's t-test (允许方差不等) / unequal variances
        st.t  = (mean(x1) - mean(x2)) / sqrt(v1/n1 + v2/n2);
        st.df = (v1/n1 + v2/n2)^2 / ((v1/n1)^2/(n1-1) + (v2/n2)^2/(n2-1));
        sp = sqrt(((n1-1)*v1 + (n2-1)*v2) / (n1 + n2 - 2));  % pooled sd
        if sp > 0, st.cohens_d = (mean(x1) - mean(x2)) / sp; end
    end
    st.p = t_pvalue(st.t, st.df);
end

function p = t_pvalue(t, df)
% Student-t 双侧 p 值，用不完全 beta 函数 (基础 MATLAB，无需统计工具箱)。
%   P(|T|>t) = I_{df/(df+t^2)}(df/2, 1/2)
    if isnan(t) || isnan(df) || df <= 0
        p = NaN; return;
    end
    p = betainc(df / (df + t^2), df/2, 0.5);
    p = min(max(p, 0), 1);
end

function pc = bh_fdr(p)
% Benjamini-Hochberg FDR 校正 / BH-FDR adjusted p-values.
    p = p(:);
    m = numel(p);
    [ps, ord] = sort(p);
    ranks = (1:m)';
    adj = ps .* m ./ ranks;
    % 自后向前取累计最小，保证单调 / enforce monotonicity
    adj = flipud(cummin(flipud(adj)));
    pc = zeros(m, 1);
    pc(ord) = min(adj, 1);
end

function plot_measure(cfg, T, factor, levels, meas, results)
    allVars = T.Properties.VariableNames;
    cols = allVars(startsWith(allVars, [meas '_']));
    if isempty(cols), return; end
    labels = cellfun(@(c) extractAfter(c, [meas '_']), cols, 'UniformOutput', false);
    K = numel(cols);

    M = nan(K, 2);  S = nan(K, 2);
    for k = 1:K
        for L = 1:2
            v = T.(cols{k})(strcmp(T.(factor), levels{L}));
            v = v(~isnan(v));
            M(k, L) = mean(v);
            S(k, L) = std(v) / sqrt(max(numel(v), 1));  % SEM
        end
    end

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 720 420]);
    hb = bar(M, 'grouped'); hold on;
    % 误差棒 / error bars
    ngroups = K; nbars = 2;
    groupwidth = min(0.8, nbars/(nbars + 1.5));
    for L = 1:nbars
        xpos = (1:ngroups) - groupwidth/2 + (2*L-1) * groupwidth / (2*nbars);
        errorbar(xpos, M(:, L), S(:, L), 'k', 'linestyle', 'none', 'LineWidth', 1);
    end
    % 显著性星标 / significance stars
    sub = results(strcmp(results.measure, meas), :);
    for k = 1:K
        idx = strcmp(sub.microstate, labels{k});
        if any(idx) && sub.significant(find(idx, 1))
            ymax = max(M(k, :) + S(k, :));
            text(k, ymax * 1.08, '*', 'HorizontalAlignment', 'center', ...
                'FontSize', 16, 'FontWeight', 'bold');
        end
    end
    set(gca, 'XTick', 1:K, 'XTickLabel', labels);
    xlabel('微状态 / Microstate');
    ylabel(meas);
    title(sprintf('%s: %s vs %s', meas, levels{1}, levels{2}), 'Interpreter', 'none');
    legend(hb, levels, 'Location', 'best', 'Interpreter', 'none');
    box off;

    outPng = fullfile(cfg.paths.results, sprintf('fig_%s_by_%s.png', meas, factor));
    saveas(fig, outPng);
    close(fig);
    log_msg(cfg, '图已保存 / wrote %s', outPng);
end
