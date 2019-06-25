function status = any_vids_still_processing(vids_start, vids_done)
%any_vids_still_processing checks if all the videos that have started
%processing have finished

status = false;
for ii=2:numel(vids_start) % Skip the first value which is set at -0001
    if ~any(contains(vids_done, vids_start{ii}))
        status = true;
        break;
    end
end

end

