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
for ii=1:numel(vid_objs)
    % Skip if already run
    if ~vid_objs(ii).hasAnySuccess
        vid_objs(ii) = process_vidset(vid_objs(ii), dsin_objs, paths, opts, q);
    end
    send(q, vid_objs(ii));
end
pipe_data.vid.vid_set = vid_objs;
pipe_data = updateVidDB(pipe_data, paths, opts);
update_pipe_progress(pipe_data, paths, 'vid', gui);

end

