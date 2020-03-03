function coords = coordsOverlapCircleRect(circ_xyr, rect_xywh)
%coordsOverlapCircleRect returns the coordinates of the image that are overlapping
%between a circle and a rectangle

%% Crop to smallest area possible
minx = [circ_xyr(1)-circ_xyr(3), rect_xywh(1)-rect_xywh(3)/2];
miny = [circ_xyr(2)-circ_xyr(3), rect_xywh(2)-rect_xywh(4)/2];
dxdy = [min(minx), min(miny)];

circ_xyr(1:2) = circ_xyr(1:2) - dxdy +1;
rect_xywh(1:2) = rect_xywh(1:2) - dxdy +1;

% Get new dimensions
maxx = [circ_xyr(1)+circ_xyr(3), rect_xywh(1)+rect_xywh(3)/2];
maxy = [circ_xyr(2)+circ_xyr(3), rect_xywh(2)+rect_xywh(4)/2];

%% Create a mask of both
% Circle
t = linspace(0,2*pi,720);
circ_xy = [
    circ_xyr(3).*cos(t)+ circ_xyr(1);
    circ_xyr(3).*sin(t)+ circ_xyr(2)]';
circ_mask = poly2mask(circ_xy(:,1), circ_xy(:,2), ...
    ceil(max(maxy)), ceil(max(maxx)));

% Rectangle
rect_mask = false(size(circ_mask));
rect_mask(...
    round(rect_xywh(2)-rect_xywh(4)/2:rect_xywh(2)+rect_xywh(4)/2), ...
    round(rect_xywh(1)-rect_xywh(3)/2:rect_xywh(1)+rect_xywh(3)/2)) = true;

%% Find overlapping coordinates
overlap = circ_mask & rect_mask;
[r,c] = find(overlap);
coords = uint16([c, r] + dxdy -1); % Shift coords by the earlier crop

% % DEV/DB
% figure;
% imshowpair(circ_mask, rect_mask, 'falsecolor', ...
%     'colorchannels', 'red-cyan');
% % END DEV/DB


end

