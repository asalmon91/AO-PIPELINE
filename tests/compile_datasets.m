%% Compile datasets
%% Imports
addpath(genpath('lib'), genpath('mods'));

%% Constants
src_root = '\\burns.rcc.mcw.edu\aoip\2-Purgatory\AO-PIPE-test\tmp\human-ctrl';
trg_root = 'C:\pipe-test\h2h';
method_tags = {'man', 'auto'};
n_datasets = 3;

% Folders, and desired file types
data_folder_list = {'Raw'; 'Calibration'; 'Montages'; 'Processed'};
wl_opts = [775, 790];
start_mods = {'confocal', 'direct', 'reflect'};
exclude_cal_tag = 'desinusoid';
exclude_wl = 680;
data_exts = {'.avi', '.mat'};

% Instructions
instruct_fname = 'processing-instructions.txt';

% Timing spreadsheets
man_timing_fname = 'manual-timing.xlsx';
auto_timing_fname = 'pipeline-timing.xlsx';

% .mat metadata fields
VID_NUM_ROOT = 'image_acquisition_settings';
VID_FNAMES = 'current_file_names';
VID_PATHS = 'destination_folders';

% cal files sometimes have identifying date strings
date_expr = '[_]\d{8}[_]';

masked_ID = 'DM_999999';

%% Filter the input directory datasets
src_contents = dir(src_root);
src_contents(~[src_contents.isdir]) = []; % Remove non-folders
src_contents(1:2) = []; % Remove relative directories
if numel(src_contents) < n_datasets
	error('Number of datasets (%i) less than number requested (%i)', ...
		numel(src_contents), n_datasets);
end
src_contents = src_contents(1:n_datasets); % Filter down to the first n datasets

%% Check paths and position files
for ii=1:numel(src_contents)
	% Paths
	path_file = fullfile(src_root, src_contents(ii).name, 'path.txt');
	fid = fopen(path_file, 'r');
	path_text = fgetl(fid);
	fclose(fid);
	
	% Fix if broken
	if ~exist(path_text, 'dir')
		warning('Dataset not found:\n%s', path_text);
		path_text = uigetdir(fullfile(src_root, src_contents(ii).name), 'Find missing dataset');
		if isnumeric(path_text)
			error('Canceled by user');
		elseif exist(path_text, 'dir')
			fid = fopen(path_file, 'w');
			fprintf(fid, '%s', path_text);
			fclose(fid);
		else
			error('Unknown errror occurred');
		end
	end
	
	src_contents(ii).orig_path = path_text;
	
	% Position files
	loc_file = find_AO_location_file(fullfile(src_root, src_contents(ii).name));
	if isempty(loc_file)
		warning('Location file not found in\n%s', fullfile(src_root, src_contents(ii).name));
		[loc_fname, loc_path] = uigetfile('*.csv', 'Select location file', ...
			fullfile(src_root, src_contents(ii).name));
		if isnumeric(loc_fname)
			error('Canceled by user');
		else
			loc_file = dir(fullfile(loc_path, loc_fname));
			loc_file.name = fullfile(loc_path, loc_fname);
		end
	end
	[loc_path, loc_name, loc_ext] = fileparts(loc_file.name);
	loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
	src_contents(ii).loc_file = fullfile(loc_path, [loc_name, loc_ext]);
	src_contents(ii).loc_data = loc_data;
end

%% Replicate the dataset by the number of methods
proc(numel(method_tags), 1).type = method_tags{end};
for ii=1:numel(proc)
	proc(ii).type = method_tags{ii};
	proc(ii).dsets = src_contents;
end

%% Make a waitbar
wb = waitbar(0, sprintf('Setting up %s', trg_root));
wb.Children.Title.Interpreter = 'none';
wb.Name = sprintf('%i/%i: %s', 1, numel(proc), proc(1).dsets(1).name);

%% Create these datasets in the target directory
for dset = 1:n_datasets
	
	for ptype = 1:numel(proc)
		
		%% Make a folder for each combination of dataset
		proc(ptype).dsets(dset).append_name = [proc(ptype).type, '-', src_contents(dset).name];
		proc(ptype).dsets(dset).out_folder = fullfile(trg_root, proc(ptype).dsets(dset).append_name);
		
		if ~exist(proc(ptype).dsets(dset).out_folder, 'dir')
			success = mkdir(proc(ptype).dsets(dset).out_folder);
			if ~success
				warning('Failed to make the folder\n%s', proc(ptype).dsets(dset).out_folder);
			else
				fprintf('Folder created:\n%s\n', proc(ptype).dsets(dset).out_folder);
			end
		else
			warning('Folder already exists:\n%s', proc(ptype).dsets(dset).out_folder);
		end
		
		%% Make the folders for data storage
		for ddir = 1:numel(data_folder_list)
			out_dir = fullfile(proc(ptype).dsets(dset).out_folder, data_folder_list{ddir});
			if ~exist(out_dir, 'dir')
				success = mkdir(out_dir);
				if ~success
					warning('Failed to create\n%s', ...
						fullfile(out_dir));
				end
			end
		end
		
		paths = initPaths(proc(ptype).dsets(dset).out_folder);
		
		%% Copy calibration data files
		in_path = fullfile(proc(ptype).dsets(dset).orig_path, 'Calibration');
		if ~exist(in_path, 'dir')
			error('Folder not found: %s', in_path);
		end
		cal_avi_dir = dir(fullfile(in_path, '*.avi'));
		cal_mat_dir = dir(fullfile(in_path, '*.mat'));
		remove = contains({cal_mat_dir.name}, exclude_cal_tag);
		cal_mat_dir(remove) = [];
		cal_files = [cal_avi_dir; cal_mat_dir];
		for cal = 1:numel(cal_files)
			if ~exist(fullfile(paths.cal, cal_files(cal).name), 'file')
				[success, msg] = copyfile(...
					fullfile(in_path, cal_files(cal).name), ...
					fullfile(paths.cal, cal_files(cal).name));
				if ~success
					warning(msg);
				end
			end
		end
		
		%% Copy location file
		[loc_path, loc_name, loc_ext] = fileparts(proc(ptype).dsets(dset).loc_file);
		if ~exist(fullfile(paths.raw, [loc_name, loc_ext]), 'file')
			[success, msg] = copyfile(...
				proc(ptype).dsets(dset).loc_file, ...
				fullfile(paths.raw, [loc_name, loc_ext]));
			if ~success
				warning(msg);
			end
		end
		
		%% Start retina data files based on the location file
		loc_data = proc(ptype).dsets(dset).loc_data;
		in_path = fullfile(proc(ptype).dsets(dset).orig_path, 'Raw');
		for loc = 1:numel(loc_data.vidnums)
			for mod = 1:numel(start_mods)
				for wl = 1:numel(wl_opts)
					for ext = 1:numel(data_exts)
						search_term = sprintf('*%inm*%s*%s%s', ...
							wl_opts(wl), start_mods{mod}, loc_data.vidnums{loc}, data_exts{ext});
						search_result = dir(fullfile(in_path, search_term));
						if numel(search_result) ~= 1
							if numel(search_result) > 1
								warning('Multiple results found when searching for %s');
								for result = 1:numel(search_results)
									warning(search_results(result).name);
								end
							end
							continue;
						end
						
						% Copy files
						if ~exist(fullfile(paths.raw, search_result.name), 'file')
							[success, msg] = copyfile(...
								fullfile(in_path, search_result.name), ...
								fullfile(paths.raw, search_result.name));
							if success
								fprintf('%s\n', search_result.name);
							else
								warning(msg);
							end
						end
					end % end ext
				end % end wl
			end % end mod
			
			waitbar(loc/numel(loc_data.vidnums), wb, loc_data.vidnums{loc});
		end % end loc
		wb.Name = sprintf('%i/%i: %s', 1, numel(proc), proc(ptype).dsets(dset).append_name);
	end % end pytpe
end % end dset

%% Renumber AO videos to simplify processing curated datasets
for dset = 1:n_datasets
	for ptype = 1:numel(proc)
		paths = initPaths(proc(ptype).dsets(dset).out_folder);
		resetAOvidnums(paths.raw);
	end
end

%% Randomize and mask
[~,Ir] = sort(rand(n_datasets*numel(method_tags), 1));
k=0;
for dset = 1:n_datasets
	for ptype = 1:numel(proc)
		k=k+1;
		out_folder_name = proc(ptype).dsets(dset).out_folder;
		new_out_folder_name = fullfile(trg_root, sprintf('%i', Ir(k)));
		movefile(out_folder_name, new_out_folder_name);
		proc(ptype).dsets(dset).masked_folder_name = new_out_folder_name;
		
		
		% Make a processing instructions file and copy timing spreadsheet
		fid = fopen(fullfile(new_out_folder_name, instruct_fname), 'w');
		if strcmp(proc(ptype).type, 'man')
			instruct_text = 'Process this dataset manually';
			
			out_timing_fname = man_timing_fname;
		elseif strcmp(proc(ptype).type, 'auto')
			instruct_text = 'Process this dataset with the AO-PIPELINE';
			
			out_timing_fname = auto_timing_fname;
		else
			error('Somehow an unexpected processing method (%s) got in here', proc(ptype).type);
		end
		% Write text file
		fprintf(fid, '%s', instruct_text);
		fclose(fid);
		% Copy timing file
		[success, msg] = copyfile(...
				fullfile(src_root, out_timing_fname), ...
				fullfile(new_out_folder_name, out_timing_fname));
		if ~success
			warning(msg);
		end
		
		% Rename all videos and headers
		new_ID = masked_ID;
		proc(ptype).dsets(dset).new_ID = new_ID;
		paths = initPaths(new_out_folder_name);
		
		old_ID = [];
		raw_dir = dir(paths.raw);
		for f = 1:numel(raw_dir)
			if raw_dir(f).isdir
				continue;
			end
			if isempty(old_ID)
				old_ID = getID(raw_dir(f).name);
				if strcmp(old_ID, new_ID)
					% Must have already done this dataset
					continue;
				end
				proc(ptype).dsets(dset).orig_ID = old_ID;
			end
			
			% Rename
			in_fname = raw_dir(f).name;
			out_fname = strrep(in_fname, old_ID, new_ID);
			if ~exist(fullfile(paths.raw, out_fname), 'file')
				movefile(...
					fullfile(paths.raw, in_fname), ...
					fullfile(paths.raw, out_fname));
			end
			
			% If .mat, remove identifying info
			if strcmp(out_fname(end-3:end), '.mat')
				load(fullfile(paths.raw, out_fname), VID_NUM_ROOT)
				eval(sprintf('%s.%s = '''';', VID_NUM_ROOT, VID_FNAMES)); % erase output names
				eval(sprintf('%s.%s = '''';', VID_NUM_ROOT, VID_PATHS)); % erase output path
				save(fullfile(paths.raw, out_fname), VID_NUM_ROOT, ...
					'-append', '-nocompression');
			end
		end
		
		% Remove identifying info from calibration files as well
		rem_files = dir(fullfile(paths.cal, sprintf('*_%inm_*', exclude_wl)));
		for f = 1:numel(rem_files)
			delete(fullfile(paths.cal, rem_files(f).name));
		end
		
		cal_files = dir(paths.cal);
		for f = 1:numel(cal_files)
			if cal_files(f).isdir
				continue;
			end
			
			date_expr_start = regexp(cal_files(f).name, date_expr);
			if ~isempty(date_expr_start)
				new_cal_name = strrep(cal_files(f).name, ...
					cal_files(f).name(date_expr_start:date_expr_start+8), '');
				movefile(...
					fullfile(paths.cal, cal_files(f).name), ...
					fullfile(paths.cal, new_cal_name));
			else
				new_cal_name = cal_files(f).name;
			end
			
			% If .mat, remove identifying info
			if strcmp(new_cal_name(end-3:end), '.mat')
				load(fullfile(paths.cal, new_cal_name), VID_NUM_ROOT)
				eval(sprintf('%s.%s = '''';', VID_NUM_ROOT, VID_FNAMES)); % erase output names
				eval(sprintf('%s.%s = '''';', VID_NUM_ROOT, VID_PATHS)); % erase output path
				save(fullfile(paths.cal, new_cal_name), VID_NUM_ROOT, ...
					'-append', '-nocompression');
			end
		end
	end
end

%% Perhaps most importantly, save proc!
save(fullfile(src_root, 'pipe-test-masked.mat'), 'proc')

