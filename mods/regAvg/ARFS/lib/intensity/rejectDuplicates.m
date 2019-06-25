function frames = rejectDuplicates(vid, frames)
%rejectDuplicates rejects any frames that are exactly the same as its
%neighbor

duplicates = false(size(vid, 3), 1);
for ii=1:size(vid,3)-1
    if isequal(vid(:,:,ii), vid(:,:,ii+1))
        duplicates(ii+1) = true;
    end
end
frames = rejectFrames(frames, duplicates, 'duplicate');


end

