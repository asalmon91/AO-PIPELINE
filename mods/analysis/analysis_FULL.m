function [db, paths] = analysis_FULL(db, paths, opts)
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

%% Set up output
paths.data = fullfile(paths.root, 'data');
if exist(paths.data, 'dir') == 0
    mkdir(paths.data);
end

% tic
%% Quick & Dirty approximation of the peak-cone-density location
[db.data.fovea_xy, canvas] = estimateFovea(db, paths, opts);
% toc

% tic
% do_par = true;
% row_or_cell = 'row'; % Change this to cell if analyzing split images
% db.data.fovea_xy = fx_montage_dft_analysis(paths.mon_out, [], ...
%     db, opts.mod_order{1}, opts.lambda_order(1), do_par, row_or_cell, paths, opts);
% toc

%% Get ROI's
rois = getROIs(db, paths, opts);

%% Count these images
write_rois = true;
rois = countROIs(db, paths, opts, rois, write_rois);
db.data.rois = rois;


%% Output .map for use with Mosaic
db.data.maps = outputMAP(db, rois, paths);


end

