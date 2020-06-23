function [overlap, amount, theta] = ...
    doOverlap(tlc_xy_a, brc_xy_a, tlc_xy_b, brc_xy_b)
%doOverlap Checks whether two rectangles overlap given the xy coordinates
%of their top-left and bottom right corners. DOES NOT ACCOUNT FOR ROTATION

% Determine Cartesian- or Image-space
if brc_xy_a(2) < tlc_xy_a(2)
    % If Cartesian, flip all Y's
    tlc_xy_a(2) = tlc_xy_a(2)*-1;
    brc_xy_a(2) = brc_xy_a(2)*-1;
    tlc_xy_b(2) = tlc_xy_b(2)*-1;
    brc_xy_b(2) = brc_xy_b(2)*-1;
end


% no_ol_x = tlc_xy_a(1) >= brc_xy_b(1) || tlc_xy_b(1) >= brc_xy_a(1);
% no_ol_y = tlc_xy_a(2) >= brc_xy_b(2) || tlc_xy_b(2) >= brc_xy_a(2);
% overlap = ~no_ol_x && ~no_ol_y;


minx = [tlc_xy_a(1), tlc_xy_b(1)];
maxx = [brc_xy_a(1), brc_xy_b(1)];
miny = [tlc_xy_a(2), tlc_xy_b(2)];
maxy = [brc_xy_a(2), brc_xy_b(2)];

amount = max(min(maxx) - max(minx), 0) * max(min(maxy) - max(miny), 0);
overlap = amount > 0;

% Get amount of overlap
% if ~overlap
%     amount = 0;
% else
%     minx = [tlc_xy_a(1), tlc_xy_b(1)];
%     maxx = [brc_xy_a(1), brc_xy_b(1)];
%     miny = [tlc_xy_a(2), tlc_xy_b(2)];
%     maxy = [brc_xy_a(2), brc_xy_b(2)];
% 
%     amount = (min(maxx) - max(minx)) * (abs(min(maxy) - max(miny)));
% end

% Get angle of line connecting rectangle a center to rectangle b center
c_xy_a = zeros(1,2);
c_xy_b = c_xy_a;
% X
c_xy_a(1) = tlc_xy_a(1) + (brc_xy_a(1) - tlc_xy_a(1))/2;
c_xy_b(1) = tlc_xy_b(1) + (brc_xy_b(1) - tlc_xy_b(1))/2;
% Y
if brc_xy_a(2) > tlc_xy_a(2) % ydir: reverse (image coordinates)
    c_xy_a(2) = tlc_xy_a(2) + (brc_xy_a(2) - tlc_xy_a(2))/2;
    c_xy_b(2) = tlc_xy_b(2) + (brc_xy_b(2) - tlc_xy_a(2))/2;
else % ydir: normal (euclidean coordinates)
    c_xy_a(2) = tlc_xy_a(2) - (tlc_xy_a(2) - brc_xy_a(2))/2;
    c_xy_b(2) = tlc_xy_b(2) - (tlc_xy_a(2) - brc_xy_b(2))/2;
end
% Subtract center xy a from b
c_xy_b = c_xy_b - c_xy_a;

theta = atan2(c_xy_b(2), c_xy_b(1))*(180/pi);

end

