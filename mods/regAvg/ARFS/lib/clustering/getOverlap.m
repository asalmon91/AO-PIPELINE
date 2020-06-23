function overlap = getOverlap(img_sz, xy1, xy2)
%getOverlap computes area of overlap in percent between two images

xy = round([xy1; xy2]);
overlap = ...
    numel(max(xy(:,1)) : min(xy(:,1)) + img_sz(2)) * ...
    numel(max(xy(:,2)) : min(xy(:,2)) + img_sz(1)) / ...
    prod(img_sz(1:2)) * 100;
end

