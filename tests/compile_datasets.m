%% Compile datasets
%% Imports
addpath(genpath('lib'), genpath('mods'));

%% Constants
src_root = 'D:\workspace\pipe\subject_info\validation\1-ctrl';
trg_root = '\\burns.rcc.mcw.edu\AOIP\2-Purgatory\AO-PIPE-test\h2h';
method_tags = {'man', 'auto'};
n_datasets = 3;

data_folder_list = {'Raw'; 'Calibration'; 'Montages'; 'Processed'};
wl_opts = [775, 790];
start_mods = {'confocal', 'direct', 'reflect'};
exclude_cal_tag = 'desinusoid';
data_exts = {'.avi', '.mat'};

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
						copyfile(fullfile(in_path, search_result.name), ...
							paths.raw, search_result.name);
						fprintf('%s\n', search_result.name);
					end
				end
			end
			
			waitbar(loc/numel(loc_data.vidnums), wb, loc_data.vidnums{loc});
		end
	end



end

	


