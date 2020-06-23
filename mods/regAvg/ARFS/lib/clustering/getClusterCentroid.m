function cluster_xy = getClusterCentroid(data, link, cluster)
%getClusterCentroid Returns the centroid of the coordinates of the frames
%in the cluster

cluster_xy = mean(getAllXY(data(...
    [data.link_id] == link & ...
    [data.cluster] == cluster)), ...
    1);

end

