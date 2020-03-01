function [outputArg1,outputArg2] = analysis_FULL(db, paths, opts)
%analysis_FULL estimates the foveal center and a coarse cone spacing
% Eventually, it will be useful to include a normative-database to
% determine if there are significant differences at each location and
% facilitate early detection of cone loss. 
% todo: handle disease cases like ACHM where cones in the fovea are only
% visible on split-detector
% todo: handle cases like squirrel where this won't make any sense
% todo: maybe don't worry about specific protocols, generate all ROIs that
% are fully contained within an image (± some tolerance) at regular
% intervals

% If the point of this is just to estimate the fovea, could filter the
% images by proximity to 0,0, perhaps by <2°
% This step takes a pretty long time, so if it's not going to work 
% todo: figure out what to do if the subject is not human
fovea_xy = fx_montage_dft_analysis(aligned_tif_path, ...
    opts.mod_order{1}, opts.lambda_order(1), do_par);

% Get information about what was collected
% xy = fixCoordsToMat(db.mon.loc_data.coords);
% dists = pdist2([0,0], xy);
% min_r = min(dists);
% max_r = max(dists);

% Generate an ROI at each integer retinal location
u_loc_xy_deg = unique(round(fixCoordsToMat(db.mon.loc_data.coords)), 'rows');
% flip y to convert to image-space
u_loc_xy_deg(:,2) = u_loc_xy_deg(:,2) *-1;

% Convert to pixels and shift 0,0 to fovea
[min_fov,I] = min([db.cal.dsin.fov]);
this_ppd = db.cal.dsin(I).ppd;
u_loc_xy_px = u_loc_xy_deg.*this_ppd + fovea_xy;

% figure;
% scatter(u_loc_xy_px(:,1), u_loc_xy_px(:,2));
% set(gca,'ydir','reverse')
% xlabel('X (px)');
% ylabel('Y (px)');
% title(sprintf('Center at %0.1f, %0.1fpx', fovea_xy(1), fovea_xy(2)));

% todo: figure out what to do if there are still breaks
% assuming there are none at this point


%% Convert relative txfms to global
% todo: this would be a WHOLE lot easier if the penn automontager output
% which image was the reference and its global coords

% ref is whichever image has the identity matrix as its txfm. determine the
% distance between this image's origin and the fovea and translate all
% txfms by that much
% Find reference image, has no rotation so it's fine to use the bounding
% box to get its position
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
mon_img_fnames = getSelectedTifs(paths.mon_out, 'confocal', 775);
ref_mon_img_fname = mon_img_fnames{contains(mon_img_fnames, img_name)};
im = imread(fullfile(paths.mon_out, ref_mon_img_fname));
imcomps = bwconncomp(imclose(im(:,:,2)>0, ones(5)));
imbox = regionprops(imcomps, 'BoundingBox');
ref_origin_xy = [imbox.BoundingBox(1), imbox.BoundingBox(2)];

%% Overwrite all dx, dy so that the global origin is 1,1
% for ii=1:db.mon.montages.N
%     txfm = db.mon.montages.TotalTransform(:,:,ii);
%     txfm(1:2,3) = txfm(1:2,3) + ref_origin_xy';
%     db.mon.montages.TotalTransform(:,:,ii) = txfm;
% end

%% Find all images that contain each ROI
% Get rectangle polygons for each image
% This current implementation is off by a couple pixels, I think either due
% to rounding error or a 0-based indexing thing. So far, the functional
% consequences of this are negligible, but it may lead to index oob errors
img_polys = zeros(4, 2, db.mon.montages.N); % 4 corners, x,y
for ii=1:numel(mon_img_fnames)
    % Get scaled image size
    key = matchImgToVid(db.vid.vid_set, mon_img_fnames{ii});
    rel_scale = db.vid.vid_set(key(1)).fov / min_fov;
    key = findImgInPennAM(db.mon.montages.inData, mon_img_fnames{ii});
    if key == 0
        error('Failed to find %s in the list of inputs', ...
            mon_img_fnames{ii});
    end
    img_fname = db.mon.montages.inData{1, key(1)};
    img_info = imfinfo(fullfile(paths.out, img_fname));
    imsize_wh = [img_info.Width, img_info.Height].*rel_scale;
    
    % Get txfm for this image
    txfm = db.mon.montages.TotalTransform(:,:,key(1));
    % Important to do this step. I wish I knew why the transforms aren't
    % recorded in their useful form... 
    txfm = pinv(txfm');
	txfm(:,3)=[0;0;1];
    txfm = txfm';

    % Get the polygon for this image
    img_polys(:,:,ii) = getTxfmdRectCoords(imsize_wh, txfm, ref_origin_xy);
    
    % Debugging
    im = imread(fullfile(paths.mon_out, mon_img_fnames{ii}));
    imshow(im(:,:,1))
    hold on
    patch('xdata', img_polys(:,1,ii), 'ydata', img_polys(:,2,ii), 'facecolor', 'none', 'edgecolor', 'r')
    plot(fovea_xy(1), fovea_xy(2), 'oc');
    hold off;
    pause();
    
end

% For each ROI, determine which polygons contain its center
ROI_SIZE_DEG = 0.5;
n_rois = size(u_loc_xy_px, 1);
overlapping_imgs = cell(n_rois, 1);

% For debugging, comment out when done
figure; 
%%%%%%%%

for ii=1:n_rois
    this_roi_xy = u_loc_xy_px(ii,:);
    
    has_roi = false(size(img_polys, 3), 1); 
    for jj=1:size(img_polys, 3)
        roi_is_in_img = inpolygon(this_roi_xy(1), this_roi_xy(2), ...
            img_polys(:,1,jj), img_polys(:,2,jj));
        
        if roi_is_in_img
            % Determine amount, preference is given to images that
            % completely encompass the ROI
            
            
            
            
        end
        
        % For debugging, comment out when done
        im = imread(fullfile(paths.mon_out, mon_img_fnames{jj}));
        imshow(im(:,:,1));
        hold on;
        plot(fovea_xy(1), fovea_xy(2), 'oc')
        plot(this_roi_xy(1), this_roi_xy(2), 'xr')
        legend({'"Fovea"', 'ROI center'}, 'location', 'northeast', ...
            'AutoUpdate', 'off');
        patch('xdata', img_polys(:,1,jj), 'ydata', img_polys(:,2,jj), ...
            'facecolor', 'none', 'edgecolor', 'r');
        hold off;
        pause();
    end
end




end

