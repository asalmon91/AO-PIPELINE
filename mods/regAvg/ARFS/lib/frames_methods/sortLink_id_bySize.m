function [uid_sort, srted_sz] = sortLink_id_bySize(data)

% Find unique link_ids
[unique_id, ~, ic] = unique(...
    [data([data.link_id]~=0 & ~[data.rej]).link_id]);
link_sz = zeros(size(unique_id));
for ii=1:numel(unique_id)
    % Find number of frames with this link id
    link_sz(ii) = numel(find(ic==ii));
end

% Sort by size
[srted_sz, I] = sort(link_sz, 'descend');
uid_sort = unique_id(I);

end