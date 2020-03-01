function frame_list = get_best_n_frames_per_cluster(frames, n_per_cluster)
%getRefFrames Returns the index of the best frame from each cluster

% Reference frame can't be 1 for some reason
% Probably a 0-based indexing thing
% todo: create a patch for demotion that fixes this bug
frames = rejectFrames(frames, 1, 'firstFrame');

link_ids = sortLink_id_bySize(frames);
% Create structure to contain results from all clusters
frame_list(numel(link_ids)).lid = link_ids(end);
for ii=1:numel(link_ids)
    frame_list(ii).lid = link_ids(ii);
    cluster_ids = sortClusterBySize(frames, link_ids(ii));
    
    frame_list(ii).cluster(numel(cluster_ids)).cid = cluster_ids(end);
    for jj=1:numel(cluster_ids)
        frame_list(ii).cluster(jj).cid = cluster_ids(jj);
        % Get frame id's within this linked group and cluster
        ids = [frames(...
            [frames.link_id] == link_ids(ii) & ...
            [frames.cluster] == cluster_ids(jj)).id];
        pccs = [frames(ids).pcc];
        % Sort pccs and extract up to n_per_cluster
        [sorted_pccs, pcc_idx] = sort(pccs, 'descend');
        n_extract = n_per_cluster;
        if numel(ids) < n_per_cluster % in case user asks for too many
            n_extract = numel(ids);
        end
        sorted_ids = ids(pcc_idx);
        frame_list(ii).cluster(jj).fids = sorted_ids(1:n_extract);
        frame_list(ii).cluster(jj).pccs = sorted_pccs(1:n_extract);
    end
end

end

