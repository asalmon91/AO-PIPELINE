function f = drawPennMontage(db, paths, opts, animate, ...
    u_loc_xy_px, ref_origin_xy, roi_sz_px, roi_pos_tol, roi_shifts)
%drawPennMontage Draws the montage created by the Penn Automontager
% Not so useful for anyone else because it currently requires a lot of
% custom structures created by PIPE

% Get min FOV for relative scaling
min_fov = min([db.cal.dsin.fov]);

% Get the montaged images
mon_img_fnames = getSelectedTifs(paths.mon_out, ...
    opts.mod_order{1}, opts.lambda_order(1));
% Get the dimensions of the canvas
img_info = imfinfo(fullfile(paths.mon_out, mon_img_fnames{1}));
canvas = zeros(img_info.Height, img_info.Width, 'uint8');

f = figure;
for ii=1:db.mon.montages.N
    % Read and scale this image
    img_fname = db.mon.montages.inData{1,ii};
    key = matchImgToVid(db.vid.vid_set, img_fname);
    rel_scale = db.vid.vid_set(key(1)).fov / min_fov;
    im = imresize(imread(...
        fullfile(paths.out, img_fname)), rel_scale, 'bicubic');
    imsize = size(im);
    
    % Get txfm
    txfm = db.mon.montages.TotalTransform(:,:,ii);
    txfm = pinv(txfm');
	txfm(:,3)=[0;0;1];
    txfm(3, 1:2) = txfm(3, 1:2) + ref_origin_xy;
    
    % Just translate
    canvas(...
        round(txfm(3,2)+1:txfm(3,2)+imsize(1)),...
        round(txfm(3,1)+1:txfm(3,1)+imsize(2))) = im;
    
    if animate
        imshow(canvas);
        drawnow();
        pause(0.1);
    end
end

% Add the proposed ROI positions
imshow(canvas);
hold on;
plot(db.data.fovea_xy(1), db.data.fovea_xy(2), 'og');

if exist('u_loc_xy_px', 'var') ~= 0 && ~isempty(u_loc_xy_px)
    n_rois = size(u_loc_xy_px, 1);
    
    plot(u_loc_xy_px(:,1), u_loc_xy_px(:,2), '*r')
    t = linspace(0,2*pi,50);
    for ii=1:n_rois
        xy = u_loc_xy_px(ii,:);
        this_roi_xy = [
            xy(1)-roi_sz_px/2, xy(1)+roi_sz_px/2, xy(1)+roi_sz_px/2, xy(1)-roi_sz_px/2;
            xy(2)-roi_sz_px/2, xy(2)-roi_sz_px/2, xy(2)+roi_sz_px/2, xy(2)+roi_sz_px/2]';

        patch('xdata', this_roi_xy(:,1), 'ydata', this_roi_xy(:,2), ...
            'facecolor', 'none', 'edgecolor', 'r')
        
        this_roi_xy_w_tol = [
            xy(1)-roi_sz_px/2-roi_pos_tol, xy(1)+roi_sz_px/2+roi_pos_tol, xy(1)+roi_sz_px/2+roi_pos_tol, xy(1)-roi_sz_px/2-roi_pos_tol;
            xy(2)-roi_sz_px/2-roi_pos_tol, xy(2)-roi_sz_px/2-roi_pos_tol, xy(2)+roi_sz_px/2+roi_pos_tol, xy(2)+roi_sz_px/2+roi_pos_tol]';
        
        patch(...
            'xdata', roi_pos_tol.*cos(t)+xy(1), ...
            'ydata', roi_pos_tol.*sin(t)+xy(2), ...
            'facecolor', 'none', 'edgecolor', 'c');
        
        patch(...
            'xdata', this_roi_xy_w_tol(:,1), ...
            'ydata', this_roi_xy_w_tol(:,2), ...
            'facecolor', 'none', 'edgecolor', 'r', 'linestyle', ':');
    end
    
    
end

% Check for adjusted positions
% todo: hopefully we're able to implement a more robust optimization
% which includes rotation, so this would need to change in that case    
if exist('roi_shifts', 'var') ~= 0 && ~isempty(roi_shifts)
    roi_shifts(all(roi_shifts == 0, 2), :) = [];
    plot(roi_shifts(:,1), roi_shifts(:,2), 'bo')
end
hold off;



end

