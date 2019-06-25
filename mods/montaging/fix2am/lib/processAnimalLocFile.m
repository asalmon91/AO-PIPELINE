function loc_data = processAnimalLocFile( loc_path, loc_fname, ...
    sheet_name, aviSets, eye_tag)
%processAnimalLocFile Processes an Animal Imaging Notes Spreadsheet
% Animals can't fixate, so we have a completely different method of note
% taking

%% Read file
[~,~,raw] = xlsread(fullfile(loc_path, loc_fname), sheet_name);
loc_head = raw(1, :);
loc_body = raw(2:end, :);
clear raw;

%% Get correct video # labels
vid_c = strcmpi(loc_head, 'video #');
vid_nums = loc_body(:, vid_c);
remove = true(size(vid_nums));
for ii=1:numel(vid_nums)
    for jj=1:numel(aviSets)
        if strcmp(vid_nums{ii}, aviSets(jj).num)
            remove(ii) = false;
            break
        end
    end
end
loc_body(remove, :) = [];

%% Eyes
eyec = strcmpi(loc_head, 'Eye');
eyes = loc_body(:, eyec);
eyes = copyDown(eyes);
remove = ~strcmpi(eyes, eye_tag);
loc_body(remove, :) = [];
eyes(remove) = [];
% Reset vid_nums as well in case the numbers were reset for the other eye
vid_nums = loc_body(:, vid_c);

%% Combine H and V coords
% hc = strcmpi(loc_head, 'Horizontal Location');
% vc = strcmpi(loc_head, 'Vertical Location');
% coords = horzcat(...
%     num2str(cell2mat(loc_body(:, hc)), '%1.3f'), ...
%     repmat(', ', size(loc_body, 1), 1), ...
%     num2str(cell2mat(loc_body(:, vc)), '%1.3f'));
coords = loc_body(:, strcmpi(loc_head, 'X, Y'));
for ii=1:numel(coords)
    if isnan(coords{ii})
        coords{ii} = '0, 0';
    end
end

%% Fields-of-view
% for now, fovs are symmetric, so just take one fov col
fovc = strcmpi(loc_head, 'FOV (°)');
fovs = loc_body(:, fovc);
fovs = copyDown(fovs);
fovs = cell2mat(fovs);

%% Put data in structure
loc_data.vidnums = vid_nums;
loc_data.coords = coords;
loc_data.fovs = fovs;
loc_data.eyes = eyes;


end

