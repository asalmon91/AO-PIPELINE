function rois = countROIs(db, paths, opts, rois)
%countROIs 

%% Counts cones in ROIs
for ii=1:numel(rois)
    if ~rois(ii).success
        continue;
    end
    roi = rois(ii);
    
    %% Determine channel
    % todo: for now, just do whatever's listed
    
    %% Read image, extract ROI
    im = imread(fullfile(paths.mon_out, rois(ii).filename));
    im = im(...
        roi.xywh(2)-roi.xywh(4)/2:roi.xywh(2)+roi.xywh(4)/2, ... % y
        roi.xywh(1)-roi.xywh(3)/2:roi.xywh(1)+roi.xywh(3)/2, ... % x
        1); % image layer
    
    %% Count cones
    
    
    
    %% Update ROI array
    rois(ii) = roi;
end







end

