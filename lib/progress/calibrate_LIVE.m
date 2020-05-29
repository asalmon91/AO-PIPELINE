function [ld, pff] = calibrate_LIVE(ld, paths, pff, pool_id, gui)
%calibrate_LIVE basic handling of queue and evaluation

%% Return if empty
if isempty(ld.cal) || ~isfield(ld.cal, 'dsin') || isempty(ld.cal.dsin)
    return;
end

%% Process calibration files if there's an open slot
if strcmp(pff.State, 'unavailable')
    ld.cal.current_idx = getNextDsin(ld.cal);
    if ~isempty(ld.cal.current_idx)
%         fprintf('Processing %1.2f deg desinusoid data\n', ...
%             ld.cal.dsin(dsin_idx).fov);
        ld.cal.dsin(ld.cal.current_idx).processing = true;
        pff = parfeval(pool_id, @construct_dsin_mat, ...
            1, ld.cal.dsin(ld.cal.current_idx), paths.cal);
        update_pipe_progress(ld,paths,'cal',gui);
    end
end

%% Check for completed process
if strcmp(pff.State, 'finished') && isempty(pff.Error)
    out_dsin = fetchOutputs(pff);
    if out_dsin.processed
        ld.cal.dsin(ld.cal.current_idx) = out_dsin;
        fprintf('Done processing %1.2f desinusoid data\n', ...
            ld.cal.dsin(ld.cal.current_idx).fov);
    end
    % Reset future object
    pff = parallel.FevalFuture();
    update_pipe_progress(ld,paths,'cal',gui);
	ld.state_changed = true;
elseif ~isempty(pff.Error)
    % TODO: handle error
    error(getReport(pff.Error))
    % Reset future object
%     pff = parallel.FevalFuture();
end



end

