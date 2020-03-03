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

%% Estimate spacing, estimate location of foveola
row_or_cell = 'row'; % Change this to cell if analyzing split images
db.data.fovea_xy = fx_montage_dft_analysis(aligned_tif_path, ...
    opts.mod_order{1}, opts.lambda_order(1), do_par, row_or_cell);

%% Get ROI's
rois = getROIs(db, paths, opts);

%% Count these images
rois = countROIs(db, paths, opts, rois);


end

