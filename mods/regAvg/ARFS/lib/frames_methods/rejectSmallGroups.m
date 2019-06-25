function data = rejectSmallGroups(data, mfpc)

% Preallocate rejection array
rej = false(size(data));
% Get unique link id's and sizes
[uid_sort, link_sz] = sortLink_id_bySize(data);
for ii=1:numel(data)
    if data(ii).rej % don't reject already rejected groups
        continue;
    end
    % Reject groups smaller than mfpc
    if link_sz(data(ii).link_id == uid_sort) < mfpc
        rej(ii) = true;
    end
end

data = rejectFrames(data, rej, mfilename);
end
