function missingImg = getMissingImgs(path_img, path_vid)

%% Constants
MOD_STR = 'confocal';

%% Get video numbers from all images
tif_dir = dir(fullfile(path_img, '*.tif'));
% Filter to just confocal (okay if multiple wavelengths)
mod_filt = contains({tif_dir.name}', MOD_STR);
tif_dir = tif_dir(mod_filt);
img_vn = zeros(size(tif_dir));
for ii=1:numel(tif_dir)
    name_parts = strsplit(tif_dir(ii).name, '_');
    img_vn(ii) = str2double(name_parts{find(strcmp(name_parts, MOD_STR)) +1});
end
img_vn = unique(img_vn);

%% Get video numbers from all videos
avi_dir = dir(fullfile(path_vid, '*.avi'));
% Filter to just confocal (okay if multiple wavelengths)
mod_filt = contains({avi_dir.name}', MOD_STR);
avi_dir = avi_dir(mod_filt);
vid_vn = zeros(size(avi_dir));
for ii=1:numel(avi_dir)
    [~, avi_name, ~] = fileparts(fullfile(path_vid, avi_dir(ii).name));
    name_parts = strsplit(avi_name, '_');
    vid_vn(ii) = str2double(name_parts{find(strcmp(name_parts, MOD_STR)) +1});
end
vid_vn = unique(vid_vn);

%% Find videos that don't have a corresponding image
missingImg = ismember(vid_vn, img_vn, 'rows');
missingImg = [vid_vn, missingImg];


end






