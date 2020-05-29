function [ld, tasks] = calibrate_LIVE(ld, paths, tasks, pool_id, gui)
%calibrate_LIVE basic handling of queue and evaluation

%% Return if empty
if isempty(ld.cal) || ~isfield(ld.cal, 'dsin') || isempty(ld.cal.dsin)
    return;
end

%% Process calibration files if there's an open slot
for ii=1:numel(tasks)
	if ~strcmp(tasks(ii).task_type, 'cal')
		continue;
	end
	
	%% Task begin
	if strcmp(tasks(ii).task_pff.State, 'unavailable')
% 		ld.cal.current_idx = getNextDsin(ld.cal);
% 		if ~isempty(ld.cal.current_idx)
	%         fprintf('Processing %1.2f deg desinusoid data\n', ...
	%             ld.cal.dsin(dsin_idx).fov);
		tasks(ii).task_obj.processing = true;
		tasks(ii).task_pff = parfeval(pool_id, @construct_dsin_mat, ...
			1, tasks(ii).task_obj, paths.cal);
		update_pipe_progress(ld, paths, 'cal', gui);
% 		end
	
	%% Task finished
	elseif strcmp(tasks(ii).task_pff.State, 'finished') && isempty(tasks(ii).task_pff.Error)
		cal_idx = tasks(ii).task_db_address;
		ld.cal.dsin(cal_idx) = fetchOutputs(tasks(ii).task_pff);
		
		% Update progress
		fprintf('Done processing %1.2f desinusoid data\n', ld.cal.dsin(cal_idx).fov);
		update_pipe_progress(ld, paths, 'cal', gui);
		ld.state_changed = true; % For saving
		
		% Reset task to default
		tasks(ii) = ao_task;
		
	%% Task Error
	elseif ~isempty(tasks(ii).task_pff.Error)
		error(getReport(tasks(ii).task_pff.Error))
	end
end

% %% Check for completed process
% if strcmp(pff.State, 'finished') && isempty(pff.Error)
%     out_dsin = fetchOutputs(pff);
%     if out_dsin.processed
%         ld.cal.dsin(ld.cal.current_idx) = out_dsin;
%         fprintf('Done processing %1.2f desinusoid data\n', ...
%             ld.cal.dsin(ld.cal.current_idx).fov);
%     end
%     % Reset future object
%     pff = parallel.FevalFuture();
%     update_pipe_progress(ld,paths,'cal',gui);
% 	ld.state_changed = true;
% elseif ~isempty(pff.Error)
%     % TODO: handle error
%     error(getReport(pff.Error))
%     % Reset future object
% %     pff = parallel.FevalFuture();
% end
% 
% 

end

