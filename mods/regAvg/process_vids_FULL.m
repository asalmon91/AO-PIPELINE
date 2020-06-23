function pipe_data = process_vids_FULL(pipe_data, paths, opts, q, gui)
%process_vids_FULL sets up the parallelization and progress reporting for
%the processing loop
% todo: Someday we want to include a pipeline architecture object that
% includes all the modules to use for processing and their adapters,
% e.g.: MODS:ARFS:DEMOTION:EMR, but I haven't really started planning how 
% this would be implemented
    
    
% Update progress tracker
afterEach(q, @(x) update_pipe_progress(pipe_data, paths, 'vid', gui, x));

pipe_data = updateVidDB(pipe_data, paths, opts);
vid_objs = pipe_data.vid.vid_set;
dsin_objs = pipe_data.cal.dsin;
% ii=1;
parfor ii=1:numel(vid_objs)
    % Skip if already run
    if ~vid_objs(ii).hasAnySuccess
        vid_objs(ii) = process_vidset(vid_objs(ii), dsin_objs, paths, opts, q);
		
		% DEV/DB This only works if not using parfor
%         pipe_data.vid.vid_set(ii) = vid_objs(ii);
%         save_full_pipe(pipe_data, opts, paths);
		% END DEV/DB
    end
    send(q, vid_objs(ii));
% 	uiwait(gui.fig, 1);
end
pipe_data.vid.vid_set = vid_objs;
save_full_pipe(pipe_data, opts, paths);
pipe_data = updateVidDB(pipe_data, paths, opts);
update_pipe_progress(pipe_data, paths, 'vid', gui);

end

