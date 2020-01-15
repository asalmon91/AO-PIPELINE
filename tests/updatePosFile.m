function updatePosFile(loc_data, vidnums, out_ffname)
%updatePosFile overwrites the position file for simulation of an AO session
%   if vidnums is empty, just write the header


LOC_HEAD = {...
    'v0.1', 'Horizontal Location', 'Vertical Location', ...
    'Horizontal FOV', 'Vertical FOV', 'Eye'};
if isempty(vidnums)
    writecell(LOC_HEAD, out_ffname);
    return;
end

loc_data_idx = zeros(size(vidnums));
for ii=1:numel(vidnums)
    loc_data_idx(ii) = find(strcmp(vidnums{ii}, loc_data.vidnums));
end


% Get vidnum out
vidnums_out = mat2cell(...
    cellfun(@str2double, ...
    (loc_data.vidnums(loc_data_idx))) +1, ...
    ones(size(vidnums))); % 0 vs 1-based indexing

% Get h&v loc
h_loc = cell(size(vidnums));
v_loc = h_loc;
for ii=1:numel(vidnums)
    loc_parts = cellfun(@str2double, strsplit(loc_data.coords(loc_data_idx(ii), :), ','));
    h_loc{ii} = loc_parts(1);
    v_loc{ii} = loc_parts(2);
end


% fov & eye
fovs = mat2cell(loc_data.fovs(loc_data_idx), ones(size(vidnums)));
eyes = loc_data.eyes(loc_data_idx);

%% Combine into cell and write
pos_data = [vidnums_out, h_loc, v_loc, fovs, fovs, eyes];
pos_data = [LOC_HEAD; pos_data];
writecell(pos_data, out_ffname);


end

