%% Compile, randomize, and mask ROIs and coordinates
DO NOT TRY RUNNING THIS AS IS
% Current working directory should be ~\AO-PIPELINE

%% Imports
addpath(genpath('lib'), genpath('tests'));

%% Get input and output directory
% Input
path_root = uigetdir('.', 'Select directory containing all output directories');
% Get all .tif's within the subfolders of this directory
tif_search = subdir(fullfile(path_root, '*.tif'));
if isempty(tif_search)
	error('No .tif''s found here');
end
% Output
path_out = uigetdir(path_root, 'Select output directory (preferably somewhere else');

%% Process images
for ii=1:numel(tif_search)
	[path_tif, name_tif, ext_tif] = fileparts(tif_search(ii).name);
	mask_token = path_tif(end-2:end);
	fname_out = sprintf('%s_%s%s', mask_token, name_tif, ext_tif);
	[success, msg] = copyfile(...
		tif_search(ii).name, ...
		fullfile(path_out, fname_out));
	if ~success
		warning(msg);
	else
		fprintf('%s\n', fname_out);
	end
end

fprintf('\nRun the cone counting algorithm in mosaic analytics\n');
pause();

%% Get all .csv's and add _coords if they don't already have it
COORDS_TAG = '_coords.csv';
csv_search = dir(fullfile(path_out, '*.csv'));
for ii=1:numel(csv_search)
	if ~contains(csv_search(ii).name, COORDS_TAG)
		[success, msg] = movefile(...
			fullfile(path_out, csv_search(ii).name), ...
			fullfile(path_out, strrep(csv_search(ii).name, '.csv', COORDS_TAG)));
		if ~success
			warning(msg);
		else
			fprintf('%s\n', csv_search(ii).name);
		end
	end
end

%% Okay this code is broken now
% Add h to specify human
tif_search = dir(fullfile(path_out, '*.tif'));
csv_search = dir(fullfile(path_out, '*_coords.csv'));
tif_and_csv = [tif_search; csv_search];
for ii=1:numel(tif_and_csv)
	movefile(...
		fullfile(path_out, tif_and_csv(ii).name), ...
		fullfile(path_out, ['s-', tif_and_csv(ii).name]));
end

%% Randomize and mask
tif_search = dir(fullfile(path_out, '*.tif'));
path_out_final = 'C:\Users\Alexander\Box\PRO-30741\WIP_Salmon_Manuscript_PIPE\h2h-testing\cone-counting\op2';
r = rand(numel(tif_search), 1);
[~, I] = sort(r);
tif_search = tif_search(I);
for ii=1:numel(tif_search)
	fname_in = tif_search(ii).name;
	fname_out = sprintf('%i.tif', ii);
	copyfile(...
		fullfile(path_out, tif_search(ii).name), ...
		fullfile(path_out_final, fname_out));
	% Find coords
	fname_csv = strrep(fname_in, '.tif', COORDS_TAG);
	fname_csv_out = sprintf('%i_coords.csv', ii);
	copyfile(...
		fullfile(path_out, fname_csv), ...
		fullfile(path_out_final, fname_csv_out));
	tif_search(ii).mask_id = ii;
end

%% Save key
path_key = 'C:\Users\Alexander\Box\PRO-30741\WIP_Salmon_Manuscript_PIPE\figs\FigX-H2H\keys';
save(fullfile(path_key, 'cc-op2-key.mat'), 'tif_search');


