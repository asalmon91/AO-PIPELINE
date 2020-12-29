%% Reset test dataset
root_path = uigetdir('.', 'Select root directory');
if isnumeric(root_path)
    return;
end

% todo: warn self

%% Get mode
% PIPE_MODE = 'LIVE';
re = questdlg('Full or Live?', 'Mode', 'Full', 'Live', 'Cancel', 'Full');
switch re
    case 'Full'
        PIPE_MODE = 'FULL';
    case 'Live'
        PIPE_MODE = 'LIVE';
    case 'Cancel'
        return;
end

%% Delete LIVE and FULL .mat database files
fprintf('Deleting AO_PIPE_%s.mat\n', PIPE_MODE);
delete(fullfile(root_path, sprintf('AO_PIPE_%s.mat', PIPE_MODE)));

% %% Delete desinusoid files
% cal_path = fullfile(root_path, 'Calibration');
% cal_files = dir(fullfile(cal_path, 'desinusoid_matrix*.mat'));
% for ii=1:numel(cal_files)
% 	fprintf('Deleting %s\n', cal_files(ii).name);
% 	delete(fullfile(cal_path, cal_files(ii).name));
% end

%% Delete split and avg
if strcmp(PIPE_MODE, 'FULL')
    raw_path = fullfile(root_path, 'Raw');
    avg_avis = dir(fullfile(raw_path, '*_avg_*.avi'));
    split_avis = dir(fullfile(raw_path, '*_split_det_*.avi'));
    rm_avis = [avg_avis; split_avis];
    for ii=1:numel(rm_avis)
        fprintf('Deleting %s\n', rm_avis(ii).name);
        delete(fullfile(raw_path, rm_avis(ii).name));
    end
end

%% Delete processed images
proc_path = fullfile(root_path, 'Processed', PIPE_MODE);
if exist(proc_path, 'dir') ~= 0
	fprintf('Deleting %s\n', proc_path);
	rmdir(proc_path, 's');
end

%% Delete Montages
mon_path = fullfile(root_path, 'Montages', PIPE_MODE);
if exist(mon_path, 'dir') ~= 0
	fprintf('Deleting %s\n', mon_path);
	rmdir(mon_path, 's');
end
xlsx_search = dir(fullfile(root_path, 'Montages', '*.xlsx'));
for ii=1:numel(xlsx_search)
    delete(fullfile(xlsx_search(ii).folder, xlsx_search(ii).name));
end
