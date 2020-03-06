function [live_data, opts, paths, pipe_data] = load_previous_session(in_path, pipe_mode)
%load_live_session loads a previous session if it exists

%% Defaults
% todo: replace with varargout
live_data = [];
pipe_data = [];

%% Parse pipe_mode
switch pipe_mode
    case 'live'
        fname = 'AO_PIPE_LIVE.mat';
        varname = 'live_data';
    case 'full'
        fname = 'AO_PIPE_FULL.mat';
        varname = 'pipe_data';
    otherwise
        error('Options are "live" or "full", not: %s', pipe_mode);
end

%% Check for existing database
if exist(fullfile(in_path, fname), 'file') ~= 0
    % First call and running on a previously run dataset
    load(fullfile(in_path, fname), varname, 'paths', 'opts');
else
    % Initialize live structure
    live_data = init_live_data(fname);
    pipe_data = init_live_data(fname);
    paths = initPaths(in_path);
    opts = [];
end

end

