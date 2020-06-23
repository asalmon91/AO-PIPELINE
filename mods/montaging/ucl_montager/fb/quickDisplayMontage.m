function quickDisplayMontage(ld)
%quickDisplayMontage a quick glance at the montage (as one layer)
% todo: enable visualization of other modalities and wavelengths

%% Constants
MIN_N_IMAGES = 2;

%% Shortcuts
montages = ld.mon.montages;

%% Remove montages that are too small
m_sizes = zeros(size(montages));
for ii=1:numel(montages)
    m_sizes(ii) = numel(montages(ii).txfms);
end
montages(m_sizes < MIN_N_IMAGES) = [];
if isempty(montages)
    return;
end

%% Set up figure
n_plots = ceil(sqrt(numel(montages))); % in each dimension (n_plots x n_plots)

%% Convert back to pixels
% Find the minimum FOV used in this montage
min_fov = inf;
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).txfms)
        img_ffname = montages(ii).txfms{jj}{1};
        [~,img_name, img_ext] = fileparts(img_ffname);
        kv = findImageInVidDB(ld, [img_name, img_ext]);
        this_fov = ld.vid.vid_set(kv(1)).fov;
        if this_fov < min_fov
            min_fov = this_fov;
        end
    end
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

%% Start calculating positions
for ii=1:numel(montages)
    %% Get all txfms and add images to canvas
    txfms = zeros(numel(montages(ii).txfms), 4);
    for jj=1:numel(montages(ii).txfms)
        txfms(jj, :) = cell2mat(montages(ii).txfms{jj}(2:end));
        % Get x and y of origin, not center
        txfms(jj, 1) = txfms(jj, 1) - txfms(jj, 4)/2;
        txfms(jj, 2) = txfms(jj, 2) - txfms(jj, 3)/2;
    end
    % Offset all txfms so that min x and y are at origin
    txfms(:, 1:2) = txfms(:, 1:2) - min(txfms(:, 1:2)) + [1, 1];
    % Get size of canvas
    maxx = ceil(max(txfms(:, 1) + txfms(:, 4)));
    maxy = ceil(max(txfms(:, 2) + txfms(:, 3)));
    canvas = zeros(maxy, maxx, 'uint8');
    
    warning off
    for jj=1:numel(montages(ii).txfms)
        % Display progress
        [~, img_name, ~] = fileparts(montages(ii).txfms{jj}{1});
%         fprintf('Reading %s...\n', img_name);
        
        % Read image, resize if necessary
        img = imread(montages(ii).txfms{jj}{1});
        if ~all(size(img) == txfms(jj, 3:4))
            img = imresize(img, txfms(jj, 3:4), 'bicubic');
        end
        im_size = size(img);
        % Add to canvas
        
        canvas(...
            txfms(jj,2):txfms(jj,2)+im_size(1)-1, ...
            txfms(jj,1):txfms(jj,1)+im_size(2)-1) = img;
    end
    warning on
    
    % Display canvas
    subplot(n_plots, n_plots, ii)
    imshow(canvas);
    drawnow();
end

end

