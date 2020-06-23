classdef ao_task
	%ao_task describes a job for one of the modules to do
	
	properties
		task_type char = ''; % Options are "cal" "vid" and "mon"
		task_obj = []; % Either a dsin obj, vidset obj, or cell array of image file names
		task_ts = []; % Will be a timestamp
		task_db_address = []; % Address in the database where task_obj belongs
		% This is just an indexing array, not a hex address
		task_pff = parallel.FevalFuture; % handles status and extracting output
	end
	
	methods
		function obj = ao_task()
			%ao_task Construct an instance of this class
			obj.task_ts = clock;
			obj.task_pff = parallel.FevalFuture;
		end
		
		function obj = setTask(obj, in_obj, db_address)
			obj.task_obj = in_obj;
			if isa(in_obj, 'dsin')
				obj.task_type = 'cal';
				obj.task_db_address = db_address;
				
			elseif isa(in_obj, 'vidset')
				obj.task_type = 'vid';
				obj.task_db_address = db_address;
				
			elseif isa(in_obj, 'cell')
				obj.task_type = 'mon';
			else
				error('Unknown input');
			end
		end
	end
end

