function data = getClusters(data, vid_sz)
%getClusters Returns clusters of stable fixation
%   Uses kmeans and slihouette value optimization to pick the "best" number
%   of clusters.

% global wb;
OVERLAP_THR = 75; % Percent

% Waitbar
% waitbar(0, wb, 'Clustering frames...');
% todo: figure out why we're getting an infinite loop
% Get initial clustering
link_sort = sortLink_id_bySize(data);
for ii=1:numel(link_sort)
    linked = [data([data.link_id] == link_sort(ii)).id];
    data = getInitialClustering(data, linked);
    
%     waitbar(ii/numel(link_sort), wb)
end


%% Absorb clusters that overlap by >= OVERLAP_THR
% Waitbar
% waitbar(0, wb, 'Absorbing clusters...');

for ii=1:numel(link_sort) % For all link groups
    
    cluster_sort = sortClusterBySize(data, link_sort(ii));
    if numel(cluster_sort) == 1
        continue;
    end
        
    for jj=1:numel(cluster_sort) % Master cluster
        % Get centroid
        xy1 = getClusterCentroid(data, link_sort(ii), cluster_sort(jj));
        
        for kk=1:numel(cluster_sort) % Slave cluster
            if kk<=jj
                continue;
            end
            % Get coords for slave cluster
            slave_ids = [data(...
                [data.link_id] == link_sort(ii) & ...
                [data.cluster] == cluster_sort(kk)).id];
            xy2 = getAllXY(data(slave_ids));
            % Determine amount of overlap
            overlaps = zeros(size(xy2,1),1);
            for mm=1:size(xy2,1)
                overlaps(mm) = getOverlap(vid_sz, xy1, xy2(mm,:));        
            end
            % Change cluster number to that of the master cluster if the
            % amount of overlap is more than the threshold
            data = updateCluster(data, ...
                slave_ids(overlaps >= OVERLAP_THR), ...
                repmat(cluster_sort(jj), numel(slave_ids)));
        end
    end
%     waitbar(ii/numel(link_sort), wb);
end

%% Reject small clusters
data = rejectSmallClusters(data);

end

