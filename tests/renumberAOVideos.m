%% Renumber videos
% Important for merging datasets for use with AO-PIPE

%% Constants
VID_NUM_ROOT = 'image_acquisition_settings';
VID_NUM_FIELD = 'current_movie_number';

%% Get user input
% Path to videos
in_path = uigetdir('.', 'Select directory containing videos to renumber');
if isnumeric(in_path)
    return;
end

% New first video number
def_ans = {'0'};
input_is_valid = false;
while ~input_is_valid
    re = inputdlg('Input the new first video number', ...
        'First video #', [1, 50], def_ans);
    if isempty(re)
        return;
    end
    if exist('wd', 'var') ~= 0 && isvalid(wd)
        close(wd);
    end
    
    new_first_num = str2double(re{1});
    if ~isnan(new_first_num) && new_first_num >=0 && ...
            isreal(new_first_num) && isfinite(new_first_num) && ...
            mod(new_first_num, 1) == 0
        input_is_valid = true;
    else
        wd = warndlg(...
            'Input must be a finite, real, positive scalar integer', ...
            'Input not recognized');
    end
end

%% Setup output
out_path = fullfile(in_path, 'renum');
if exist(out_path, 'dir') == 0
    mkdir(out_path);
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
wb = waitbar(0, sprintf('Copying files to %s', out_path));
wb.Children.Title.Interpreter = 'none';

%% Gather information about the videos in this directory
% Find all files
in_avi = dir(fullfile(in_path, '*.avi'));
in_mat = dir(fullfile(in_path, '*.mat'));
if isempty(in_avi)
    errordlg(sprintf('No .avi''s found in %s', in_path), '404');
end

% Determine sets of simultaneously acquired files
[vidnum_str, ao_idx] = determineAOSets({in_avi.name}');

% Get video numbers, shift so that the first one matches the user-input
% first video number
vid_nums = str2double(vidnum_str);
new_vid_nums = vid_nums + (new_first_num - min(vid_nums));
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
        % Don't copy if we screwed up
        if strcmp(in_fname, out_fname)
            error('Failed to rename %s', in_fname);
        end
        % Copy
        copyfile(...
            fullfile(in_path, in_fname), ...
            fullfile(out_path, out_fname));
        
        % MAT
        mat_fname = strrep(in_fname, '.avi', '.mat');
        if exist(fullfile(in_path, mat_fname), 'file') ~= 0
            % Prepare output name
            out_mat_fname = strrep(mat_fname, ...
                vidnum_str{ii}, new_vid_num_str{ii});
            if strcmp(mat_fname, out_mat_fname)
                error('Failed to rename %s', mat_fname);
            end
            
            % Copy
            copyfile(...
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
    
    % Update progress
    waitbar(ii/numel(vid_nums), wb, ...
        sprintf('Changed video %i to %i', ...
        vid_nums(ii), new_vid_nums(ii)));
end

% Done!
close(wb);





