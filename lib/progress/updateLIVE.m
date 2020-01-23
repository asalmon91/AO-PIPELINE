function live_data = updateLIVE(paths, live_data, opts)
%updateLIVE checks for new data

%% Constants
LIVE_FNAME = 'AO_PIPE_LIVE.mat';

%% Check for existing database
if (exist('live_data', 'var') == 0 || isempty(live_data)) && ...
        exist(fullfile(paths.root, LIVE_FNAME), 'file') ~= 0
    % First call and running on a previously run dataset
    load(fullfile(paths.root, LIVE_FNAME), 'live_data');
elseif exist('live_data', 'var') == 0 || isempty(live_data)
    % Initialize live structure
    live_data = init_live_data();
end

%% Update calibration database
% fprintf('Updating calibration data...\n');
live_data = updateCalDB(live_data, paths, opts);

%% Update video database
% fprintf('Updating video data...\n');
live_data = updateVidDB(live_data, paths, opts);

%% Update montage database
% fprintf('Updating montage data...\n');
live_data = updateMontageDB(live_data, paths);

% Update session completion
if ~live_data.done
    live_data.done = is_session_done(paths.root, live_data);
    % TODO: GUI will include a button which tells the system that
    % acquisition is done
end

%% Save current progress to disk
% save(fullfile(paths.root, LIVE_FNAME), 'live_data');


end

