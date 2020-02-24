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
if ~live_data.done
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
save(fullfile(paths.root, live_data.filename), 'live_data', 'opts');
% Put in back on
if exist('guih', 'var') && ~isempty(guih)
    live_data.gui_handles = guih;
end

end

