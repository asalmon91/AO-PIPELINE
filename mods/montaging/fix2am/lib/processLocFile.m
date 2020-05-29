function loc_data = processLocFile(loc_path, loc_fname)
%processLocFile universal reading and processing

%% Default
loc_data = [];

%% Read file
raw = readFixGuiFile(fullfile(loc_path, loc_fname));
if isempty(raw)
    return;
end
loc_head = raw(1, :);
loc_body = raw(2:end, :);
clear raw;

%% Get correct video # labels
vid_c = 1; % Column header is software version number...
n_digits = numel(num2str(max(cell2mat(loc_body(:, vid_c))-1)));
vidnums = pad(...
    cellfun(@strtrim, ... % remove leading white space before padding
    mat2cell(...
    num2str(...
    cell2mat(loc_body(:, vid_c))-1), ... % subtract 1 from each number
    ones(size(loc_body, 1), 1), n_digits), ... % shape of cell
    'uniformoutput', false), ...
    4, 'left', '0'); % pad with 0's to 4 chars on the left

%% Combine H and V coords
hc = strcmpi(loc_head, 'Horizontal Location');
vc = strcmpi(loc_head, 'Vertical Location');
coords = horzcat(...
    num2str(cell2mat(loc_body(:, hc)), '%1.3f'), ...
    repmat(', ', size(loc_body, 1), 1), ...
    num2str(cell2mat(loc_body(:, vc)), '%1.3f'));


%% Fields-of-view
% for now, fovs are symmetric, so just take one fov col
fovc = strcmpi(loc_head, 'Horizontal FOV');
fovs = cell2mat(loc_body(:, fovc));

%% Eyes
eyec = strcmpi(loc_head, 'Eye');
eyes = loc_body(:, eyec);

%% Put data in structure
loc_data.vidnums = vidnums;
loc_data.coords = coords;
loc_data.fovs = fovs;
loc_data.eyes = eyes;

end

