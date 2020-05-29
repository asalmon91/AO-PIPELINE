function vidset_idx = getNextVidset(vid_data)
%getNextVidset finds the next video for processing

% Return empty by default
vidset_idx    = [];

% Determine the first one in the database that is ready for processing
for ii=1:numel(vid_data.vid_set)
    if ~vid_data.vid_set(ii).processing && ...
            ~vid_data.vid_set(ii).processed && ...
            all([vid_data.vid_set(ii).vids.ready]) && ...
            vid_data.vid_set(ii).hasCal && ...
            vid_data.vid_set(ii).hasAllMods && ...
            ~isempty(vid_data.vid_set(ii).fov) && ...
            ~isempty(vid_data.vid_set(ii).vidnum)
        vidset_idx = ii;
        break;
    end
end

end

