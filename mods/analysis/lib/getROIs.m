function rois = getROIs(db, paths, opts, roi_sz_deg, roi_tol_deg)
%getROIs generates a grid of ROIs and the images that contain that best
%match
% This algorithm assumes a completely intact montage
% Description of variables:
% db:
% paths:
% opts
% roi_sz_deg
% roi_pos_tol


%% Optional Inputs
% ROI size (side length) in degrees (must be square)
if exist('roi_sz_deg', 'var') == 0 || isempty(roi_sz_deg)
    roi_sz_deg = 0.5;
end
% Get image scale (pixels per degree (ppd))
[min_fov,I] = min([db.cal.dsin.fov]);
this_ppd = db.cal.dsin(I).ppd;
roi_sz_px = roi_sz_deg*this_ppd;

% ROI center position tolerance (allow shifting to avoid edges and bad
% parts of the image
if exist('roi_tol_deg', 'var') == 0 || isempty(roi_tol_deg)
    roi_tol_deg = 0.1;
%     roi_pos_tol = roi_sz_px*sqrt(2)/2 - (roi_sz_px/2);
    roi_pos_tol = roi_tol_deg*this_ppd;
end

%% Generate a 1° ROI grid
u_loc_xy_deg = unique(fix(fixCoordsToMat(db.mon.loc_data.coords)), 'rows');
% flip y to convert to image-space
u_loc_xy_deg_img = u_loc_xy_deg;
u_loc_xy_deg_img(:,2) = u_loc_xy_deg(:,2) *-1;
% Convert to pixels and shift 0,0 to fovea
u_loc_xy_px = u_loc_xy_deg_img.*this_ppd + db.data.fovea_xy;
n_rois = size(u_loc_xy_px, 1);

% % DEV/DEBUGGING
% figure;
% scatter(u_loc_xy_px(:,1), u_loc_xy_px(:,2));
% set(gca,'ydir','reverse')
% xlabel('X (px)');
% ylabel('Y (px)');
% title(sprintf('Center at %0.1f, %0.1fpx', fovea_xy(1), fovea_xy(2)));
% % END DEV/DB

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
mon_img_fnames = getSelectedTifs(paths.mon_out, ...
    opts.mod_order{1}, opts.lambda_order(1));
ref_mon_img_fname = mon_img_fnames{contains(mon_img_fnames, img_name)};
im = imread(fullfile(paths.mon_out, ref_mon_img_fname));
imcomps = bwconncomp(imclose(im(:,:,2)>0, ones(5)));
imbox = regionprops(imcomps, 'BoundingBox');
ref_origin_xy = [imbox.BoundingBox(1), imbox.BoundingBox(2)];

%% Compute polygons for the rotated images to determine overlap with ROIs
% Get rectangle polygons for each image
% todo: This current implementation is off by a couple pixels, I think either due
% to rounding error or a 0-based indexing thing. So far, the functional
% consequences of this are negligible, but it may lead to IOB errors
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
    
    % % DEV/DEBUGGING
    % im = imread(fullfile(paths.mon_out, mon_img_fnames{ii}));
    % imshow(im(:,:,1))
    % hold on
    % patch('xdata', img_polys(:,1,ii), 'ydata', img_polys(:,2,ii), ...
    %     'facecolor', 'none', 'edgecolor', 'r')
    % plot(db.data.fovea_xy(1), db.data.fovea_xy(2), 'oc');
    % hold off;
    % pause();
    % % END DEV/DEBUGGING
end

% % DEV/DB
% drawPennMontage(db, paths, opts, true, u_loc_xy_px, ref_origin_xy, ...
%     roi_sz_px, roi_pos_tol);
% % END DEV/DB

% todo: Find a fast geometric way to measure overlap of rotated rectangles.
% This currently doesn't take rotation into account
% https://en.wikipedia.org/wiki/Line_clipping

% DEV/DB
% f = figure; 
% END DEV/DB

% tic
img_info = imfinfo(fullfile(paths.mon_out, mon_img_fnames{1}));
roi_ol_amts = zeros(n_rois, db.mon.montages.N);
for ii=1:n_rois
    xy = u_loc_xy_px(ii,:);
    this_roi_xy = [
        xy(1)-roi_sz_px/2-roi_pos_tol, xy(1)+roi_sz_px/2+roi_pos_tol, xy(1)+roi_sz_px/2+roi_pos_tol, xy(1)-roi_sz_px/2-roi_pos_tol;
        xy(2)-roi_sz_px/2-roi_pos_tol, xy(2)-roi_sz_px/2-roi_pos_tol, xy(2)+roi_sz_px/2+roi_pos_tol, xy(2)+roi_sz_px/2+roi_pos_tol]';
    % Correct any out-of-bounds errors
    if ...
            all(this_roi_xy(:,1) > img_info.Width) || ...
            all(this_roi_xy(:,2) > img_info.Height)
        continue; % Leave overlapping amounts at 0
    end
    % Squish em into frame
    if any(this_roi_xy(:,1) > img_info.Width)
        this_roi_xy(this_roi_xy(:,1) > img_info.Width, 1) = img_info.Width;
    end
    if any(this_roi_xy(:,2) > img_info.Height)
        this_roi_xy(this_roi_xy(:,2) > img_info.Height, 2) = img_info.Height;
    end
    if any(this_roi_xy(:,1) < 1)
        this_roi_xy(this_roi_xy(:,1) < 1, 1) = 1;
    end
    if any(this_roi_xy(:,2) < 1)
        this_roi_xy(this_roi_xy(:,2) < 1, 2) = 1;
    end
    
    % Measure overlap
    for jj=1:size(img_polys, 3)
        % This solution does not take rotation into account, but the
        % rotations are usually minor enough to not impact this problem
        % And it's fast
        
        
        
        [~, roi_ol_amts(ii, jj)] = doOverlap(...
            img_polys(1,:,jj), img_polys(3,:,jj), ...
            this_roi_xy(1,:), this_roi_xy(3,:));
        
        % % DEV/DEBUGGING
        % clf;
        % patch('xdata', this_roi_xy(:,1), 'ydata', this_roi_xy(:,2), ...
        %     'facecolor', 'none', 'edgecolor', 'r')
        % patch('xdata', img_polys(:,1,jj), 'ydata', img_polys(:,2,jj), ...
        %     'facecolor', 'none', 'edgecolor', 'b');
        % set(gca,'ydir','reverse')
        % axis equal
        % xlim([1, img_info.Width]);
        % ylim([1, img_info.Height]);
        % title(sprintf('OL: %0.2f', roi_ol_amts(ii,jj)));
        % drawnow()
        % pause(0.5);
        % % END DEV/DEBUGGING
        
        % % DEV/DEBUGGING
        % im = imread(fullfile(paths.mon_out, mon_img_fnames{jj}));
        % imshowpair(im(:,:,1), this_roi_logical, 'falsecolor', ...
        %     'colorchannels', 'red-cyan');
        % DEV/DEBUGGING
        % imshowpair(img_mask, this_roi_logical, 'blend');
        % hold on;
        % plot(db.data.fovea_xy(1), db.data.fovea_xy(2), 'oc')
        % patch('xdata', img_polys(:,1,jj), 'ydata', img_polys(:,2,jj), ...
        %     'facecolor', 'none', 'edgecolor', 'r');
        % hold off;
        % title(sprintf('Overlap: %0.2f deg^2', ...
        %     sqrt(roi_ol_amts(ii,jj))/this_ppd))
        % % END DEV/DEBUGGING
    end
end
% toc

%% Normalize overlap amounts to roi size without tolerance
% roi_ol_amts = roi_ol_amts./roi_sz_px^2;

%% Shift all ROIs to their "best" position
failed_rois = false(n_rois, 1);
roi_img_fnames = cell(n_rois, 1);
roi_shifts = zeros(n_rois, 2, 'uint16');
% Ensure entire ROI within a single image
% Prefer smaller FOVs
% Avoid blood vessels
% Minimize movement from nominal location

% DEV/DB
% figure;
% t = linspace(0,2*pi,50);
% END DEV/DB
% tic
for ii=1:n_rois
    % Determine which images could overlap at all
    ol_idx = find(roi_ol_amts(ii, :) > 0);
    if isempty(ol_idx)
        % No images satisfy this mandatory criterion
        failed_rois(ii) = true;
        continue;
    end
    % Get their names
    ol_img_fnames = mon_img_fnames(ol_idx);
    
    % Get ROI center and corners
    xy = u_loc_xy_px(ii,:);
    roi_xywh = [xy, roi_sz_px, roi_sz_px];
%     % DEV/DB
%     this_roi_xy = [
%         xy(1)-roi_sz_px/2, xy(1)+roi_sz_px/2, xy(1)+roi_sz_px/2, xy(1)-roi_sz_px/2;
%         xy(2)-roi_sz_px/2, xy(2)-roi_sz_px/2, xy(2)+roi_sz_px/2, xy(2)+roi_sz_px/2]';
%     canvas = false(img_info.Height, img_info.Width);
%     for jj=1:numel(ol_img_fnames)
%         im = imread(fullfile(paths.mon_out, ol_img_fnames{jj}));
%         canvas = canvas | im(:,:,2) > 0;
%     end
%     imshow(canvas);
%     hold on
%     plot(xy(1), xy(2), '*r')
%     patch('xdata', this_roi_xy(:,1), 'ydata', this_roi_xy(:,2), ...
%         'facecolor', 'none', 'edgecolor', 'r')
%     patch(...
%         'xdata', (roi_pos_tol).*cos(t) + xy(1), ...
%         'ydata', (roi_pos_tol).*sin(t) + xy(2), ...
%         'facecolor', 'none', 'edgecolor', 'c')
%     patch(...
%         'xdata', (roi_pos_tol+roi_sz_px/2).*cos(t) + xy(1), ...
%         'ydata', (roi_pos_tol+roi_sz_px/2).*sin(t) + xy(2), ...
%         'facecolor', 'none', 'edgecolor', 'r', 'linestyle', ':')
%     % Draw image boundaries
%     for jj=1:numel(ol_img_fnames)
%         patch(...
%             'xdata', img_polys(:,1,ol_idx(jj)), ...
%             'ydata', img_polys(:,2,ol_idx(jj)), ...
%             'facecolor', 'none', 'edgecolor', 'g')
%     end
%     hold off;
%     % END DEV/DB
    
    % Of these images, determine the possible center positions
    shift_space = cell(numel(ol_idx), 1);
    rect_xywh_list = zeros(numel(ol_img_fnames), 4);
    for jj=1:numel(ol_img_fnames)
        % Determine overlap of tolerance circle and image mask
        imsize = [
            img_polys(3,2,ol_idx(jj))-img_polys(1,2,ol_idx(jj)), ...
            img_polys(2,1,ol_idx(jj))-img_polys(1,1,ol_idx(jj))];
        rect_xywh = [
            img_polys(1,1,ol_idx(jj)) + imsize(2)/2, ...
            img_polys(1,2,ol_idx(jj)) + imsize(1)/2, ...
            flip(imsize)];
        rect_xywh_list(jj,:) = rect_xywh;
        
        shift_space{jj} = coordsOverlapImgROI(...
            rect_xywh, roi_xywh, roi_pos_tol);
    end
    % Remove non-encapsulating options
    remove = cellfun(@isempty, shift_space);
    if all(remove)
        failed_rois(ii) = true;
        continue;
    end
    shift_space(remove)         = [];
    rect_xywh_list(remove, :)   = [];
    ol_img_fnames(remove)       = [];

    % Is this an optimization problem??
    % Could have generate a cost function from FOV and distance from center
    % Not sure how to include avoiding vessel shadows, could just make the
    % cost function proportional to the number of vessel pixels included in
    % the roi
    % Finally would want to compare quality somehow
    % Allow translation within shift space
    % Allow rotation in 15° increments?
    
    % Measure distance between roi center and this image's center
    dists = pdist2(rect_xywh_list(:,1:2), xy);
    
    % Get FOVs
    fovs = zeros(size(ol_img_fnames));
    for jj=1:numel(ol_img_fnames)
        key = matchImgToVid(db.vid.vid_set, ol_img_fnames{jj});
        fovs(jj) = db.vid.vid_set(key(1)).fov;
    end
    
    % Pick the one from the smallest fov that's the closest to the center
    [~,I] = min(dists(fovs==min(fovs)));
    roi_img_fnames{ii} = ol_img_fnames{I(1)};
    
    % Okay if we've committed to this image, find the best shift
    % For now, just pick the coord closest to the center of the ROI
    [~, shift_idx] = min(pdist2(double(shift_space{I(1)}), xy));
    roi_shifts(ii,:) = shift_space{I(1)}(shift_idx, :); 
end
% toc

%% Warn user about ROI failures
failed_roi_list = u_loc_xy_deg(failed_rois, :);
failed_roi_list(:,2) = failed_roi_list(:,2);
for ii=1:size(failed_roi_list, 1)
    warning('ROI could not be extracted from: %i, %i', ...
        failed_roi_list(ii,1), failed_roi_list(ii,2));
end

% % DEV/DB
% figure;
% img_path = 'C:\Users\DevLab_811\Box\Manuscripts\Author\Articles\2020-Salmon-PIPE-BOE\Figs\FigX-ROIs';
% img_fname = 'rois.tiff';
% % DEV/DB

%% Compute ROIs and return
rois(n_rois).filename = [];
for ii=1:n_rois
    if failed_rois(ii)
        rois(ii).success = false;
        continue;
    end
    rois(ii).success    = true;
    rois(ii).filename   = roi_img_fnames{ii};
    % Nominal and actual locations
    rois(ii).loc_deg    = u_loc_xy_deg(ii, :);
    rois(ii).xywh       = [roi_shifts(ii,:), roi_sz_px, roi_sz_px];
    
    % % DEV/DB
    % im = imread(fullfile(paths.mon_out, rois(ii).filename));
    % im = im(...
    %     rois(ii).xywh(2)-rois(ii).xywh(4)/2:rois(ii).xywh(2)+rois(ii).xywh(4)/2, ... % y
    %     rois(ii).xywh(1)-rois(ii).xywh(3)/2:rois(ii).xywh(1)+rois(ii).xywh(3)/2, ... % x
    %     1); % image layer
    % imshow(im);
    % if ii==1
    %     wm = 'overwrite';
    % else
    %     wm = 'append';
    % end
    % imwrite(im, fullfile(img_path,img_fname), 'WriteMode', wm);
    % % END DEV/DB
end

% DEV/DB
f = drawPennMontage(db, paths, opts, false, u_loc_xy_px, ref_origin_xy, ...
    roi_sz_px, roi_pos_tol, roi_shifts);
fig_data = getframe(f);
imwrite(fig_data.cdata, fullfile(paths.data, 'montage_w_rois.png'));
% END DEV/DB

end

