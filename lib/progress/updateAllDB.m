function db = updateAllDB(db, paths, opts, gui)
%updateAllDB updates the database variable with calibration and video info

%% Update databases
db = updateCalDB(db, paths, opts);
db = updateVidDB(db, paths, opts);

%% Update progress window
update_pipe_progress(db, paths, 'cal', gui)
update_pipe_progress(db, paths, 'vid', gui)
update_pipe_progress(db, paths, 'mon', gui)

end

