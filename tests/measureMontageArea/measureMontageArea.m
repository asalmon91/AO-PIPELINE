%% Determine montage area
%% Imports
addpath(genpath('lib'));

%% Get images
[png_fnames, png_path] = uigetfile('*.png', 'Select transparent .png of the montage', 'multiselect', 'on');
if isnumeric(png_fnames)
	return;
elseif ~iscell(png_fnames)
	png_fnames = {png_fnames};
end
png_fnames = png_fnames'; % transpose for readability

%% Process images
px_list = zeros(size(png_fnames));
for png = 1:numel(png_fnames)
	px_list(png) = determineMontageAreaPx(fullfile(png_path, png_fnames{png}));
end

%% Report results
px_report = [png_fnames, mat2cell(px_list, ones(size(px_list)))];
out_path = png_path;
out_fname = 'report.xlsx';
xlswrite(fullfile(out_path, out_fname), px_report);