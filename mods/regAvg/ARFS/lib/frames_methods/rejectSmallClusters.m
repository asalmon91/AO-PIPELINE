function data = rejectSmallClusters(data)
%rejectSmallClusters 

global MFPC;

% For all link_ids that haven't already been rejected
link_ids = unique([data(~[data.rej]).link_id]);
for ii=1:numel(link_ids)
    [cluster,~,ic] = unique(...
        [data([data.link_id] == link_ids(ii)).cluster]);
    % For all clusters within that link id
    for jj=1:numel(cluster)
        % If the number of frames is less than the threshold,
        if numel(find(ic==jj)) < MFPC
            ids = [data(...
                [data.link_id] == link_ids(ii) & ...
                [data.cluster] == cluster(jj)).id];
            % Reject it
            data = rejectFrames(data, ids, mfilename);
        end
    end
end
end

