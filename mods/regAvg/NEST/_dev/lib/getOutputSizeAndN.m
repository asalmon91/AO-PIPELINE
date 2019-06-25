function [ht, wd, nFrames, nCrop, tif_path, tif_fname] = ...
    getOutputSizeAndN(out_proc, dmb_fname)
%getOutputSizeAndN Summary of this function goes here
%   Detailed explanation goes here

% Find matching output tif
[~,dmb_name,~] = fileparts(dmb_fname);
tif_search = dir(fullfile(out_proc, [dmb_name, '*.tif']));
if numel(tif_search) == 0
    warning('Something went wrong with %s', dmb_fname);
    ht = 0;
    wd = 0;
    nFrames = 0;
    nCrop = 0;
    tif_path = '';
    tif_fname = '';
    return;
elseif numel(tif_search) > 1
    tif_dates = [tif_search.datenum]';
    tif_search = tif_search(tif_dates == max(tif_dates));
end
tif_path = tif_search.folder;
tif_fname = tif_search.name;

% Get dimensions
f = imfinfo(fullfile(tif_search.folder, tif_search.name));
ht = f.Height;
wd = f.Width;

[~,tif_name,~] = fileparts(tif_search.name);
nameparts = strsplit(tif_name, '_');

nFrames = str2double(nameparts{find(strcmp(nameparts, 'n'))+1});
nCrop   = str2double(nameparts{find(strcmp(nameparts, 'cropped'))+1});

end

