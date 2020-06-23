function loc_data = processAnimalLocFile( loc_path, loc_fname, ...
    sheet_name, aviSets, eye_tag)
%processAnimalLocFile Processes an Animal Imaging Notes Spreadsheet
% Animals can't fixate, so we have a completely different method of note
% taking

%% Constants
VID_NUM_TXT = 'Video #';

%% Read file
[~,~,raw] = xlsread(fullfile(loc_path, loc_fname), sheet_name);
loc_head = raw(1, :);
loc_body = raw(2:end, :);
clear raw;

%% Fill in blanks with last value
for ii=1:numel(loc_head)
    if strcmpi(loc_head, VID_NUM_TXT)
        continue;
    end
    loc_body(:,ii) = copyDown(loc_body(:,ii));
end

%% Get correct video # labels
vid_c = strcmpi(loc_head, VID_NUM_TXT);
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
% Convert the text in the location column, which is in the format 'x, y',
% to doubles so that they can be converted to a char array to match the
% formatting of the human locations
xy = loc_body(:, strcmpi(loc_head, 'X, Y'));
x = cell(size(xy));
y = x;
for ii=1:numel(xy)
    if isnan(xy{ii})
        xy{ii} = '0, 0';
    end
    xy{ii} = strrep(xy{ii}, ' ', '');
    xy_parts = strsplit(xy{ii}, ',');
    if numel(xy_parts) == 2
        x{ii} = str2double(xy_parts{1});
        y{ii} = str2double(xy_parts{2});
    else
        warning('Error parsing %s, defaulting to 0, 0', xy{ii});
        x{ii} = 0;
        y{ii} = 0;
    end
end
coords = horzcat(...
    num2str(cell2mat(x), '%1.3f'), ...
    repmat(', ', size(loc_body, 1), 1), ...
    num2str(cell2mat(y), '%1.3f'));

%% Fields-of-view
% for now, fovs are symmetric, so just take one fov col
% Extract fov from aviSet (more reliable than notes)
fovs = zeros(size(vid_nums));
for ii=1:numel(vid_nums)
    for jj=1:numel(aviSets)
        if strcmp(vid_nums{ii}, aviSets(jj).num)
            fovs(ii) = aviSets(jj).fov;
            break;
        end
    end
end
% fovc = strcmpi(loc_head, 'FOV (°)');
% fovs = loc_body(:, fovc);
% fovs = copyDown(fovs);
% fovs = cell2mat(fovs);

%% Put data in structure
loc_data.vidnums = vid_nums;
loc_data.coords = coords;
loc_data.fovs = fovs;
loc_data.eyes = eyes;


end

