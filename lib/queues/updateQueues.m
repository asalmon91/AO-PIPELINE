function [proc_queue, par_queue] = updateQueues(proc_queue, par_queue)
%updateQueues shifts entries from the processing queue to the parallel
%queue if there is space

% Find empty slots in the parallel queue
par_queue_index = find(cellfun(@isempty, par_queue));
remove = false(size(proc_queue));
for ii=1:numel(par_queue_index)
    % Try to fill those slots with entries from the processing queue
    for jj=1:numel(proc_queue)
        % Skip if the parallel queue already contains this entry
        if any(strcmp(par_queue, proc_queue{jj}))
            remove(jj) = true;
            continue;
        end

        % Add it to the parallel queue
        par_queue{par_queue_index(ii)} = proc_queue{jj};
        remove(jj) = true;
        break;
    end
    if jj==numel(proc_queue)
        break; % all caught up
    end
end
% Remove the entries that are currently being processed or will 
% start being processed in the next step
proc_queue(remove) = [];

end

