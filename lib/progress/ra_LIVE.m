function [ld, pff] = ra_LIVE(ld, paths, opts, pff, pool_id, gui)
%ra_LIVE Handles parallelization for registration and averaging

%% Return if empty
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
    return;
end

%% Todo: to allow more than one slot for r/a
% input could be a subset of the video parfeval future objects

%% Process videos if there's an open slot
if strcmp(pff.State, 'unavailable')
    ld.vid.current_idx = getNextVidset(ld.vid);
    if ~isempty(ld.vid.current_idx)
        dsin_idx = matchVidsetToDsin(ld.vid.vid_set(ld.vid.current_idx), ld.cal.dsin);
        this_dsin = ld.cal.dsin(dsin_idx);
        pff = parfeval(pool_id, @quickRA, 1, ld, paths, this_dsin, opts);
        update_pipe_progress(ld, paths, 'vid', gui)
    end
end

%% Check for completed process
if strcmp(pff.State, 'finished') && isempty(pff.Error)
    out_vidset = fetchOutputs(pff);
    if out_vidset.processed
        ld.vid.vid_set(ld.vid.current_idx) = out_vidset;
        fprintf('Done processing video %i\n', ...
            ld.vid.vid_set(ld.vid.current_idx).vidnum);
    end
    % Reset future object
    pff = parallel.FevalFuture();
    update_pipe_progress(ld, paths, 'vid', gui)
elseif ~isempty(pff.Error)
    % TODO: handle error
    rethrow(pff.Error)
    % Reset future object
%     pff = parallel.FevalFuture();
end





end

