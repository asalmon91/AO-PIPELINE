function gui_handles = displayMontage(ld, gui_handles)
%quickDisplayMontage a quick glance at the montage (as one layer)
% todo: enable visualization of other modalities and wavelengths

%% Inputs
% May need to change this to updating axes if it's contained within a GUI
if exist('gui_handles', 'var') == 0 || isempty(gui_handles)
    [~, gui_handles] = montage_display(ld.mon.opts.mods,1);
end

%% Constants
BUFF_PX = 50; % buffer pixels between disjoints
% MIN_N_IMAGES = 2;

%% Shortcut
montages = ld.mon.montages;

%% Insert code for switching modalities/wavelength here
mods = get(gui_handles.mod_list, 'string');
disp_mod = mods{get(gui_handles.mod_list, 'value')};
% Replace modality string for disp_mod
default_mod = 'confocal'; % todo: if confocal is not collected, this will break.
% this is very rare, so we can leave it for now
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).txfms)
        img_ffname = montages(ii).txfms{jj}{1};
        [img_path, img_name, img_ext] = fileparts(img_ffname);
        out_name = strrep(img_name, default_mod, disp_mod);
        % Overwrite with display name
        % todo: this will crash if the expected modality doesn't exist
        % Not sure if that would ever occur
        montages(ii).txfms{jj}{1} = fullfile(img_path, [out_name, img_ext]);
    end
end

%% Determine scale in pixels/degree
% (input is degrees)
% Find the minimum FOV used in this montage
min_fov = inf;
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).txfms)
        img_ffname = montages(ii).txfms{jj}{1};
        [~,img_name, img_ext] = fileparts(img_ffname);
        kv = findImageInVidDB(ld, [img_name, img_ext]);
        if isempty(kv) % This video hasn't finished updating
            continue;
        end
        this_fov = ld.vid.vid_set(kv(1)).fov;
        if this_fov < min_fov
            min_fov = this_fov;
        end
    end
end
if isinf(min_fov) % Database is not ready
    return;
end

% Get the pixels per degree that was used for this montage
this_ppd = ld.cal.dsin([ld.cal.dsin.fov] == min_fov).ppd;
% overwrite the pixel units with degree values
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).txfms)
        for kk=2:5
            montages(ii).txfms{jj}{kk} = ...
                montages(ii).txfms{jj}{kk}.*this_ppd;
        end
    end
end
% Keep in mind that the montages structure in the live database is still
% has degrees for units, not sure if this matters yet


%% Determine canvas size
% Units are pixels at this point
% Coordinate space is "image"
% Plan for now is just stack disjoints horizontally
% Collect areas for sorting
canvas_hw = [0,0];
txfm_cell = cell(size(montages));
areas = zeros(size(montages));
for ii=1:numel(montages)
    % Get coordinates and sizes as a matrix
    xyhw = cell2mat(cellfun(@(x) [x{2}, x{3}, x{4}, x{5}], ...
        montages(ii).txfms', 'uniformoutput', false));
    % Get coordinates of the origins rather than the centers
    xyhw(:,1:2) = xyhw(:, 1:2) - xyhw(:, 4:-1:3)./2;
    txfm_cell{ii} = xyhw; % Store in a cell array for later use
    minx = min(xyhw(:,1));
    maxx = max(xyhw(:,1) + xyhw(:,4));
    miny = min(xyhw(:,2));
    maxy = max(xyhw(:,2) + xyhw(:,3));
    % Make sure height is large enough to fit tallest montage
    if abs(maxy-miny) > canvas_hw(1)
        canvas_hw(1) = abs(maxy-miny);
    end
    % Expand width by the width of this montage
    canvas_hw(2) = canvas_hw(2) + abs(maxx-minx) + ...
        ((ii~=numel(montages))*BUFF_PX);
    % Measure area of montage
    areas(ii) = abs(maxy-miny) * abs(maxx-minx);
end
% Sort montages so that the largest ones are in the middle
I = bellSort(areas);
montages = montages(I);
txfm_cell = txfm_cell(I);

%% Create canvas and start populating
canvas_hw = ceil(canvas_hw);
canvas = zeros(canvas_hw(1), canvas_hw(2), 'uint8');
x_off = 0;
for ii=1:numel(montages)
    xyhw = txfm_cell{ii};
    % Shift so that minx and miny are at origin
    xyhw(:,1:2) = xyhw(:,1:2) - min(xyhw(:,1:2), [], 1) + [1,1];
    
    for jj=1:numel(montages(ii).txfms)
        % Read image, resize
        img = imresize(imread(montages(ii).txfms{jj}{1}), ...
            txfm_cell{ii}(jj,3:4), 'nearest');
        im_size = size(img);
        % Add to canvas
        
        canvas(...
            round(xyhw(jj,2):xyhw(jj,2)+im_size(1)-1), ...
            round(xyhw(jj,1)+x_off:xyhw(jj,1)+x_off+im_size(2)-1)) = img;
    end
    
    % Get start position of next montage
    minx = min(xyhw(:,1));
    maxx = max(xyhw(:,1) + xyhw(:,4));
    x_off = x_off + abs(maxx-minx) + BUFF_PX;
end

% Display
imshow(canvas, 'border', 'tight', 'parent', gui_handles.montage_ax);
drawnow();

end

function new_I = bellSort(sizes)
% bellSort returns a sorting index so that the largest things are in the
% middle and the smaller things are on the outside
% If you can think of a better way to do this, I'm all ears.

[~,I] = sort(sizes, 'ascend');
new_I       = I;
start_idx   = 1;
end_idx     = numel(I);
for ii=1:numel(I)
    if mod(ii,2)
        new_I(start_idx) = I(ii);
        start_idx = start_idx +1;
    else
        new_I(end_idx) = I(ii);
        end_idx = end_idx -1;
    end
end

end
