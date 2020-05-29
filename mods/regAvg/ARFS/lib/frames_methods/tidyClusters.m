function frames_out = tidyClusters(frames)
%tidyClusters renumbers the link id's and cluster id's to be sequential

% Set all rejected frames to a link and cluster id of 0
rejected_ids = find([frames.rej]);
frames_out = updateLinkID(frames, rejected_ids, 0);
frames_out = updateCluster(frames_out, rejected_ids, zeros(size(rejected_ids)));

% Get unique non-zero link id's and renumber
lids = unique([frames_out.link_id]);
lids(lids==0) = [];
[~,IL] = sort(lids, 'ascend');
for ii=1:numel(lids)
    ids = [frames_out([frames_out.link_id]==lids(ii)).id];
    frames_out = updateLinkID(frames_out, ids, IL(ii));
    
    % Do the same for the clusters within this link id
    cids = unique([frames_out(ids).cluster]);
    [~,IC] = sort(cids, 'ascend');
    for jj=1:numel(cids)
        linked_frames = frames_out(ids);
        lc_ids = [linked_frames([linked_frames.cluster] == cids(jj)).id];
        frames_out = updateCluster(frames_out, lc_ids, ...
            ones(size(lc_ids)).*IC(jj));
    end
end

end

