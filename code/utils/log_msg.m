function log_msg(cfg, fmt, varargin)
% LOG_MSG  统一的带时间戳日志输出 / timestamped logging helper.
%
%   log_msg(cfg, fmt, ...)   行为类似 fprintf，受 cfg.run.verbose 控制。
%   log_msg(fmt, ...)        亦可不传 cfg (默认 verbose)。

    if nargin >= 1 && isstruct(cfg)
        verbose = ~isfield(cfg, 'run') || ~isfield(cfg.run, 'verbose') || cfg.run.verbose;
    else
        % 未传 cfg：把第一个参数当作 fmt / no cfg passed
        if nargin >= 2
            varargin = [{fmt}, varargin];
        end
        if nargin >= 1
            fmt = cfg;
        end
        verbose = true;
    end

    if verbose
        fprintf('[%s] %s\n', datestr(now, 'HH:MM:SS'), sprintf(fmt, varargin{:}));
    end
end
