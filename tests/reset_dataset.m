%% Reset test dataset

root_path = uigetdir('.', 'Select root directory');

% todo: warn self


%% Delete LIVE and FULL .mat database files
fprintf('Deleting %s\n', 'AO_PIPE_FULL.mat');
delete(fullfile(root_path, 'AO_PIPE_FULL.mat'));

%% Delete desinusoid files
cal_path = fullfile(root_path, 'Calibration');
cal_files = dir(fullfile(cal_path, 'desinusoid_matrix*.mat'));
for ii=1:numel(cal_files)
	fprintf('Deleting %s\n', cal_files(ii).name);
	delete(fullfile(cal_path, cal_files(ii).name));
end

%% Delete split and avg
raw_path = fullfile(root_path, 'Raw');
avg_avis = dir(fullfile(raw_path, '*_avg_*.avi'));
split_avis = dir(fullfile(raw_path, '*_split_det_*.avi'));
rm_avis = [avg_avis; split_avis];
for ii=1:numel(rm_avis)
	fprintf('Deleting %s\n', rm_avis(ii).name);
	delete(fullfile(raw_path, rm_avis(ii).name));
end

%% Delete processed images
proc_path = fullfile(root_path, 'Processed', 'FULL');
if exist(proc_path, 'dir') ~= 0
	fprintf('Deleting %s\n', proc_path);
	rmdir(proc_path, 's');
end

%% Delete Montages
mon_path = fullfile(root_path, 'Montages', 'FULL');
if exist(mon_path, 'dir') ~= 0
	fprintf('Deleting %s\n', mon_path);
	rmdir(mon_path, 's');
end

