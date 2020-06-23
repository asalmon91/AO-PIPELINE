%% Determine primary modality
clear all %#ok<CLALL>

%% Import
addpath(genpath('.\lib'));
addpath('..\..\lib\AVI');
addpath(genpath('E:\Code\AO\gl\ARFS')); % todo: make relative

%% Video and desinusoid matrix
%% Healthy fovea test image
avi_path = '\\AOIP_0_999\Repo_500_999\JC_0616\AO_2_2_SLO\2017_12_22_OD\Raw';
split_fname = 'JC_0616_790nm_OD_split_det_0054.avi';
cal_path = '\\AOIP_0_999\Repo_500_999\JC_0616\AO_2_2_SLO\2017_12_22_OD\Calibration';
cal_fname = 'desinusoid_matrix_790nm_1p00_deg_118p1_lpmm_fringe_14p981_pix.mat';
%% Vessel test image
% avi_path = '\\AOIP_10200_\Repo_10200_\JC_10220\AO_2_2_SLO\2017_03_30_OD\Raw';
% avi_fname = 'JC_10220_790nm_OD_confocal_0085.avi';
% cal_path = '\\AOIP_10200_\Repo_10200_\JC_10220\AO_2_2_SLO\2017_03_30_OD\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_1p5_deg_118p1_lpmm_fringe_9p9159_pix.mat';
%% Squirrel ONH test image
% avi_path = '\\purgatory\animal_longterm\Squirrel\__Subjects\DM_160303\AOSLO\2017_01_31_OS\Raw';
% split_fname = 'DM_160303_790nm_OS_split_det_0001.avi';
% cal_path = '\\purgatory\animal_longterm\Squirrel\__Subjects\DM_160303\AOSLO\2017_01_31_OS\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_2p00_deg_118p1_lpmm_fringe_5p9698_pix.mat';
%% ACHM fovea
% avi_path = '\\AOIP_1000_9999\Repo_1000_9999\Move to 19370\ACHM-001-PCI-009\AO_2_2_SLO\2015_07_23_OD\Raw';
% split_fname = 'JC_1208_790nm_OD_split_det_0001.avi';
% cal_path = '\\AOIP_1000_9999\Repo_1000_9999\Move to 19370\ACHM-001-PCI-009\AO_2_2_SLO\2015_07_23_OD\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_1p75_deg_118p1_lpmm_fringe_8p553_pix.mat';

confocal_fname = strrep(split_fname, 'split_det', 'confocal');

%% Waitbar
wb = waitbar(0, sprintf('Reading %s...', split_fname));
wb.Children.Title.Interpreter = 'none';

%% Read and desinusoid video
split_avi = fn_read_AVI(fullfile(avi_path, split_fname), wb);
cal = load(fullfile(cal_path, cal_fname));
% Pre-allocate desinusoided video
d_avi = zeros(...
    size(split_avi, 1), ...
    size(cal.vertical_fringes_desinusoid_matrix, 1), ...
    size(split_avi, 3));
for ii=1:size(split_avi, 3)
    d_avi(:,:,ii) = im2double(split_avi(:,:,ii)) * ...
        cal.vertical_fringes_desinusoid_matrix';
    waitbar(ii/size(split_avi,3), wb, 'Desinusoiding');
end
% avi = single(d_avi);
split_avi = d_avi;
% clear d_avi;

%% Read and desinusoid video
confocal_avi = fn_read_AVI(fullfile(avi_path, confocal_fname), wb);
% Pre-allocate desinusoided video
d_avi = zeros(...
    size(confocal_avi, 1), ...
    size(cal.vertical_fringes_desinusoid_matrix, 1), ...
    size(confocal_avi, 3));
for ii=1:size(confocal_avi, 3)
    d_avi(:,:,ii) = im2double(confocal_avi(:,:,ii)) * ...
        cal.vertical_fringes_desinusoid_matrix';
    waitbar(ii/size(split_avi,3), wb, 'Desinusoiding');
end
% avi = single(d_avi);
confocal_avi = d_avi;
clear d_avi;

%% SNR
% confocal
tic
% What about the log of the confocal?
log_confocal_avi = uint8(confocal_avi.*255);
log_confocal_avi = log10(double(log_confocal_avi)+1);
log_confocal_avi = log_confocal_avi - min(log_confocal_avi(:));
log_confocal_avi = log_confocal_avi./max(log_confocal_avi(:));


log_confocal_snr = zeros(size(log_confocal_avi, 3), 1);
for ii=1:size(log_confocal_avi,3)
    img = log_confocal_avi(:,:,ii);
    log_confocal_snr(ii) = 10*log10(mean(img(:))/std(img(:)));
end

% contrast stretched split
split_avi = split_avi-min(split_avi(:));
split_avi = split_avi./max(split_avi(:));

split_snr = zeros(size(split_avi, 3), 1);
for ii=1:size(split_avi,3)
    img = split_avi(:,:,ii);
    split_snr(ii) = 10*log10(mean(img(:))/std(img(:)));
end
toc

figure;
subplot(2,1,1);
imshowpair(log_confocal_avi(:,:,1), split_avi(:,:,1), 'montage');
title('log_{10}(confocal) v. split');

subplot(4,1,3)
hist_edges = linspace(0,1,50);
histogram(log_confocal_avi(:,:,1), hist_edges);
hold on;
histogram(split_avi(:,:,1), hist_edges);
hold off
legend({'log confocal','split'},'location','northeastoutside');
xlabel('Intensity (AU)');
ylabel('# Pixels');

% figure;
hist_edges = linspace(...
    min([log_confocal_snr; split_snr]), ...
    max([log_confocal_snr; split_snr]), size(split_avi,3)/4);
subplot(4,1,4);
histogram(log_confocal_snr, hist_edges);
hold on;
histogram(split_snr, hist_edges);
hold off;
legend({'log confocal','split'},'location','northeastoutside');
xlabel('SNR (dB)');
ylabel('# Frames');


