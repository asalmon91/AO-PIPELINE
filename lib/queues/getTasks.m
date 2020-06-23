function tasks = getTasks(tasks, db, paths, opts)
%getTasks dynamically assigns a task to each thread
%   Tasks are assigned by priority, 1: Calibration, 2: Montaging, 3: Registration/Averaging

%% Priorities
priority = {'cal';'mon';'vid'};

%% First iteration, setup
this_pool = gcp('nocreate');
n_workers = this_pool.NumWorkers;	
if exist('tasks', 'var') == 0 || isempty(tasks)
	tasks = repmat(ao_task, n_workers, 1);
else
	if numel(tasks) ~= n_workers
		error('Incompatible task array (%i) and parallel pool (%i)', ...
			numel(tasks), n_workers);
	end
end

%% If all tasks are busy, return
tasks_running = false(size(tasks));
for ii=1:numel(tasks)
	tasks_running(ii) = ~strcmpi(tasks(ii).task_pff.State, 'unavailable');
end
if all(tasks_running)
	return;
end

%% Get open slots
open_slots = cellfun(@isempty, {tasks.task_type}');
filled_slots = ~open_slots;

%% Add tasks based on priority
for pp=1:numel(priority)
	if ~isfield(db, priority{pp}) || isempty(db.(priority{pp}))
		continue;
	end
	if ~any(open_slots)
		break;
	end
	
	switch priority{pp}
		case 'cal'
			[ready_dsins, db_keys] = getReadyDsin(db.cal.dsin);
			if isempty(ready_dsins)
				continue;
			end
			% Remove ones that are already in the queue
			check_tasks = tasks(filled_slots & strcmp({tasks.task_type}', 'cal'));
			check_addresses = [check_tasks.task_db_address]';
			remove = false(size(ready_dsins));
			for ii=1:numel(ready_dsins)
				remove(ii) = ismember(db_keys(ii), check_addresses);
			end
			ready_dsins(remove) = [];
			db_keys(remove) = [];
			
			% Add to queue
			for ii=1:numel(ready_dsins)
				if any(open_slots)
					next_open_slot = find(open_slots, 1);
					open_slots(next_open_slot) = false;
				else
					break;
				end
				tasks(next_open_slot) = tasks(next_open_slot).setTask(ready_dsins(ii), db_keys(ii));
				fprintf('Task %i: %s, %0.2f degree fov\n', ...
					next_open_slot, 'cal', ready_dsins(ii).fov);
			end
			
		case 'vid'
			if ~isfield(db.vid, 'vid_set') || isempty(db.vid.vid_set)
				continue;
			end
			
			[ready_vidsets, db_keys] = getReadyVidsets(db.vid.vid_set);
			if isempty(ready_vidsets)
				continue;
			end
			% Until I make a working montage class, there's going to be a bit of redundancy here
			% This works the same as the calibration queue handling
			% Remove ones that are already in the queue
			check_tasks = tasks(filled_slots & strcmp({tasks.task_type}', 'vid'));
			check_addresses = [check_tasks.task_db_address]';
			remove = false(size(ready_vidsets));
			for ii=1:numel(ready_vidsets)
				remove(ii) = ismember(db_keys(ii), check_addresses);
			end
			ready_vidsets(remove) = [];
			db_keys(remove) = [];
			
			% Add to queue
			for ii=1:numel(ready_vidsets)
				if any(open_slots)
					next_open_slot = find(open_slots, 1);
					open_slots(next_open_slot) = false;
				else
					break;
				end
				tasks(next_open_slot) = tasks(next_open_slot).setTask(ready_vidsets(ii), db_keys(ii));
				fprintf('Task %i: video #%i\n', ...
					next_open_slot, ready_vidsets(ii).vidnum);
			end
			
		case 'mon'
			% todo: modify ucl automontager to include an append mode
			% This one's a bit more complicated, until I figure out a non-redundant way to append
			% images to an existing montage with the UCL automontager, we can only allow one thread
			
			% So first check if there is already a montage in the queue
			check_tasks = tasks(filled_slots & strcmp({tasks.task_type}', 'mon'));
			if ~isempty(check_tasks)
				continue;
			end
			
			img_fnames = getNextMontage(db, paths, db.mon.opts.mods);
			if numel(img_fnames) < 2
				continue;
			end
			next_open_slot = find(open_slots, 1);
			open_slots(next_open_slot) = false;
			tasks(next_open_slot) = tasks(next_open_slot).setTask(img_fnames);
			fprintf('Task %i: %s\n', next_open_slot, 'mon');
			disp(img_fnames);
	end
	
	% Update filled slots
	filled_slots = ~cellfun(@isempty, {tasks.task_type}');
end

end

