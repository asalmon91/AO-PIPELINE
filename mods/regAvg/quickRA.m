function this_vidset = quickRA(ld, paths, this_dsin, opts)
%quickRA is a quick registration and averaging method for AOSLO images
%   These will be subject to distortion from eye motion, so these are not
%   meant to be used for measurement. This is just to get an idea of the
%   coverage of retinal area

%% Get current vidset for processing
this_vidset = ld.vid.vid_set(ld.vid.current_idx);
this_vidset.processing = true;
this_vidset.t_proc_start = clock;

%% Get primary and secondary modality information
% todo: importantly, if the scheme we're going with is to not generate
% split and avg during the live loop, then we can't use either as a
% primary. In areas of weak confocal signal, this might be a deal-breaker,
% but it might also be possible to use direct or reflect as a primary. Not
% sure it's ever been tried. For now, just use confocal. Make sure to
% confer flexibility to use different wavelengths of confocal
fnames = this_vidset.getAllFnames();
primary_mod = contains(fnames, 'confocal');
primary_wavelength = [this_vidset.vids.wavelength]' == opts.lambda_order(1);
prime_fname = fnames{primary_mod & primary_wavelength};
sec_fnames = fnames(~(primary_mod & primary_wavelength));

%% Read primary sequence
vid = single(gpuArray(fn_read_AVI(fullfile(paths.raw, prime_fname))));
this_vidset.t_proc_read = clock;

%% Desinusoid
%todo: Make function apply dsin
vid = desinusoidVideo(vid, this_dsin.mat);
% dsin_vid = gpuArray(zeros(size(vid,1), size(this_dsin.mat, 1), ...
%     size(vid, 3), 'single'));
% for ii=1:size(vid, 3)
%     dsin_vid(:,:,ii) = vid(:,:,ii) * this_dsin.mat';
% end
% vid = dsin_vid; clear dsin_vid;
this_vidset.t_proc_dsind = clock;

%% Select reference frames
% todo: make mfpc an option
frames = arfs(vid, ...
    'pcc_thr', ld.vid.arfs_opts.pcc_thrs(1), ...
    'mfpc', 10);
fids = get_best_n_frames_per_cluster(frames, opts.n_frames);
% Remove clusters with less than the number requested
% todo: functionalize
remove_link = false(size(fids));
for ii=1:numel(fids)
    remove = false(size(fids(ii).cluster));
    for jj=1:numel(fids(ii).cluster)
        remove(jj) = numel(fids(ii).cluster(jj).fids) < opts.n_frames;
    end
    if all(remove)
        remove_link(ii) = true;
    else
        fids(ii).cluster(remove) = [];
    end
end

fids(remove_link) = [];
this_vidset.vids(1).frames = frames;
this_vidset.vids(1).fids = fids;
if isempty(fids)
    this_vidset.processing = false;
    this_vidset.processed = true;
    return;
end

this_vidset.t_proc_arfs = clock;

%% Fast strip-registration
% Current approach: output short videos and use DeMotion as usual
% todo: find a more efficient approach that doesn't require so much
% overhead
if opts.strip_reg
    this_vidset.vids(1).fids = quickSR(vid, this_vidset.vidnum, fids, ...
        this_dsin, paths, prime_fname, sec_fnames);
else

    %% Full-frame register these frames
    [ffr_imgs, fids] = quickFFR(vid, fids);

    % Read secondaries, apply txfms, create other mods, write images
    sec_ffr_imgs = cell(numel(ffr_imgs), 2);
    for ii=1:numel(sec_fnames)
        img_idx = 0;
        vid = single(gpuArray(...
            fn_read_AVI(fullfile(paths.raw, sec_fnames{ii}))));
        dsin_vid = gpuArray(zeros(size(vid,1), size(this_dsin.mat, 1), ...
        size(vid, 3), 'single'));
        for dd=1:size(vid, 3)
            dsin_vid(:,:,dd) = vid(:,:,dd) * this_dsin.mat';
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

    %% Write images
    prime_out_fnames = outputFFR_imgs(ffr_imgs, fids, paths.out, prime_fname);

    split_fname = strrep(prime_fname, 'confocal', 'split_det');
    if ~strcmp(split_fname, prime_fname)
        split_out_fnames = outputFFR_imgs(split_imgs, fids, paths.out, split_fname);
    else
        error('Failed to name split_detector images');
    end

    avg_fname = strrep(prime_fname, 'confocal', 'avg');
    if ~strcmp(avg_fname, prime_fname)
        avg_out_fnames = outputFFR_imgs(avg_imgs, fids, paths.out, avg_fname);
    else
        error('Failed to name split_detector images');
    end

    %% Add output image file names to database
    k=1;
    for ii=1:numel(fids)
        for jj=1:numel(fids(ii).cluster)
            this_vidset.vids(1).fids(ii).cluster(jj).out_fnames = {
                prime_out_fnames{k};
                split_out_fnames{k};
                avg_out_fnames{k}};
            k=k+1;
        end
    end
end
this_vidset.t_proc_ra = clock;

%% Done!
this_vidset.processing = false;
this_vidset.processed = true;
this_vidset.t_proc_end = clock;


