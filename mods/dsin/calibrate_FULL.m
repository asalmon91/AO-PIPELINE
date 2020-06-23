function db = calibrate_FULL(db, paths, opts, qc, gui)
%calibrateFULL handles calibration :)

% Update progress tracker
afterEach(qc, @(x) update_pipe_progress(db, paths, 'cal', gui, x))

% Update database
db = updateCalDB(db, paths, opts);
update_pipe_progress(db, paths, 'cal', gui)

% Extract dsin objects
dsin_objs = db.cal.dsin;
cal_path = paths.cal;
% parfor those suckers
parfor ii=1:numel(dsin_objs)
    if ~dsin_objs(ii).processed
        dsin_objs(ii) = construct_dsin_mat(dsin_objs(ii), cal_path)
        % Update 
        send(qc, dsin_objs(ii));
    end
end
db.cal.dsin = dsin_objs;
db = updateCalDB(db, paths, opts);
update_pipe_progress(db, paths, 'cal', gui)

end

