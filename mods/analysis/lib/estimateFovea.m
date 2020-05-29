function [fovea_xy, canvas] = estimateFovea(db, paths, opts)
%estimateFovea does a quick estimation of the cone density map in the
%central 2° and finds the center of mass of the summed density map


%% Estimate spacing, estimate location of foveola
% Get images within 2 degrees
tif_fnames = filterMonImgsByECC(db, paths, opts, 2);
% Get images at smallest fov
fovs = zeros(size(tif_fnames));
for ii=1:numel(tif_fnames)
    key = matchImgToVid(db.vid.vid_set, tif_fnames{ii});
    fovs(ii) = db.vid.vid_set(key(1)).fov;
end
[min_fov, I] = min([db.cal.dsin.fov]);
tif_fnames(fovs > min_fov) = [];

% Also get some scaling info
ppd = db.cal.dsin(I).ppd;

% Get global reference origin
for ii=1:db.mon.montages.N
    if isequal(db.mon.montages.TotalTransform(:,:,ii), eye(3))
        ref_idx = ii;
        break;
    end
end
% Get origin of this image 
% Get image name
img_fname = db.mon.montages.inData{1,ref_idx};
% Find the corresponding montaged image filename
[~,img_name] = fileparts(img_fname);
mon_img_fnames = getSelectedTifs(paths.mon_out, ...
    opts.mod_order{1}, opts.lambda_order(1));
ref_mon_img_fname = mon_img_fnames{contains(mon_img_fnames, img_name)};
im = imread(fullfile(paths.mon_out, ref_mon_img_fname));
imcomps = bwconncomp(imclose(im(:,:,2)>0, ones(5)));
imbox = regionprops(imcomps, 'BoundingBox');
ref_origin_xy = [imbox.BoundingBox(1), imbox.BoundingBox(2)];

img_info = imfinfo(fullfile(paths.mon_out, ref_mon_img_fname));
% Plan is to use nanmean(canvas, 3) to get the average spacing of this
% submontage
canvas = zeros(img_info.Height, img_info.Width);
sum_map = zeros(size(canvas));
micron_box_size = 25;
um_per_pix = 1/ppd*291;

% Quick count all images
for ii=1:numel(tif_fnames)
    % Get original version of the image
    mon_idx = findImgInPennAM(db.mon.montages.inData, tif_fnames{ii});
    img_fname = db.mon.montages.inData{1, mon_idx};
    im = imread(fullfile(paths.out, img_fname));
    % Get scale
    key = matchImgToVid(db.vid.vid_set, img_fname);
    rel_scale = db.vid.vid_set(key(1)).fov / min_fov;
    % Scale
    im = imresize(im, rel_scale);
    im_size = size(im);
    
    % Count cones in whole image
    coords_xy = li_roorda_count_cones(im);
    
    % Prep coordinate mask
    fullcoordmask = zeros(im_size(1:2));
    inds = sub2ind(size(fullcoordmask), ...
        round(coords_xy(:,2)), round(coords_xy(:,1)));
    fullcoordmask(inds) = 1;

    % Make cell counting kernel (just a ones matrix)
    pix_box_size  = round(micron_box_size/um_per_pix); % The size of the kernel box
    pix_half_size = micron_box_size/(2*um_per_pix);
    kernel = ones(pix_box_size);
    
    % The density per cell that it finds, in cells/mm
    densitypercell = (1/((micron_box_size^2)/(1000^2)));
    % Perform the convolution
    densitymap = conv2(fullcoordmask, kernel.*densitypercell, 'valid');
    dmap_sz = size(densitymap);
    padded_dmap = nan(im_size(1:2));
    padded_dmap(...
        round(pix_half_size):round(pix_half_size)+dmap_sz(1)-1, ...
        round(pix_half_size):round(pix_half_size)+dmap_sz(2)-1) = densitymap;
    padded_sum_map = zeros(size(padded_dmap));
    padded_sum_map(...
        round(pix_half_size):round(pix_half_size)+dmap_sz(1)-1, ...
        round(pix_half_size):round(pix_half_size)+dmap_sz(2)-1) = 1;
    
    % Transform the map into the global montage space
    txfm = db.mon.montages.TotalTransform(:,:,mon_idx);
    txfm = pinv(txfm');
	txfm(:,3)=[0;0;1];
    txfm = txfm';
    txfm(1:2, 3) = txfm(1:2, 3) + ref_origin_xy';
    
    warp_map = imwarp(padded_dmap, imref2d(size(padded_dmap)), affine2d(txfm'), ...
        'OutputView', imref2d([img_info.Height, img_info.Width]));
    warp_sum = imwarp(padded_sum_map, imref2d(size(padded_dmap)), affine2d(txfm'), ...
        'OutputView', imref2d([img_info.Height, img_info.Width]));
    
    warp_map(warp_sum==0) = NaN;
    canvas = sum(cat(3, canvas, warp_map), 3, 'omitnan');
    sum_map = sum(cat(3, sum_map, warp_sum), 3, 'omitnan');
end
canvas = canvas./sum_map;
% canvas(isinf(canvas)) = nan;
% canvas = mean(canvas, 3, 'omitnan');
canvas(isnan(canvas)) = 0;
meanD = mean(canvas(:), 'omitnan');
[X, Y] = meshgrid(1:size(canvas, 2), 1:size(canvas, 1));
fovea_xy = [...
    mean(canvas(:) .* X(:)) / meanD, ...
    mean(canvas(:) .* Y(:)) / meanD];

figure;
imagesc(canvas);
colormap('jet')
hold on;
plot(fovea_xy(1), fovea_xy(2), '*k');


end

