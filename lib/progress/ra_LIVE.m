function [ld, tasks] = ra_LIVE(ld, paths, opts, tasks, pool_id, gui)
%ra_LIVE Handles parallelization for registration and averaging

%% Return if empty
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
    return;
end

%% Process videos if there's an open slot
for ii=1:numel(tasks)
	if ~strcmp(tasks(ii).task_type, 'vid')
		continue;
	end
	
	%% Task begin
	if strcmp(tasks(ii).task_pff.State, 'unavailable')
% 		ld.vid.current_idx = getNextVidset(ld.vid);
% 		if ~isempty(ld.vid.current_idx)
		
		this_vidset = tasks(ii).task_obj;
		dsin_idx = matchVidsetToDsin(this_vidset, ld.cal.dsin);
		this_dsin = ld.cal.dsin(dsin_idx);
		tasks(ii).task_pff = parfeval(pool_id, @quickRA, 1, this_vidset, paths, this_dsin, ...
			opts, ld.vid.arfs_opts.pcc_thrs);
		update_pipe_progress(ld, paths, 'vid', gui);
		% DEV/DB
		%quickRA(this_vidset, paths, this_dsin, opts, ld.vid.arfs_opts.pcc_thrs);
		% END DEV/DB
% 		end
		
	%% Task finished
	elseif strcmp(tasks(ii).task_pff.State, 'finished') && isempty(tasks(ii).task_pff.Error)
		vid_idx = tasks(ii).task_db_address;
		ld.vid.vid_set(vid_idx) = fetchOutputs(tasks(ii).task_pff);
		
		% Update progress
		fprintf('Done processing video %i\n', ...
            ld.vid.vid_set(vid_idx).vidnum);
		update_pipe_progress(ld, paths, 'vid', gui);
		ld.state_changed = true; % For saving
		
		% Reset task
		tasks(ii) = ao_task();
		
	%% Task error
	elseif ~isempty(tasks(ii).task_pff.Error)
		error(getReport(tasks(ii).task_pff.Error))
	end
end

% %% Check for completed process
% if strcmp(tasks(ii).task_pff.State, 'finished') && isempty(tasks(ii).task_pff.Error)
%     out_vidset = fetchOutputs(tasks(ii).task_pff);
%     if out_vidset.processed
%         ld.vid.vid_set(ld.vid.current_idx) = out_vidset;
%         fprintf('Done processing video %i\n', ...
%             ld.vid.vid_set(ld.vid.current_idx).vidnum);
%     end
%     % Reset future object
%     tasks(ii).task_pff = parallel.FevalFuture();
%     update_pipe_progress(ld, paths, 'vid', gui);
% 	ld.state_changed = true;
% elseif ~isempty(tasks(ii).task_pff.Error)
%     % TODO: handle error
%     error(getReport(tasks(ii).task_pff.Error))
% end


end

