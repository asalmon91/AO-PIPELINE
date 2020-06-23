function fids = get_best_n_frames_overall(frames, n_frames)
%get_best_n_frames_overall returns the # (n_frames) frames with the highest pcc values

% Check input for errors
if n_frames < 1
	error('n_frames cannot be less than 1');
elseif n_frames > numel(frames)
	n_frames = numel(frames);
	warning('n_frames > # frames, capping at %i', numel(frames));
end

% todo: account for rejected frames
[sorted_pccs, sort_idx] = sort([frames.pcc], 'descend');
ids = [frames.id];
ids = ids(sort_idx);
ids = ids(1:n_frames);

% Create a structure similar to the output of get_best_n_frames_per_cluster
fids(numel(ids)).lid = numel(ids);
for ii=1:numel(ids)
	fids(ii).lid = ii;
	fids(ii).cluster.cid = 1;
	fids(ii).cluster.fids = ids(ii);
	fids(ii).cluster.pccs = sorted_pccs(ii);
end

