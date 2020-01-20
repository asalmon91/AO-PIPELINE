function [ld, pff] = montage_LIVE(ld, paths, opts, pff, pool_id)
%montage_LIVE Handles parallelization for montaging

%% Return if empty
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
    return;
end

% Todo: figure out a way to allocate as many workers to montaging as
% possible. If desinusoiding and registration and averaging are all done,
% it would be good to put as much effort into this step as possible

%% Process videos if there's an open slot
if strcmp(pff.State, 'unavailable')
    % Determine new or append
    append_mon = isfield(ld.mon, 'mon_ffname') && ...
        ~isempty(ld.mon.mon_ffname);
    if ~append_mon
        ld.mon.mon_ffname = [];
    end
    
    % Limit location data to processed images
    loc_data = filterLocationDataByProcessed(ld);
    if numel(loc_data.vidnums) >= 2
            pff = parfeval(pool_id, @AOMosiacAllMultiModal, 1, ...
                paths.out, loc_data, paths.mon, 'multi_modal', ...
                ld.mon.mon_opts.mods, ld.mon.mon_opts.txfm_type, ...
                append_mon, ld.mon.mon_ffname, false, 0);
    end
end

%% Check for completed process
if strcmp(pff.State, 'finished') && isempty(pff.Error)
    ld.mon.mon_ffname = fetchOutputs(pff);

    % Reset future object
    pff = parallel.FevalFuture();
    
elseif ~isempty(pff.Error)
    % TODO: handle some error types
    rethrow(pff.Error)
end









end

