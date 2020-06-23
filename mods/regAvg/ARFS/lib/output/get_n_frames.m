function n_frames = get_n_frames(frames, refFrames)
%get_n_frames returns the number of frames estimated to align with
%refFrames

n_frames = zeros(size(refFrames));
for ii=1:numel(refFrames)
    link_id = frames(refFrames(ii)).link_id;
    cluster_id = frames(refFrames(ii)).cluster;
    
    n_frames(ii) = numel(find(...
        [frames.link_id] == link_id & ...
        [frames.cluster] == cluster_id));
%     n_frames(ii) = numel(find([frames.link_id] == link_id));
end

end

