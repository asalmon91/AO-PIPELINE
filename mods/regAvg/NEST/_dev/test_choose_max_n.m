%% Test dataset
img_path = 'E:\Code\AO\AO-PIPE\mods\NEST\dev\results-20190405102515\1-ctrl\JC_0616-20171222-OD\Processed\SR_TIFs';
img_srch = '*_confocal_*.tif';
img_dir = dir(fullfile(img_path, img_srch));

%% Get n's from filenames
tif_fnames = {img_dir.name}';
ns = zeros(size(tif_fnames));
for ii=1:numel(tif_fnames)
    name_parts = strsplit(tif_fnames{ii}, '_');
    ns(ii) = str2double(name_parts{find(strcmp(name_parts, 'n')) +1});
end
% Get max n and use as template for snr measurements
[~,I] = max(ns);
max_n_tif_fname = tif_fnames{I};
max_n_img = imread(fullfile(img_path, max_n_tif_fname));

%% Preallocate measurement arrays
areas   = zeros(size(ns));
snrs    = areas;
%% Read images, measure area and snr relative to max # frames
for ii=1:numel(ns)
    img_ffname = fullfile(img_path, tif_fnames{ii});
    
    % Read, measure area and snr
    img         = imread(img_ffname);
    areas(ii)   = numel(img);
    
    % To measure snr, images must be aligned and cropped to a common area
    ncc = getNCC(img, max_n_img);
    ncc_mask = zeros(size(ncc));
    ncc_mask(...
        round(size(ncc,1)/4):end-round(size(ncc,1)/4), ...
        round(size(ncc,2)/4):end-round(size(ncc,2)/4)) = 1;
    ncc = ncc.*ncc_mask;
    [rr, cc] = find(ncc == max(ncc(:)));
    dy = rr - size(img,1);
    dx = cc - size(img,2);
    % Get boundaries
    miny = [1+dy, 1];
    maxy = [size(img,1)+dy, size(max_n_img,1)];
    minx = [1+dx, 1];
    maxx = [size(img,2)+dx, size(max_n_img,2)];
    % Shift so min is 1
    shift_y = min(miny);
    shift_x = min(minx);
    miny = miny - shift_y + 1;
    maxy = maxy - shift_y + 1;
    minx = minx - shift_x + 1;
    maxx = maxx - shift_x + 1;
    % Construct canvas
    canvas = zeros(max(maxy), max(maxx), 2, 'uint8');
    imgs = {img, max_n_img};
    for jj=1:numel(imgs)
        canvas(miny(jj):maxy(jj), minx(jj):maxx(jj), jj) = imgs{jj};
    end
    % Crop to common area
    crop_canvas = canvas(max(miny):min(maxy), max(minx):min(maxx), :);
    
    % Measure SNR relative to max n image
    snrs(ii) = psnr(crop_canvas(:,:,1), crop_canvas(:,:,2));
end



% Sort by n
% [sort_ns, I] = sort(ns);
% sort_areas = areas(I);
% sort_snrs = snrs(I);

figure;
subplot(2,1,1);
scatter(ns, areas, 'k');
set(gca, 'tickdir', 'out');
xlabel('# Frames');
ylabel('# Pixels');

subplot(2,1,2);
scatter(ns, snrs, 'k')
% Find largest non-infinite SNR to limit y-axis
set(gca, 'tickdir', 'out');
ylim = [0, max(snrs(snrs~=Inf))];
xlabel('# Frames');
ylabel('SNR (dB)');





