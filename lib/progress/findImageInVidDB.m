function key = findImageInVidDB(ld, image_fname)
%findImageInVidDB determines the index of an image in the video database

key = [];

for ii=1:numel(ld.vid.vid_set)
    for jj=1:numel(ld.vid.vid_set(ii).vids)
        for kk=1:numel(ld.vid.vid_set(ii).vids(jj).fids)
            for mm=1:numel(ld.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                if ismember(image_fname, ...
                        ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames)
                    key = [ii,jj,kk,mm];
                    return;
                end
            end
        end
    end
end

end

