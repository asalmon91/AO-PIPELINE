function [ht, wd, nFrames, nCrop, tif_path, tif_fname, px_cdf, cropErr] = ...
    getOutputSizeAndN(out_proc, dmb_fname, current_modality)
%getOutputSizeAndN determines results of demotion
% todo: there is some weird bug with DeMotion where the SR .avi's don't
% seem to match the registered image. In the SR .avi, you expect the
% reference frame to show up as an undistorted raw frame, but this is
% missing sometimes. This results in chunks of the image being interpreted
% as an average of 0 frames and inferring a cropping error. It would be
% better to determine cropping errors from the .dmp so that we don't have
% to waste time dealing with the binary .avi's.

%% Defaults
ht = 0;
wd = 0;
nFrames = 0;
nCrop = 0;
tif_path = '';
tif_fname = '';
cropErr = false;

%% Find matching output tif
[~,dmb_name,~] = fileparts(dmb_fname);
tif_search = dir(fullfile(out_proc, [dmb_name, '*.tif']));
if numel(tif_search) == 0
    warning('Something went wrong with %s', dmb_fname);
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

% Get the number of frames to which the stack was cropped
% (from the filename)...
[~,tif_name,~] = fileparts(tif_search.name);
nameparts = strsplit(tif_name, '_');
nCrop = str2double(nameparts{find(strcmp(nameparts, 'cropped'))+1});
if nCrop == 1
    % This is definitely a crop error, but not one where we want to
    % increase the ncc threshold
    return;
end

%% Get # Frames
% This is trickier because the n listed in the filename is not always
% accurate. Check to see if the SR_AVI was output, and determine the # of
% frames that way. Otherwise use the filename and hope for the best
sr_avi_path = fullfile(out_proc, '..', 'SR_AVIs');
avi_search = dir(fullfile(sr_avi_path, [dmb_name, '*.avi']));
if ~isempty(avi_search)
    if numel(avi_search) > 1
        % Use most recent one
        avi_search = avi_search([avi_search.datenum] == max([avi_search.datenum]));
    end
    vr = VideoReader(fullfile(avi_search.folder, avi_search.name));
    nFrames = vr.NumFrames;
else
    % Use filename
    nFrames = str2double(nameparts{find(strcmp(nameparts, 'n'))+1});
end

%% Get distribution of pixel averages
% And check for crop errors
% Find binary image
if exist('current_modality', 'var') ~=0 && ~isempty(current_modality)
    bin_name = strrep(tif_name, current_modality, 'bin');
    if exist(fullfile(sr_avi_path, [bin_name, '.avi']), 'file') == 0
        error('%s not found', [bin_name, '.avi']);
    end
    
    bin_sr_vid = fn_read_AVI(fullfile(sr_avi_path, [bin_name, '.avi']));
    bin_map = sum(bin_sr_vid, 3)./255;
    if numel(find(bin_map(:)==0)) > 4
        % A little bit of crop error at the corners never hurt anyone,
        % right?
        cropErr = true;
    end
    
    [N,edges] = histcounts(bin_map(:), 0:size(bin_sr_vid,3), ...
        'normalization', 'cdf');
    px_cdf = [1-N', edges(1:end-1)'];
end



end

