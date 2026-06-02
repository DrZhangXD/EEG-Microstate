function subjects = load_subjects(cfg)
% LOAD_SUBJECTS  读取被试清单 CSV，返回结构体数组。
%                Read the subject manifest CSV into a struct array.
%
%   subjects = load_subjects(cfg)
%
%   CSV 列 / required columns:
%       subject_id  - 被试编号 / subject id  (e.g. sub-01)
%       group       - 组别 / group           (e.g. PD, HC)
%       condition   - 条件 / condition       (e.g. cond1, cond2)
%       raw_file    - 原始文件名 (相对 cfg.paths.raw) / raw filename
%
%   返回 / returns: 1xN struct，字段同上，并附加 .raw_path / .deriv_path

    csv = cfg.paths.subjects_csv;
    if exist(csv, 'file') ~= 2
        error('load_subjects:noCSV', ...
            ['未找到被试清单: %s\n' ...
             '请复制 config/subjects_template.csv 为 config/subjects.csv ' ...
             '并填入你的数据。\nCopy the template to config/subjects.csv first.'], csv);
    end

    T = readtable(csv, 'Delimiter', ',');

    required = {'subject_id', 'group', 'condition', 'raw_file'};
    missingCols = required(~ismember(required, T.Properties.VariableNames));
    if ~isempty(missingCols)
        error('load_subjects:badCols', ...
            'subjects.csv 缺少列 / missing columns: %s', strjoin(missingCols, ', '));
    end

    n = height(T);
    % 逐字段构建结构体数组 (避免字段顺序导致的赋值错误) /
    % build field-by-field to avoid "dissimilar structures" assignment errors
    subjects = struct([]);
    for i = 1:n
        sid  = strtrim(cell2charsafe(T.subject_id(i)));
        cond = strtrim(cell2charsafe(T.condition(i)));
        subjects(i).subject_id = sid;
        subjects(i).group      = strtrim(cell2charsafe(T.group(i)));
        subjects(i).condition  = cond;
        subjects(i).raw_file   = strtrim(cell2charsafe(T.raw_file(i)));
        % 唯一标识 (被试_条件) / unique id used for output filenames
        subjects(i).id         = sprintf('%s_%s', sid, cond);
        % raw_file 可为相对 data/raw 的文件名或绝对路径 / relative or absolute
        if isAbsolutePath(subjects(i).raw_file)
            subjects(i).raw_path = subjects(i).raw_file;
        else
            subjects(i).raw_path = fullfile(cfg.paths.raw, subjects(i).raw_file);
        end
        subjects(i).deriv_path = fullfile(cfg.paths.derivatives, ...
            [subjects(i).id '_clean.set']);
    end
end

function s = cell2charsafe(x)
% 把表格单元 (cellstr / string / char / 数值) 安全转为 char 行向量。
    if iscell(x), x = x{1}; end
    if isstring(x), x = char(x); end
    if isnumeric(x), x = num2str(x); end
    s = char(x);
end

function tf = isAbsolutePath(p)
% 判断绝对路径 (兼容 Windows 与 *nix) / detect absolute path.
    tf = ~isempty(regexp(p, '^([A-Za-z]:[\\/]|[\\/]|\\\\)', 'once'));
end
