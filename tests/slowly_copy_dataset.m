%% Imports
addpath(genpath(fullfile('..', 'lib')));
addpath(genpath(fullfile('..', 'mods')));
import System.IO.File.GetCreationTime

%% Constants
IGNORE_WL = {'680nm'};
FR = 16.666; % frame rate (seconds)
% write lag, very useful to induce some extra lag when writing videos to
% test performace while some videos are in the middle of being written
WRITE_LAG = 1/FR; % (seconds)
N_PAD = 4;
VID_NUM_EXP = sprintf('%s%s%s', ...
    '[_]', repmat('\d', 1, N_PAD), '[.]mat');
USE_REAL_DELAYS = true; % Change this to true if transferring between two local locations

%% Get source and target directories
% src = uigetdir('.', 'Select source root directory');
% if isnumeric(src)
%     return;
% end
% trg = uigetdir(src, 'Select target root directory');
% if isnumeric(trg)
%     return;
% end
src = 'D:\workspace\JC_0605\src\2019_06_04_OD';
trg = 'D:\workspace\JC_0605\AO_2_3_SLO\2019_06_04_OD';
src_paths = initPaths(src);
trg_paths = initPaths(trg);

%% Get position file, read, process
[~, eye_tag] = getDateAndEye(src);
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

%% Get delays from videos
create_times = zeros(size(cal_avi_dir));
for ii=1:numel(create_times)
	d = GetCreationTime(...
		fullfile(src_paths.cal, cal_avi_dir(ii).name));
	t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
	create_times(ii) = datenum(t_create)*(24*3600);
end
% Sort to avoid alphabetic bias
[create_times, I] = sort(create_times, 'ascend');
cal_avi_dir = cal_avi_dir(I);

% Get delays
delays = diff(create_times);
delays = [delays; 0]; % Add a zero at the end to move on to videos with no delay

%% Start copying calibration files
for ii=1:numel(cal_avi_dir)
    if any(contains(cal_avi_dir(ii).name, IGNORE_WL))
        continue;
    end
    
    % Don't overwrite
    out_ffname = fullfile(trg_paths.cal, cal_avi_dir(ii).name);
    if exist(out_ffname, 'file') ~= 0
        continue;
    end
    
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
    fn_write_AVI(out_ffname, vid, FR, wb, WRITE_LAG)
    
    if ii < numel(cal_avi_dir)
        if delays(ii) < 1
            delays(ii) = 5;
        end
        waitbar(1, wb, sprintf('%is delay.', round(delays(ii))));
        if USE_REAL_DELAYS
            pause(delays(ii));
        end
    end
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

%% Get delays from the headers
ts = zeros(size(u_vid_nums));
for ii=1:numel(u_vid_nums)
    vn_dir = dir(fullfile(src_paths.raw, ...
        sprintf('*_%s.mat', u_vid_nums{ii})));
    ts(ii) = min([vn_dir.datenum]);
end
delays = diff(ts)*(24*3600);

%% Start writing videos
for ii=1:numel(u_vid_nums)
    % Update total progress (for this loop)
    wb.Name = sprintf('%i/%i, %s', ii, numel(u_vid_nums), ...
        u_vid_nums{ii});
    
    % Get the current vidset
    current_heads = header_fnames(...
        contains(header_fnames, [u_vid_nums{ii}, '.mat']));
    current_avis = strrep(current_heads, '.mat', '.avi');
    
    % Skip any unwanted wavelengths
    remove = false(size(current_avis));
    for jj=1:numel(current_avis)
        if any(contains(current_avis{jj}, IGNORE_WL))
            remove(jj) = true;
        end
    end
    current_avis(remove) = [];
    if isempty(current_avis)
        continue;
    end
    
    % Don't overwrite
    out_ffnames = cell(size(current_avis));
    trg_exists = false(size(current_avis));
    for jj=1:numel(current_avis)
        out_ffnames{jj} = fullfile(trg_paths.raw, current_avis{jj});
        trg_exists(jj) = exist(out_ffnames{jj}, 'file') ~= 0;
    end
    if all(trg_exists)
        continue;
    end
    
    %% Read all videos in this set
    vids = cell(size(current_avis));
    vws = vids;
    for jj=1:numel(current_avis)
        % Read
        success = false;
        k = 0;
        max_iter = 100;
        while ~success
            try
                k=k+1;
                if k > max_iter
                    error('Max iterations exceeded');
                end
                vids{jj} = fn_read_AVI(...
                    fullfile(src_paths.raw, current_avis{jj}), wb);
            catch err
                % Sometimes it loses access to videos on network drives,
                % just try again until it works
                continue;
            end
            success = true;
        end
    end
    
    %% Update position file
    updatePosFile(loc_data, u_vid_nums(1:ii), ...
        fullfile(trg_paths.raw, 'locations.csv'), eye_tag);
    
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
    if ii < numel(u_vid_nums)
        waitbar(1, wb, sprintf('%is delay.', round(delays(ii))));
        if USE_REAL_DELAYS
            pause(delays(ii));
        end
    end
end
close(wb);

%% Let tester know there are no more videos
msgbox('Done!', '', 'help')

%% Indicate that you're done by creating an empty text file
% done_fname = 'done.txt';
% out_ffname = fullfile(trg, done_fname);
% fid = fopen(out_ffname, 'w');
% fclose(fid);



