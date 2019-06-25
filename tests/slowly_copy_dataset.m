%% Imports
addpath(genpath('..\lib'));

%% Constants
SRC = '\\AOIP_10200_\Repo_10200_\JC_10549\AO_2_2_SLO\2018_04_20_OS\Raw';
TRG = 'R:\Alex Salmon\live-test\2018_04_20_OS\Raw';
FR = 1/16; % frame rate
WAIT_RANGE = [10, 20]; % min + rand between 0 and max
N_PAD = 4;
VID_NUM_EXP = sprintf('%s%s%s', ...
    '[_]', repmat('\d', 1, N_PAD), '[.]mat');

%% Set up parallel pool
delete(gcp('nocreate'));
p = parpool('local', 3);

%% Make target directory
if exist(TRG, 'dir') == 0
    mkdir(TRG);
end

%% Copy calibration files
cal_in_path = strrep(SRC, '\Raw', '\Calibration');
cal_out_path = strrep(TRG, '\Raw', '\Calibration');
if exist(cal_out_path, 'dir') == 0
    mkdir(cal_out_path);
end
cal_avi_dir = dir(fullfile(cal_in_path, '*.avi'));
for ii=1:numel(cal_avi_dir)
    % Copy videos
    copyfile(...
        fullfile(cal_in_path, cal_avi_dir(ii).name), ...
        fullfile(cal_out_path, cal_avi_dir(ii).name));
    
    % Copy headers
    mat_in_name = strrep(cal_avi_dir(ii).name, '.avi', '.mat');
    copyfile(...
        fullfile(cal_in_path, mat_in_name), ...
        fullfile(cal_out_path, mat_in_name));
end

%% Get all aoslo headers
all_aoslo_headers = dir(fullfile(SRC, '*.mat'));
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

fprintf('Press enter to start\n');
pause();
for ii=1:numel(u_vid_nums)
    current_heads = header_fnames(...
        contains(header_fnames, [u_vid_nums{ii}, '.mat']));
    current_avis = strrep(current_heads, '.mat', '.avi');
    
    parfor jj=1:numel(current_avis)
        img = fn_read_AVI(fullfile(SRC, current_avis{jj}));
        fprintf('Writing %s.\n', current_avis{jj});
        
        vw = VideoWriter(fullfile(TRG, current_avis{jj}), ...
            'grayscale avi'); %#ok<TNMLP>
        open(vw);
        for kk=1:size(img, 3)
            writeVideo(vw, img(:,:,kk));
            pause(FR);
        end
        close(vw);
        
        % Copy headers after videos are written
        copyfile(...
            fullfile(SRC, current_heads{jj}), ...
            fullfile(TRG, current_heads{jj}));
    end
    
    % Simulate delay between "acquisitions"
    wait_time = WAIT_RANGE(1) + randi([0, WAIT_RANGE(2)], 1);
    fprintf('Waiting %is before next "acquisition"\n', wait_time);
    pause(wait_time);
end

%% Indicate that you're done by creating an empty text file
root_path = fullfile(TRG, '..');
done_fname = 'done.txt';
out_ffname = fullfile(root_path, done_fname);
fid = fopen(out_ffname, 'w');
fclose(fid);



