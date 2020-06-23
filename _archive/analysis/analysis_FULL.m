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
xy = fixCoordsToMat(db.mon.loc_data.coords);
dists = pdist2([0,0], xy);
min_r = min(dists);
max_r = max(dists);

% Generate an ROI at each integer retinal location
u_loc_xy_deg = unique(round(fixCoordsToMat(db.mon.loc_data.coords)), 'rows');


% Generate ROIs for cone segmentation
ROI_TRS_DEG = [45, 1, 0.5]; % theta, rho, size (in degrees)
[~,I] = min([db.cal.dsin.fov]);
this_ppd = db.cal.dsin(I).ppd;


t_vec = 0:ROI_TRS_DEG(1):360-ROI_TRS_DEG(1);
r_vec = min_r:ROI_TRS_DEG(2):max_r;
roi_xy_deg = [...
    reshape(r_vec'*cosd(t_vec), [numel(r_vec)*numel(t_vec), 1]), ...
    reshape(r_vec'*sind(t_vec), [numel(r_vec)*numel(t_vec), 1])];

% figure; scatter(roi_xy_deg(:,1), roi_xy_deg(:,2))
% xlabel(sprintf('ROI X (%s)', char(176)))
% ylabel(sprintf('ROI Y (%s)', char(176)))

% Scale to px
roi_xy_px = roi_xy_deg.*this_ppd;
% figure; scatter(roi_xy_px(:,1), roi_xy_px(:,2))
% xlabel(sprintf('ROI X (%s)', 'px'))
% ylabel(sprintf('ROI Y (%s)', 'px'))
% title(sprintf('Center at %0.1f, %0.1fpx', 0, 0));

% Shift 0,0 to fovea coords
roi_xy_px = roi_xy_px + fovea_xy;
% figure; scatter(roi_xy_px(:,1), roi_xy_px(:,2))
% xlabel(sprintf('ROI X (%s)', 'px'))
% ylabel(sprintf('ROI Y (%s)', 'px'))
% title(sprintf('Center at %0.1f, %0.1fpx', fovea_xy(1), fovea_xy(2)));

% Determine if each ROI



end

