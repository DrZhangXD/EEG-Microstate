function batch_preprocess(cfg)
% BATCH_PREPROCESS  对被试清单中的所有记录批量预处理。
%                   Batch-preprocess every record in the subject manifest.
%
%   batch_preprocess(cfg)
%
%   逐个调用 preprocess_subject，单个被试出错不影响其余 (记录到日志)。
%   Errors on one subject are caught and logged so the batch continues.

    if nargin < 1, cfg = pipeline_config(); end

    subjects = load_subjects(cfg);
    n = numel(subjects);
    log_msg(cfg, '###### 批量预处理：共 %d 条记录 / %d records ######', n, n);

    failed = {};
    for i = 1:n
        try
            preprocess_subject(subjects(i), cfg);
        catch ME
            failed{end+1} = subjects(i).id; %#ok<AGROW>
            warning('batch_preprocess:subjectFailed', ...
                '被试 %s 处理失败 / failed: %s', subjects(i).id, ME.message);
            fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
    end

    log_msg(cfg, '###### 批量预处理完成 / done ######');
    if isempty(failed)
        log_msg(cfg, '全部 %d 条记录成功 / all succeeded', n);
    else
        log_msg(cfg, '失败 %d 条 / %d failed: %s', numel(failed), numel(failed), ...
            strjoin(failed, ', '));
    end
end
