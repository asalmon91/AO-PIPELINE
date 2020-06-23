function [ref_frame, nFramesReg, err] = getRefFrame(frames, mfpc)
%getRefFrame returns 1 reference frame id from the array of frame objects
%output from ARFSv2
% This will be the reference frame from the largest cluster with the
% highest inter-frame phase correlation coefficient

% Default error status
err         = false;
ref_frame   = 0;

% Sort linked frame groups by size
link_ids = sortLink_id_bySize(frames);
all_cluster_szs = cell(size(link_ids));
all_cluster_ids = cell(size(link_ids));
for ii=1:numel(link_ids)
    [all_cluster_ids{ii}, all_cluster_szs{ii}] = ...
        sortClusterBySize(frames, link_ids(ii));
end

% Find location of largest cluster
[~, LI] = max(...
    cellfun(@max, all_cluster_szs));
largest_link_id = link_ids(LI(1));
[~, CI] = max(all_cluster_szs{LI(1)});
largest_cluster_id = all_cluster_ids{LI(1)}(CI(1));

% Find frames in this cluster
frame_ids = [frames(...
    [frames.link_id] == largest_link_id & ...
    [frames.cluster] == largest_cluster_id...
    ).id];
nFramesReg = numel(frame_ids);

% Check for motion tracking failure
if nFramesReg < mfpc
    err = true;
    return;
end

%% Choose reference frame
pccs = [frames(frame_ids).pcc];
[~, I] = max(pccs);
ref_frame = frame_ids(I(1));

end

