function resetAOvidnums(in_path, loc_file_ffname)
%resetAOvidnums renumbers AO videos so that they're continuous (for use in the user-interaction
%experiment)

%% Constants
VID_NUM_ROOT = 'image_acquisition_settings';
VID_NUM_FIELD = 'current_movie_number';

%% Setup output
out_path = fullfile(in_path, 'renum');
if exist(out_path, 'dir') == 0
    [success, msg] = mkdir(out_path);
	if ~success && ~strcmp(msg, 'Directory already exists.')
		warning(msg);
	end
else
    % Check if there's anything in there
    avi_search = dir(fullfile(out_path, '*.avi'));
    mat_search = dir(fullfile(out_path, '*.mat'));
    if ~isempty(avi_search) || ~isempty(mat_search)
        re = questdlg(...
            'Output path is not empty, okay to output here?', ...
            'Possible overwrite', 'Yes', 'No', 'No');
        if isempty(re) || strcmp(re, 'No')
            return;
        end 
    end
end

%% Make a waitbar
% wb = waitbar(0, sprintf('Copying files to %s', out_path));
% wb.Children.Title.Interpreter = 'none';

%% Gather information about the videos in this directory
% Find all files
in_avi = dir(fullfile(in_path, '*.avi'));
% in_mat = dir(fullfile(in_path, '*.mat'));
if isempty(in_avi)
    errordlg(sprintf('No .avi''s found in %s', in_path), '404');
end

% Determine sets of simultaneously acquired files
[vidnum_str, ao_idx] = determineAOSets({in_avi.name}');

% Get video numbers, rename starting at 0
vid_nums = str2double(vidnum_str);
new_vid_nums = (0:numel(vid_nums) -1)';

% new_vid_nums = vid_nums + (new_first_num - min(vid_nums));
% Convert numbers to strings
new_vid_num_str = cellfun(@(x) sprintf('%i', x), num2cell(new_vid_nums), ...
    'uniformoutput', false);
% Zero-pad
new_vid_num_str = cellfun(@(x) pad(x, 4, 'left', '0'), new_vid_num_str, ...
    'uniformoutput', false);

%% Start copying
for ii=1:numel(vid_nums)
    current_set = in_avi(ao_idx == ii);
    
    for jj=1:numel(current_set)
        % AVI
        in_fname = current_set(jj).name;
        out_fname = strrep(in_fname, vidnum_str{ii}, new_vid_num_str{ii});
		if exist(fullfile(out_path, out_fname), 'file')
			warning('%s already exists', out_fname);
			continue;
		end
		
%         % Don't move if we screwed up
%         if strcmp(in_fname, out_fname)
%             error('Failed to rename %s', in_fname);
%         end
        % Move
        movefile(...
            fullfile(in_path, in_fname), ...
            fullfile(out_path, out_fname));
        
        % MAT
        mat_fname = strrep(in_fname, '.avi', '.mat');
        if exist(fullfile(in_path, mat_fname), 'file') ~= 0
            % Prepare output name
            out_mat_fname = strrep(mat_fname, ...
                vidnum_str{ii}, new_vid_num_str{ii});
%             if strcmp(mat_fname, out_mat_fname)
%                 error('Failed to rename %s', mat_fname);
%             end
            
            % Copy
            movefile(...
                fullfile(in_path, mat_fname), ...
                fullfile(out_path, out_mat_fname));
            
            % Adjust video number metadata
            load(fullfile(out_path, out_mat_fname), VID_NUM_ROOT)
            old_vid_num = eval(sprintf('%s.%s', VID_NUM_ROOT, VID_NUM_FIELD));
            eval(sprintf('%s.%s = %i;', VID_NUM_ROOT, VID_NUM_FIELD, ...
                cast(new_vid_nums(ii)+1, class(old_vid_num))));
            save(fullfile(out_path, out_mat_fname), VID_NUM_ROOT, ...
                '-append', '-nocompression');
            %+1 because names are 0-based
        end
    end
    
%     % Update progress
%     waitbar(ii/numel(vid_nums), wb, ...
%         sprintf('Changed video %i to %i', ...
%         vid_nums(ii), new_vid_nums(ii)));
end

%% Copy and renumber position file
if ~exist('loc_file_ffname', 'var') || isempty(loc_file_ffname)
	loc_file = find_AO_location_file(in_path);
	loc_file_ffname = loc_file.name;
end
% [~, loc_name, loc_ext] = fileparts(loc_file_ffname);
loc_data = readFixGuiFile(loc_file_ffname);
loc_data(2:end, 1) = mat2cell(new_vid_nums +1, ones(size(new_vid_nums))); % +1 because fix-gui is 1-based
writecell(loc_data, loc_file_ffname); % Overwrite this file (don't worry we have a backup in src_root, see compile_datasets)

%% Move all files back to in_path and remove out_path
out_files = dir(out_path);
for ii=1:numel(out_files)
	if out_files(ii).isdir
		continue;
	end
	movefile(...
		fullfile(out_path, out_files(ii).name), ...
		fullfile(in_path, out_files(ii).name));
end

rmdir(out_path, 's');
% % Done!
% close(wb);

end

