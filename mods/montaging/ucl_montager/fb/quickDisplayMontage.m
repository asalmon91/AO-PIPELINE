function quickDisplayMontage(montages)
%quickDisplayMontage a quick glance at the montage (as one layer)
% todo: enable visualization of other modalities and wavelengths

%% Constants
MIN_N_IMAGES = 2;

for ii=1:numel(montages)
    %% Skip montages with too few images
    if numel(montages(ii).txfms) < MIN_N_IMAGES
        for jj=1:numel(montages(ii).txfms)
            [~, img_name, ~] = fileparts(montages(ii).txfms{jj}{1});
            fprintf('Montage %i not shown, contains %s\n', ...
                ii, img_name);
        end
        continue;
    end
    
    %% Get names and filter by mod and wavelength
%     all_names = cell(size(montages(ii).txfms));
%     for jj=1:numel(montages(ii).txfms)
%         img_ffname = montages(ii).txfms{jj}{1};
%         [~, img_name, ~] = fileparts(img_ffname);
%         all_names{jj} = img_name;
%     end
%     name_filt = ...
%         contains(all_names, disp_mod) & ...
%         contains(all_names, disp_lambda);
    % todo: the ucl automontager actually only writes down the confocal,
    % and has a function later for switching the confocal tag out for the
    % secondaries. If we want to display other modalities, there will need
    % to be another function here.
    
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
        fprintf('Reading %s...\n', img_name);
        
        % Read image, resize if necessary
        img = imread(montages(ii).txfms{jj}{1});
        if ~all(size(img) == txfms(jj, 3:4))
            img = imresize(img, txfms(jj, 3:4), 'bicubic');
        end
        % Add to canvas
        
        canvas(...
            txfms(jj,2):txfms(jj,2)+txfms(jj,3)-1, ...
            txfms(jj,1):txfms(jj,1)+txfms(jj,4)-1) = img;
    end
    warning on
    
    % Display canvas
    figure;
    imshow(canvas);
end

end

