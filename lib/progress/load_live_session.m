function [live_data, opts] = load_live_session(in_path)
%load_live_session loads a previous session if it exists

%% Constants
LIVE_FNAME = 'AO_PIPE_LIVE.mat';

%% Check for existing database
if exist(fullfile(in_path, LIVE_FNAME), 'file') ~= 0
    % First call and running on a previously run dataset
    load(fullfile(in_path, LIVE_FNAME), 'live_data', 'opts');
else
    % Initialize live structure
    live_data = init_live_data(LIVE_FNAME);
    opts = [];
end

end

