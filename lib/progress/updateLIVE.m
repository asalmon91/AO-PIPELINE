function live_data = updateLIVE(paths, live_data)
%updateLIVE checks for new data

%% Constants
LIVE_FNAME = 'AO_PIPE_LIVE.mat';

%% Check for existing database
if (exist('live_data', 'var') == 0 || isempty(live_data)) && ...
        exist(fullfile(paths.root, LIVE_FNAME), 'file') ~= 0
    % First call and running on a previously run dataset
    load(fullfile(paths.root, LIVE_FNAME), 'live_data');
else
    % Initialize live structure
    live_data = init_live_data();
end

%% Update calibration database
live_data = updateCalDB(live_data);

%% Update video database
live_data = updateVidDB(live_data);

%% Update montage database
live_data = updateMontageDB(live_data);

% Update session completion
if ~live_data.done
    live_data.done = is_session_done(paths.root);
    % TODO: Session is only done is done.txt exists, all videos in raw have
    % gone through r/a and successful images have been placed in the
    % montage
end

end

