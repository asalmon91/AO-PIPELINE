function [dsin_vid, dsin] = readAndDsin(vid_ffname, dsins, fov, wl)
%readAndDsin reads the avi, then desinusoids

%% Read video
vid = im2single(fn_read_AVI(vid_ffname));

%% Find matching desinusoid matrix
% todo: make desinusoid matching a separate function
dsin_fovs   = zeros(size(dsins));
dsin_wls    = dsin_fovs;
for ii=1:numel(dsins)
    dsin_fovs(ii)   = dsins(ii).lut.fov;
    dsin_wls(ii)    = dsins(ii).lut.wl;
end

dsin = dsins(...
    fov == dsin_fovs & ...
    wl == dsin_wls);

dsin_mat = single(dsin.lut.dsin_mat);

dsin_vid = zeros(...
    size(vid, 1), ...
    size(dsin_mat, 1), ...
    size(vid, 3), 'single');

for ii=1:size(vid, 3)
    dsin_vid(:, :, ii) = vid(:, :, ii) * dsin_mat';
end







end

