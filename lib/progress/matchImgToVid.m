function key = matchImgToVid(vidset_array, img_fname)
%matchImgToVid determines which video in the database and image belongs
%to

key = [0,0];
for ii=1:numel(vidset_array)
    for jj=1:numel(vidset_array(ii).vids)
        [~,vid_name] = fileparts(vidset_array(ii).vids(jj).filename);
        if contains(img_fname, vid_name)
            key = [ii,jj];
            break;
        end
    end
    if ~all(key==0)
        break
    end
end







end

