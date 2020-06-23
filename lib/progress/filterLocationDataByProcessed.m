function loc_data = filterLocationDataByProcessed(ld)
%filterLocationDataByProcessed Determines which videos have been processed
%and returns a filtered location data structure

% 1) convert each video number to double
% 2) convert the cell array output to a double array
loc_vidnums = cell2mat(...
    cellfun(@str2double, ...
    ld.mon.loc_data.vidnums, 'uniformoutput', false));
% Get all video numbers that have already been processed
proc_vidnums = [ld.vid.vid_set([ld.vid.vid_set.processed]).vidnum]';
% Determine which 
current_idx = false(size(loc_vidnums));
for ii=1:numel(loc_vidnums)
    current_idx(ii) = ismember(loc_vidnums(ii), proc_vidnums);
end

loc_data = ld.mon.loc_data;
loc_data.vidnums(~current_idx)      = [];
loc_data.coords(~current_idx, :)    = [];
loc_data.fovs(~current_idx)         = [];
loc_data.eyes(~current_idx)         = [];
loc_data.fringes(~current_idx)      = [];

% Do we need to consider the case where a processed video exists, but we
% don't have location information for it?



end

