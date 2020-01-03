function ld = quickRA(paths, ld, opts)
%quickRA is a quick registration and averaging method for AOSLO images
%   These will be subject to distortion from eye motion, so these are not
%   meant to be used in 

% todo: move this determination elsewhere so that quickRA can be used more
% generally
% Find first vidset in live_data that can be processed
ready_vids = find(...
    ~[ld.vid.vid_set.processed] & ...
    ~[ld.vid.vid_set.processing] & ...
    [ld.vid.vid_set.hasCal]);
if isempty(ready_vids)
    return;
else
    this_vidset = ld.vid.vid_set(ready_vids(1));
    ld.vid.vid_set(ready_vids(1)).processing = true;
end

%% Output path
paths.out = fullfile(paths.pro, 'LIVE');
if exist(paths.out, 'dir') == 0
    mkdir(paths.out)
end

% todo: extract mod_order from opts
fnames = this_vidset.getAllFnames();
prime_fname = fnames{contains(fnames, 'confocal')};
sec_fnames = {...
    strrep(prime_fname, 'confocal', 'direct'), ...
    strrep(prime_fname, 'confocal', 'reflect')};

% Read confocal
vid = fn_read_AVI(fullfile(paths.raw, prime_fname));
vid = single(gpuArray(vid));

% Determine appropriate dsin mat to use
cal_fovs = [ld.cal.dsin.fov];
dsin_mat = ld.cal.dsin(this_vidset.fov == cal_fovs).mat;

%todo: Make function apply dsin
dsin_vid = gpuArray(zeros(size(vid,1), size(dsin_mat, 1), ...
    size(vid, 3), 'single'));
for ii=1:size(vid, 3)
    dsin_vid(:,:,ii) = vid(:,:,ii) * dsin_mat';
end
vid = dsin_vid; clear dsin_vid;

% Determine appropriate PCC threshold to use for ARFS
% TODO

% Select reference frames
frames = arfs(vid);
fids = get_best_n_frames_per_cluster(frames, 5);

% Full-frame register these frames
[ffr_imgs, fids] = quickFFR(vid, fids);

% Write images
outputFFR_imgs(ffr_imgs, fids, out, prime_fname);

% Read secondaries, apply txfms, create other mods, write images
sec_ffr_imgs = cell(numel(ffr_imgs), 2);
for ii=1:numel(sec_fnames)
    img_idx = 0;
    vid = single(gpuArray(...
        fn_read_AVI(fullfile(paths.raw, sec_fnames{ii}))));
    dsin_vid = gpuArray(zeros(size(vid,1), size(dsin_mat, 1), ...
    size(vid, 3), 'single'));
    for dd=1:size(vid, 3)
        dsin_vid(:,:,dd) = vid(:,:,dd) * dsin_mat';
    end
    vid = dsin_vid; %clear dsin_vid;

    for jj=1:numel(fids)
        for kk=1:numel(fids(jj).cluster)
            img_idx = img_idx +1;
            regSeq = getRegSeq(vid(:,:,fids(jj).cluster(kk).fids), ...
                fids(jj).cluster(kk).txfms, true);
            sec_ffr_imgs{img_idx, ii} = mean(regSeq, 3);
        end
    end
end

% Combine to create split and avg
split_imgs = ffr_imgs;
avg_imgs = ffr_imgs;
for ii=1:size(sec_ffr_imgs,1)
    img1 = sec_ffr_imgs{ii,1};
    img2 = sec_ffr_imgs{ii,2};

    split_img = contrast_stretch((img1 - img2) ./ (img1 + img2));
    avg_img = contrast_stretch((img1 + img2) ./ 2);
    split_imgs{ii} = split_img;
    avg_imgs{ii} = avg_img;
end

split_fname = strrep(prime_fname, 'confocal', 'split_det');
avg_fname = strrep(prime_fname, 'confocal', 'avg');
outputFFR_imgs(split_imgs, fids, out, split_fname);
outputFFR_imgs(avg_imgs, fids, out, avg_fname);





