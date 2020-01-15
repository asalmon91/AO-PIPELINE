%% Imports
addpath(genpath(fullfile('..', 'lib')));
addpath(genpath(fullfile('..', 'mod')));

%% Constants
FR = 16.666; % frame rate (seconds)
% write lag, very useful to induce some extra lag when writing videos to
% test performace while some videos are in the middle of being written
WRITE_LAG = 1/FR; % (seconds)
WAIT_RANGE = [10, 20]; % seconds; min + rand between 0 and max
N_PAD = 4;
VID_NUM_EXP = sprintf('%s%s%s', ...
    '[_]', repmat('\d', 1, N_PAD), '[.]mat');

%% Get source and target directories
src = uigetdir('.', 'Select source root directory');
if isnumeric(src)
    return;
end
trg = uigetdir(src, 'Select target root directory');
if isnumeric(trg)
    return;
end
src_paths = initPaths(src);
trg_paths = initPaths(trg);

%% Get position file, read, process
loc_file_data = find_AO_location_file(src);
if isempty(loc_file_data)
    [pos_fname, pos_path] = uigetfile(...
        {'*.csv', 'comma-separated values'; 
        '*.xlsx', 'excel file',}, ...
        'Select position file', src, 'multiselect', 'off');
    loc_file_data = subdir(fullfile(pos_path, pos_fname));
end
[loc_path, loc_name, loc_ext] = fileparts(loc_file_data.name);
if strcmp(loc_ext, '.csv')
    loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
elseif strcmp(loc_ext, '.xlsx')
    % TODO: fix animal imaging notes processing
    aviSets = getAviSets(src_paths.raw);
    [~, eye_tag] = getDateAndEye(src_paths.root);
    loc_data = processAnimalLocFile(loc_path, [loc_name, loc_ext], ...
            'AO_Img', aviSets, eye_tag);
end
updatePosFile(loc_data, [], fullfile(trg_paths.raw, 'locations.csv'));

%% Waitbar
wb = waitbar(0, trg);
wb.Children.Title.Interpreter = 'none';

%% Load and re-write calibration files
% Can't just copy files because this doesn't change the timestamp, which
% makes this simulation not realistic
if exist(trg_paths.cal, 'dir') == 0
    mkdir(cal_out_path);
end
cal_avi_dir = dir(fullfile(src_paths.cal, '*.avi'));
for ii=1:numel(cal_avi_dir)
    % Update total progress (for this loop)
    wb.Name = sprintf('%i/%i, %s', ii, numel(cal_avi_dir), ...
        cal_avi_dir(ii).name);
    
    % Read video
    vid = fn_read_AVI(fullfile(src_paths.cal, cal_avi_dir(ii).name), wb);
    
    % Load header and write to target directory
    mat_fname = strrep(cal_avi_dir(ii).name, '.avi', '.mat');
    load(fullfile(src_paths.cal, mat_fname));
    save(fullfile(trg_paths.cal, mat_fname), ...
        'clinical_version', ...
        'frame_numbers', ...
        'frame_time_stamps', ...
        'image_acquisition_settings', ...
        'image_resolution_calculation_settings', ...
        'optical_scanners_settings');
    
    % Write video
    fn_write_AVI(fullfile(trg_paths.cal, cal_avi_dir(ii).name), vid, ...
        FR, wb, WRITE_LAG)
end

%% Get all aoslo headers
all_aoslo_headers = dir(fullfile(src_paths.raw, '*.mat'));
search_results = regexp({all_aoslo_headers.name}', VID_NUM_EXP);
remove = cellfun(@isempty, search_results);
all_aoslo_headers(remove) = [];
header_fnames = {all_aoslo_headers.name}';
vid_num_start = search_results(~remove);

%% Extract video number from each file name
vid_nums = cellfun(@(x,y) (x( y+1 : y + N_PAD)), ...
    header_fnames, vid_num_start, 'uniformoutput', false);
% Find unique entries
u_vid_nums = unique(vid_nums);

for ii=1:numel(u_vid_nums)
    % Update total progress (for this loop)
    wb.Name = sprintf('%i/%i, %s', ii, numel(u_vid_nums), ...
        u_vid_nums{ii});
    
    % Get the current vidset
    current_heads = header_fnames(...
        contains(header_fnames, [u_vid_nums{ii}, '.mat']));
    current_avis = strrep(current_heads, '.mat', '.avi');
    
    %% Read all videos in this set
    vids = cell(size(current_avis));
    vws = vids;
    for jj=1:numel(current_avis)
        % Read
        vids{jj} = fn_read_AVI(...
            fullfile(src_paths.raw, current_avis{jj}), wb);
    end
    
    %% Update position file
    updatePosFile(loc_data, u_vid_nums(1:ii), ...
        fullfile(trg_paths.raw, 'locations.csv'));
    
    %% Create video writers and headers
    for jj=1:numel(current_avis)
        % Create writer (but don't write just yet)
        vws{jj} = VideoWriter(...
            fullfile(trg_paths.raw, current_avis{jj}), 'grayscale avi'); %#ok<TNMLP>
        open(vws{jj});
        
        % Load and write headers
        load(fullfile(src_paths.raw, current_heads{jj}));
        save(fullfile(trg_paths.raw, current_heads{jj}), ...
            'clinical_version', ...
            'frame_numbers', ...
            'frame_time_stamps', ...
            'image_acquisition_settings', ...
            'image_resolution_calculation_settings', ...
            'optical_scanners_settings');
    end
    
    %% Set up parallel writing
    n_frame_list = cellfun(@(x) size(x, 3), vids);
    n_frames = n_frame_list(1);
    if ~all(n_frame_list == n_frames)
        n_frames = min(n_frame_list);
        warning('Frame # don''t match for vid %s', u_vid_nums{ii});
    end
    
    %% Write each frame of all videos in ~parallel
    for nn=1:n_frames
        for jj=1:numel(current_avis)
            writeVideo(vws{jj}, vids{jj}(:,:,nn));
        end
        pause(WRITE_LAG);
        
        waitbar(nn/n_frames, wb, sprintf('Writing %s', u_vid_nums{ii}));
    end
    
    %% Finish writing
    for jj=1:numel(current_avis)
        close(vws{jj});
    end
    
    %% Simulate delay between "acquisitions"
    wait_time = WAIT_RANGE(1) + randi([0, WAIT_RANGE(2)], 1);
    fprintf('Waiting %is before next "acquisition"\n', wait_time);
    pause(wait_time);
end

%% Indicate that you're done by creating an empty text file
root_path = fullfile(trg, '..');
done_fname = 'done.txt';
out_ffname = fullfile(root_path, done_fname);
fid = fopen(out_ffname, 'w');
fclose(fid);



