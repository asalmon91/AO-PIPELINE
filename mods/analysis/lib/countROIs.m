function rois = countROIs(db, paths, opts, rois, write_rois)
%countROIs 

% % DEV/DB
f = figure;
% % END DEV/DB
if write_rois
    % Setup output
    paths.uncorr = fullfile(paths.data, 'uncorr');
    if exist(paths.uncorr, 'dir') == 0
        mkdir(paths.uncorr);
    end
end
    


%% Counts cones in ROIs
for ii=1:numel(rois)
    if ~rois(ii).success
        continue;
    end
    
    %% Determine channel
    [count_handle, modality] = determineCountingAlgorithm(rois(ii), opts);
    in_fname = rois(ii).filename;
    key = matchImgToVid(db.vid.vid_set, in_fname);
    in_mod = db.vid.vid_set(key(1)).vids(key(2)).modality;
    if ~strcmp(in_mod, modality)
        search_name = [strrep(in_fname(1:end-6), in_mod, modality), '*.tif'];
        search_results = dir(fullfile(paths.mon_out, search_name));
        if numel(search_results) == 1
            out_fname = search_results.name;
        else
            error('Failed to find the image');
        end
    else
        out_fname = in_fname;
    end
    
    %% Read image, extract ROI
    im = imread(fullfile(paths.mon_out, out_fname));
    try
        im = im(...
            rois(ii).xywh(2)-rois(ii).xywh(4)/2:rois(ii).xywh(2)+rois(ii).xywh(4)/2, ... % y
            rois(ii).xywh(1)-rois(ii).xywh(3)/2:rois(ii).xywh(1)+rois(ii).xywh(3)/2, ... % x
            1); % image layer
    catch me
        if strcmp(me.identifier, 'MATLAB:badsubscript')
            warning(me.message)
            warning('ROI could not be extracted from: %i, %i', ...
                rois(ii).loc_deg(1), rois(ii).loc_deg(2));
            rois(ii).success = false;
            % Keep all the other metadata for diagnostics
            continue;
        else
            rethrow(me);
        end
    end
    
    %% Count cones
    coords_xy = fx_cone_counting(im, count_handle, rois(ii).loc_deg);
    rois(ii).coords_xy = coords_xy;
    
    %% Output images and coordinates
    if write_rois
        [~,im_name, im_ext] = fileparts(out_fname);
        im_out_fname = [im_name, ...
            sprintf('_%0.2f_%0.2f%s', ...
            rois(ii).loc_deg(1), rois(ii).loc_deg(2), im_ext)];
        imwrite(im, fullfile(paths.uncorr, im_out_fname));
        csv_out_fname = strrep(im_out_fname, im_ext, '.csv');
        csvwrite(fullfile(paths.uncorr, csv_out_fname), coords_xy);
    end
    
    % DEV/DB
    loc_deg = rois(ii).loc_deg;
    imshow(im);
    hold on;
    plot(coords_xy(:,1), coords_xy(:,2), '.r');
    hold off;
    if exist('loc_deg', 'var') && ~isempty(loc_deg)
        title(sprintf('%i, %i', loc_deg(1), loc_deg(2)));
    end
    img_frame = getframe(f);
    if ii==1
        wm = 'overwrite';
    else
        wm = 'append';
    end
    imwrite(img_frame.cdata, fullfile(paths.data, 'counted_rois.tiff'), ...
        'writemode', wm);
    % END DEV/DB
end







end

