function out_ffnames = outputMAP(db, rois, paths)
%outputMAP outputs a ".map" file for use with Mosaic
%   Mosaic is a tool for manually refining ROI positions, identifying
%   cells, and extracting metrics
%   Currently supports versions 0.4-0.5

%% Constants
VER = [0.4, 0.5];

%% Convert roi centers to origins
for ii=1:numel(rois)
    if ~rois(ii).success
        continue;
    end
    rois(ii).xywh(1:2) = rois(ii).xywh(1:2) - rois(ii).xywh(3:4)./2;
end

%% Create all supported versions of .map files
out_ffnames = cell(numel(VER), 1);
for ii=1:numel(VER)
    % Get output full file name
    out_ffname = fullfile(paths.data, ...
        [strjoin({db.id, db.date, db.eye, ...
        sprintf('%0.1f', VER(ii))},'-'), '.map']);
    % Construct and write
    xmlwrite(out_ffname, roi2map(db.data.fovea_xy, rois, VER(ii)));
    out_ffnames{ii} = out_ffname;
end



end

