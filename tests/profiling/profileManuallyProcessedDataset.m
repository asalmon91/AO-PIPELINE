%% Get profile for manually processed dataset
% Total processing time

%% Imports
import System.IO.File.GetCreationTime
addpath(genpath('lib'), genpath('mods'), genpath('classes'));

%% Constants
MOD_TAG = 'split_det';

%% Get root path to dataset
root_path = uigetdir('.', 'Select root directory of dataset');
if isnumeric(root_path)
	return;
end

%% Initiate paths
paths = initPaths(root_path);

%% Calibration
% Negligible, skip

%% Secondary modalities
aviSets = getAviSets(paths.raw);
t_last_modified = zeros(size(aviSets));
for vid = 1:numel(aviSets)
	% Get secondary video of interest
	v_idx = find(~cell2mat(cellfun(@isempty, strfind(aviSets(vid).fnames, MOD_TAG), 'uniformoutput', false)));
	if isempty(v_idx)
		error('Modality not found for video %i', aviSets(vid).num);
	end
	this_fname = aviSets(vid).fnames{v_idx};
	
% 	% Get creation time - changes if the file is copied
% 	d = GetCreationTime(fullfile(paths.raw, this_fname));
% 	t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
% 	t_create = days2sec(datenum(t_create));
	
	% Get modified time
	this_vid = dir(fullfile(paths.raw, this_fname));
	t_last_modified(vid) = days2sec(this_vid.datenum);
end
t_secondary = diff(sort(t_last_modified));

%% ARFS
arfs_data_info = dir(fullfile(paths.raw, '*dmbdata.mat'));
if numel(arfs_data_info) ~= 1
	error('Failed to find 1 arfs data file in %s', paths.raw);
end
arfs_data = load(fullfile(paths.raw, arfs_data_info.name));



