function key = findImageInMonDB(ld, img_fname)
%findImageInMonDB returns the index of the montage database that contains
%this image

%% Default
key = [];

for ii=1:numel(ld.mon.imgs)
    if ismember(img_fname, ld.mon.imgs(ii).fnames)
        key = ii;
        return;
    end
end


end

