function out_queue = updateQueues(ld, in_queue, queue_type)
%updateQueues 

switch queue_type
    case 'cal'
        
        
    case 'vid'
        if numel(cellfun(@isempty, in_queue))
            
        end
        
        all_processing = [ld.vid.vid_set.processing];
        n_processing = numel(find(all_processing));
        
        
        if n_processing < numel(in_queue)
            all_processed = [ld.vid.vid_set.processed];
            not_proc_idx = find(~all_processed & ~all_processing);
            
            
            
        end
        
    case 'mon'
        
        
end


end

