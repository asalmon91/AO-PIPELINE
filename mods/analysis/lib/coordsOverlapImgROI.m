function coords = coordsOverlapImgROI(img_xywh, roi_xywh, roi_xy_tol)
%coordsOverlapImgROI returns the coordinates of the image that ensure an
%ROI would be completely overlapping


%% Optional input
if exist('roi_xy_tol', 'var') == 0 || isempty(roi_xy_tol)
    roi_xy_tol = 0;
end

%% Clip half the ROI size off each edge
% This ensures the center would be more than half it's size on the inside
% of the image
img_xywh_tmp = img_xywh; %#ok<NASGU> % Can comment out
img_xywh(3:4) = img_xywh(3:4) - roi_xywh(3:4);
if img_xywh(3) < roi_xywh(3) || img_xywh(4) < roi_xywh(4)
    % Image is too small to contain this ROI
    coords = [];
    return;
end

%% Crop to smallest area possible
% Find distance to edges nearest the origin
minx = [roi_xywh(1)-roi_xy_tol-roi_xywh(3)/2, img_xywh(1)-img_xywh(3)/2];
miny = [roi_xywh(2)-roi_xy_tol-roi_xywh(3)/2, img_xywh(2)-img_xywh(4)/2];
dxdy = [min(minx), min(miny)];
% Crop
roi_xywh(1:2) = roi_xywh(1:2) - dxdy +1;
img_xywh(1:2) = img_xywh(1:2) - dxdy +1;

% Get new dimensions
maxx = [roi_xywh(1)+roi_xywh(3), img_xywh(1)+img_xywh(3)/2];
maxy = [roi_xywh(2)+roi_xywh(3), img_xywh(2)+img_xywh(4)/2];

%% Create a mask of both
% Circle
t = linspace(0,2*pi,720);
% circ_xy = [
%     (roi_xywh(3)/2 + roi_xy_tol).*cos(t) + roi_xywh(1);
%     (roi_xywh(4)/2 + roi_xy_tol).*sin(t) + roi_xywh(2)]';
circ_xy = [
    roi_xy_tol.*cos(t) + roi_xywh(1);
    roi_xy_tol.*sin(t) + roi_xywh(2)]';
circ_mask = poly2mask(circ_xy(:,1), circ_xy(:,2), ...
    ceil(max(maxy)), ceil(max(maxx)));

% Rectangle
rect_mask = false(size(circ_mask));
rect_mask(...
    round(img_xywh(2)-img_xywh(4)/2:img_xywh(2)+img_xywh(4)/2), ...
    round(img_xywh(1)-img_xywh(3)/2:img_xywh(1)+img_xywh(3)/2)) = true;

%% Find overlapping coordinates
overlap = circ_mask & rect_mask;
[r,c] = find(overlap);
if isempty(r)
    coords = [];
    return;
end
% Shift coords by the earlier crop
coords = uint16([c, r] + dxdy -1);

% % DEV/DB
% figure;
% imshowpair(circ_mask, rect_mask, 'falsecolor', ...
%     'colorchannels', 'red-cyan');
% axis on
% set(gca, 'xticklabel', round(str2double(get(gca,'xticklabel'))+dxdy(1)))
% set(gca, 'yticklabel', round(str2double(get(gca,'yticklabel'))+dxdy(2)))
% hold on;
% % Okay I'm sorry about this:
% % This is just to plot the original image boundary... There's probably a
% % better way.
% patch(...
%     'xdata', ...
%     [img_xywh_tmp(1)-dxdy(1)+1-img_xywh_tmp(3)/2, img_xywh_tmp(1)-dxdy(1)+1+img_xywh_tmp(3)/2, ...
%     img_xywh_tmp(1)-dxdy(1)+1+img_xywh_tmp(3)/2, img_xywh_tmp(1)-dxdy(1)+1-img_xywh_tmp(3)/2], ...
%     'ydata', ...
%     [img_xywh_tmp(2)-dxdy(2)+1-img_xywh_tmp(4)/2, img_xywh_tmp(2)-dxdy(2)+1-img_xywh_tmp(4)/2, ...
%     img_xywh_tmp(2)-dxdy(2)+1+img_xywh_tmp(4)/2, img_xywh_tmp(2)-dxdy(2)+1+img_xywh_tmp(4)/2], ...
%     'facecolor', 'none', 'edgecolor', 'g', 'linestyle', ':');
% legend({'Original image boundary'})
% hold off;
% box off
% % END DEV/DB


end

