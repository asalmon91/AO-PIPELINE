function refFrames = getRefFrames(frames)
%getRefFrames Returns the index of the best frame from each cluster

link_ids = sortLink_id_bySize(frames);
link_ref_list = cell(size(link_ids));
link_pcc_list = link_ref_list;
for ii=1:numel(link_ids)
    cluster_ids = sortClusterBySize(frames, link_ids(ii));
    
    cluster_ref_list = zeros(size(cluster_ids));
    cluster_pcc_list = cluster_ref_list;
    for jj=1:numel(cluster_ids)
        ids = [frames(...
            [frames.link_id] == link_ids(ii) & ...
            [frames.cluster] == cluster_ids(jj)).id];
        pccs = [frames(ids).pcc];
        refs = ids(pccs == max(pccs));
        cluster_ref_list(jj) = refs(1); % Almost always comes in pairs
        cluster_pcc_list(jj) = max(pccs);
    end
    
    link_ref_list{ii} = cluster_ref_list;
    link_pcc_list{ii} = cluster_pcc_list;
end

% Flatten link_ref_list into single array
n_refs = sum(cellfun(@numel, link_ref_list));
refFrames = zeros(n_refs, 1);
pccs = refFrames;
k=0;
for ii=1:numel(link_ids)
    for jj=1:numel(link_ref_list{ii})
        k=k+1;
        refFrames(k) = link_ref_list{ii}(jj);
        pccs(k) = link_pcc_list{ii}(jj);
    end
end

% Sort by descending pcc's and process frames in the order that is most
% likely to be successful 
[~, I] = sort(pccs, 'descend');
refFrames = refFrames(I);


end

