function data = getInitialClustering(data, indices)
%getInitialClustering 

global MFPC;

%% Ensure we're calling the default k-means
% Conflicts with automontager
% Is on the path toolbox\stats\stats\kmeans.m
kmeans_functions = which('kmeans', '-all');
if isempty(kmeans_functions)
    error('Stats toolbox required');
end
expected_path = 'toolbox\stats\stats\kmeans.m';
if ~contains(kmeans_functions{1}, expected_path)
    kmeans_path = kmeans_functions(contains(kmeans_functions, expected_path));
    if isempty(kmeans_path)
        error('Required function not found: %s', expected_path);
    end
    if numel(kmeans_path) > 1
        error('Ambiguous import, contact IT: %s', expected_path);
    end
    kmeans_path = fileparts(kmeans_path{1});
    addpath(kmeans_path, '-begin');
end

%% Determine maximum number of clusters such that largest cluster is
% guaranteed to be larger than MFPC
maxK = floor(numel(indices)/MFPC);
if maxK <= 1
    data = updateCluster(data, indices, ones(size(indices)));
    return;
end

% Determine best number of clusters using the Silhouette statistic
xy = getAllXY(data(indices));
evalSilhouette = evalclusters(xy,'kmeans',...
    'silhouette','KList',1:maxK);

% Ensure biggest cluster exceeds size threshold
if isnan(evalSilhouette.OptimalK)
    optK = maxK;
else
    optK = evalSilhouette.OptimalK;
end
tblSilh = 0;
while max(tblSilh) <= MFPC
    clusterSilhouette = kmeans(xy,optK,'Replicates',5);
    optK = optK - (max(tblSilh) <= MFPC);
    tblSilh = tabulate(clusterSilhouette);
    tblSilh = tblSilh(:,2);
end

% Update cluster ids with initial assignments
data = updateCluster(data, indices, clusterSilhouette);

end

