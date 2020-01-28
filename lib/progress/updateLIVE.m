function [live_data, opts] = updateLIVE(paths, live_data, opts)
%updateLIVE checks for new data

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
% Remove figure handle from live_data to avoid constant warnings and
% excessive file size
if isfield(live_data, 'gui_handles') && ~isempty(live_data.gui_handles)
    guih = live_data.gui_handles;
    live_data = rmfield(live_data, 'gui_handles');
end
% Save
save(fullfile(paths.root, live_data.filename), 'live_data', 'opts');
% Put in back on
if exist('guih', 'var') && ~isempty(guih)
    live_data.gui_handles = guih;
end

end

