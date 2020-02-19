function [outputArg1,outputArg2] = outputMontage(ld, paths)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here
%% Constants
BUFF_PX = 30; % buffer pixels between disjoints
DEF_MOD = 'confocal';
% MIN_N_IMAGES = 2;

%% Shortcut
montages = ld.mon.montages;
mods = ld.mon.opts.mods;

%% Prep output
paths.mon_live = fullfile(paths.mon, 'LIVE');
if exist(paths.mon_live, 'dir') == 0
    mkdir(paths.mon_live);
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
% I = bellSort(areas);
% montages = montages(I);
% txfm_cell = txfm_cell(I);

%% Create canvas and start writing
canvas_hw = ceil(canvas_hw);
x_off = 0;
for ii=1:numel(montages)
    xyhw = txfm_cell{ii};
    % Shift so that minx and miny are at origin
    xyhw(:,1:2) = xyhw(:,1:2) - min(xyhw(:,1:2), [], 1) + [1,1];
    
    for jj=1:numel(montages(ii).txfms)
        % Reset the background for each image
        canvas = zeros(canvas_hw(1), canvas_hw(2), 2, 'uint8');
        [img_path, img_name, img_ext] = fileparts(montages(ii).txfms{jj}{1});
        scale = txfm_cell{ii}(jj,3:4);
        
        for mm=1:numel(mods)
            % Pick image
            this_img_name = strrep(img_name, DEF_MOD, mods{mm});
            this_img_ffname = fullfile(img_path, [this_img_name, img_ext]);
            if exist(this_img_ffname, 'file') == 0
                warning('%s does not exist', this_img_name);
                continue;
            end
            
            % Read image, resize
            img = imresize(imread(this_img_ffname), scale, 'bicubic');
            im_size = size(img);

            % Add to canvas
            x_idx = round(xyhw(jj,2):xyhw(jj,2)+im_size(1)-1);
            y_idx = round(xyhw(jj,1)+x_off:xyhw(jj,1)+x_off+im_size(2)-1);
            canvas(x_idx, y_idx, 1) = img;
            canvas(x_idx, y_idx, 2) = 255;
            
            % Modify output name for easy grouping
            saveTif(canvas, paths.mon_live, [this_img_name, img_ext]);
        end
    end
    
    % Get start position of next montage
    minx = min(xyhw(:,1));
    maxx = max(xyhw(:,1) + xyhw(:,4));
    x_off = x_off + abs(maxx-minx) + BUFF_PX;
end

end

