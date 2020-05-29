function [cluster_sort, s_cluster_sz] = sortClusterBySize(data,link_id)
%sortClusterBySize returns the cluster ids sorted by number of frames with
%that id

clusters = [data([data.link_id] == link_id & ~[data.rej]).cluster];
[u_clusters,~,ic] = unique(clusters);
if numel(u_clusters) == 1
    cluster_sort = u_clusters;
    s_cluster_sz = numel(ic);
    return;
end
cluster_sz = zeros(size(u_clusters));
for ii=1:numel(u_clusters)
    cluster_sz(ii) = numel(find(ic==ii));
end
[~, I] = sort(cluster_sz, 'descend');
cluster_sort = u_clusters(I);
s_cluster_sz = cluster_sz(I);

end

