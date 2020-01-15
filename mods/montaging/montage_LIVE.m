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
    [append_mon] = setupMontageBatch(ld.mon);
    % Determine new or append
    
    % Update position file
    [pos_ffname, ~, ok] = fx_fix2am(ld.mon.loc_file.name, ...
        'human', 'penn', ld.cal.dsin, [], 'ID', ld.date, ld.eye);
    if ~ok
    
    if ~isempty(append_mon)
        % This is probably not the best way to do this for a few reasons:
        % every time the montage gets appended, it has to re-read the .mat
        % file, and it has to read the position file
        pff = parfeval(pool_id, @AOMosiacAllMultiModal, 4, paths.out, ...
            posFileLoc, outputDir, 'multimodal', opts.proc_mods, ...
            ld.mon.mon_opts.txfm_type, append_mon, ld.mon.mon_ffname, ...
            false, 0);
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
elseif ~isempty(pff.Error)
    % TODO: handle error
    rethrow(pff.Error)
    % Reset future object
%     pff = parallel.FevalFuture();
end









end

