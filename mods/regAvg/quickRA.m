function [outputArg1,outputArg2] = quickRA(vid_data, cal_data, opts)
%UNTITLED13 Summary of this function goes here
%   Detailed explanation goes here

% Raw path
in_path = '\\141.106.183.144\animal_longterm\Squirrel\__Subjects\DM_154802\AOSLO\2019_08_04_OS\Raw';

% Calibration path
in_cal_path = '\\141.106.183.144\animal_longterm\Squirrel\__Subjects\DM_154802\AOSLO\2019_08_04_OS\Calibration';
in_cal_fname = 'desinusoid_matrix_790nm_2p00_deg_118p1_lpmm_fringe_6p4006_pix.mat';
dsin_data = load(fullfile(in_cal_path, in_cal_fname));
dsin_mat = single(gpuArray(dsin_data.vertical_fringes_desinusoid_matrix));

% Output path
out_path = '\\141.106.183.144\animal_longterm\Squirrel\__Subjects\DM_154802\AOSLO\2019_08_04_OS\Processed\LIVE';
if exist(out_path, 'dir') == 0
    mkdir(out_path)
end

% Use confocal as primary modality for this test
confocal_dir = dir(fullfile(in_path, '*confocal*.avi'));
tic
for zz=1:numel(confocal_dir)
    in_fname = confocal_dir{zz};
    sec_fnames = {...
        strrep(in_fname, 'confocal', 'direct'), ...
        strrep(in_fname, 'confocal', 'reflect')};
    % in_mat_fname = strrep(in_fname, '.avi', '.mat');

    % Read confocal
    vid = fn_read_AVI(fullfile(in_path, in_fname));
    vid = single(gpuArray(vid));

    %todo: Make function apply dsin
    dsin_vid = gpuArray(zeros(size(vid,1), size(dsin_mat, 1), ...
        size(vid, 3), 'single'));
    for ii=1:size(vid, 3)
        dsin_vid(:,:,ii) = vid(:,:,ii) * dsin_mat';
    end
    vid = dsin_vid; clear dsin_vid;

    % Select reference frames
    frames = arfs(vid);
    fids = get_best_n_frames_per_cluster(frames, 5);

    % Full-frame register these frames
    [ffr_imgs, fids] = quickFFR(vid, fids);

    % Write images
    outputFFR_imgs(ffr_imgs, fids, out_path, in_fname);

    % Read secondaries, apply txfms, create other mods, write images
    sec_ffr_imgs = cell(numel(ffr_imgs), 2);
    for ii=1:numel(sec_fnames)
        img_idx = 0;
        vid = single(gpuArray(...
            fn_read_AVI(fullfile(in_path, sec_fnames{ii}))));
        dsin_vid = gpuArray(zeros(size(vid,1), size(dsin_mat, 1), ...
        size(vid, 3), 'single'));
        for dd=1:size(vid, 3)
            dsin_vid(:,:,dd) = vid(:,:,dd) * dsin_mat';
        end
        vid = dsin_vid; clear dsin_vid;

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

    split_fname = strrep(in_fname, 'confocal', 'split_det');
    avg_fname = strrep(in_fname, 'confocal', 'avg');
    outputFFR_imgs(split_imgs, fids, out_path, split_fname);
    outputFFR_imgs(avg_imgs, fids, out_path, avg_fname);
end
toc






