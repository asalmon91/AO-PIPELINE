function [live_data, montage_app] = updateLIVE(paths, live_data, opts, gui, montage_app)
%updateLIVE checks for new data

%% Update calibration database
% fprintf('Updating calibration data...\n');
live_data = updateCalDB(live_data, paths, opts);

%% Update video database
% fprintf('Updating video data...\n');
live_data = updateVidDB(live_data, paths, opts);

%% Update montage database
if exist('montage_app', 'var') == 0 || isempty(montage_app)
    montage_app = [];
end
live_data = updateMontageDB(live_data, paths, gui, montage_app);

% Update session completion
if isvalid(gui) && ~live_data.done
    live_data.done = gui.finished;
end

%% Save current progress to disk
% Remove figure handle from live_data to avoid constant warnings and
% excessive file size
if isfield(live_data, 'gui_handles') && ~isempty(live_data.gui_handles)
    guih = live_data.gui_handles;
    live_data = rmfield(live_data, 'gui_handles');
end
% Save
db_ffname = fullfile(paths.root, live_data.filename);
if exist(db_ffname, 'file') == 0
	save(db_ffname, 'live_data', 'paths', 'opts');
elseif isfield(live_data, 'state_changed') && live_data.state_changed
	save(db_ffname, 'live_data', 'paths', 'opts', '-append');
	live_data.state_changed = false;
end
% Put in back on
if exist('guih', 'var') && ~isempty(guih)
    live_data.gui_handles = guih;
end

end

