%% Minimizing Ambiguity and Strip Size
clear all %#ok<CLALL>

%% Import
addpath(genpath('.\lib'));
addpath('..\..\lib\AVI');
addpath(genpath('E:\Code\AO\gl\ARFS')); % todo: make relative

%% Video and desinusoid matrix
% Fovea test image
avi_path = '\\AOIP_0_999\Repo_500_999\JC_0616\AO_2_2_SLO\2017_12_22_OD\Raw';
avi_fname = 'JC_0616_790nm_OD_confocal_0054.avi';
cal_path = '\\AOIP_0_999\Repo_500_999\JC_0616\AO_2_2_SLO\2017_12_22_OD\Calibration';
cal_fname = 'desinusoid_matrix_790nm_1p00_deg_118p1_lpmm_fringe_14p981_pix.mat';
% Vessel test image
% avi_path = '\\AOIP_10200_\Repo_10200_\JC_10220\AO_2_2_SLO\2017_03_30_OD\Raw';
% avi_fname = 'JC_10220_790nm_OD_confocal_0085.avi';
% cal_path = '\\AOIP_10200_\Repo_10200_\JC_10220\AO_2_2_SLO\2017_03_30_OD\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_1p5_deg_118p1_lpmm_fringe_9p9159_pix.mat';
% Squirrel ONH test image
% avi_path = '\\purgatory\animal_longterm\Squirrel\__Subjects\DM_160303\AOSLO\2017_01_31_OS\Raw';
% avi_fname = 'DM_160303_790nm_OS_split_det_0001.avi';
% cal_path = '\\purgatory\animal_longterm\Squirrel\__Subjects\DM_160303\AOSLO\2017_01_31_OS\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_2p00_deg_118p1_lpmm_fringe_5p9698_pix.mat';
% ACHM fovea
% avi_path = '\\AOIP_1000_9999\Repo_1000_9999\Move to 19370\ACHM-001-PCI-009\AO_2_2_SLO\2015_07_23_OD\Raw';
% avi_fname = 'JC_1208_790nm_OD_split_det_0001.avi';
% cal_path = '\\AOIP_1000_9999\Repo_1000_9999\Move to 19370\ACHM-001-PCI-009\AO_2_2_SLO\2015_07_23_OD\Calibration';
% cal_fname = 'desinusoid_matrix_790nm_1p75_deg_118p1_lpmm_fringe_8p553_pix.mat';

%% Waitbar
wb = waitbar(0, sprintf('Reading %s...', avi_fname));
wb.Children.Title.Interpreter = 'none';

%% Read and desinusoid video
avi = fn_read_AVI(fullfile(avi_path, avi_fname), wb);
cal = load(fullfile(cal_path, cal_fname));
% Pre-allocate desinusoided video
d_avi = zeros(...
    size(avi, 1), ...
    size(cal.vertical_fringes_desinusoid_matrix, 1), ...
    size(avi, 3));
for ii=1:size(avi, 3)
    d_avi(:,:,ii) = im2double(avi(:,:,ii)) * ...
        cal.vertical_fringes_desinusoid_matrix';
    waitbar(ii/size(avi,3), wb, 'Desinusoiding');
end
% avi = single(d_avi);
avi = d_avi;
clear d_avi;
    
%% Get the ARFS best frame
frames = arfs(avi, 'wb', wb);
% [ulid, ~, ic] = unique([frames.link_id]);
ref_frame = [frames([frames.pcc] == max([frames.pcc])).id];
if numel(ref_frame) > 1
    ref_frame = ref_frame(1);
end
img = uint8(avi(:,:,ref_frame).*255);

% NCC cols to ignore
n_cols_ignore = floor(size(img,1)/4);

%% Set up candidate strip sizes
n_candidates = 15;
ss = round(5*exp(.25*(1:n_candidates)));
% ss = unique(round(5*exp(.25*(1:0.5:n_candidates))));
% n_candidates = numel(ss);

%% Measurement arrays
ncc_ss = cell(n_candidates, 1);
% figure;
% imshow(img);
% tic
for ii=1:n_candidates
    
    % Choose template strip based on minimum entropy
    [entropies, start_indices] = stripEntropy(img, ss(ii));
    ub_t = start_indices(entropies == min(entropies));
    if numel(ub_t) > 1
        ub_t = ub_t(1);
    end
    lb_t = ub_t + ss(ii) -1;
    t_strip = img(ub_t:lb_t, :);
    
    % vectors of sample strips
    ub_above = ub_t + ss(ii) : ss(ii) : size(img,1);
    ub_below = flip(ub_t - ss(ii) : -ss(ii) : 1);
    ub_s = [ub_below, ub_above];
    lb_s = ub_s + ss(ii) - 1;
    oob = lb_s > size(img,1);
    ub_s(oob) = [];
    lb_s(oob) = [];
    
    % ncc maxima array
    nccs = zeros(numel(ub_s), 1);
    
    % ncc rows to ignore
    n_rows_ignore = floor(ss(ii)/2);
    
    for jj=1:numel(ub_s)
        % Sample Strip
        s_strip = img(ub_s(jj):lb_s(jj), :);

        % NCC
        ncc = getNCC(t_strip, s_strip);
        ncc = ncc(n_rows_ignore:end-n_rows_ignore, ...
            n_cols_ignore:end-n_cols_ignore);
        nccs(jj) = max(ncc(:));

%         % Display
%         imshow(img);
%         hold on
%         % template strip
%         plot([1, size(img,2), size(img,2), 1], ...
%             [ub_t, ub_t, lb_t, lb_t], '-c')
%         % sample strip
%         plot([1, size(img,2), size(img,2), 1], ...
%             [ub_s(jj), ub_s(jj), lb_s(jj), lb_s(jj)], '-m')
%         hold off
%         legend({'Template', 'Sample'}, 'location', 'northeastoutside');
%         drawnow;
    end
    
    % Compile nccs
    ncc_ss{ii} = nccs;
    
    waitbar(ii/n_candidates, wb, sprintf('Testing ss=%i', ss(ii)));
end
% toc

%% Compile results into one vector and corresponding ss
n_iter = cellfun(@numel, ncc_ss);
n_nccs = sum(n_iter);
all_nccs = zeros(n_nccs, 1);
all_ss = all_nccs;
for ii=1:n_candidates
    if ii==1
        indices = 1:n_iter(1); 
    else
        indices = sum(n_iter(1:ii-1)) +1 : sum(n_iter(1:ii-1)) + n_iter(ii);
    end
	all_nccs(indices) = ncc_ss{ii};
    all_ss(indices) = repmat(ss(ii), n_iter(ii), 1);
end

% figure;
% subplot(131);
% scatter(all_ss, all_nccs, '.k')
% xlabel('Strip size (px)');
% ylabel('NCC');
% set(gca,'tickdir','out');

%% Find minimum uniqueness
max_nccs = zeros(size(ss));
for ii=1:n_candidates
    max_nccs(ii) = max(all_nccs(all_ss == ss(ii)));
end

% figure;
% subplot(132);
% scatter(ss, max_nccs, '.k');
% xlabel('Strip size (px)');
% ylabel('max(NCC)');
% set(gca,'tickdir','out');

%% Parabolic increase in cost scaled by range of autocorrelation
autocorr = getNCC(img,img);
max_corr_diff = range(autocorr(:));
m = max_corr_diff/((size(img,1)/2)^2);
cost_fx = @(x) m.*(x.^2);

%% Apply Cost function
% obj_fx = max_nccs + cost_fx(ss);
obj_fx = all_nccs + cost_fx(all_ss);

% Custom fit, ambiguity tends to follow a sqrt(s) fx and the amount of
% potential motion error we introduce by increasing strip size increases
% linearly with strip size (Cost fx). So we fit to f(s)=as^-.5 + ms
ft = fittype('(a*(x^-.5)+c) + (b*x^2+d)', ...
    'independent', 'x', 'dependent', 'y' );
% ft = fittype( '(a*x^-.5+c) + (b*x+d)', ...
%     'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
% opts.StartPoint = [0, 0.5, 0, 0.5];
% [fx_sqrt_sqr, gof] = fit( ss', obj_fx', ft, opts);
[fx_sqrt_sqr, gof] = fit( all_ss, obj_fx, ft, opts);
% Sample every ss
fx = min(ss):max(ss);
fy = fx_sqrt_sqr(fx);

%% Find strip size that minimizes objective function
ss_min = fx(fy==min(fy));

%% Determine NCC threshold
% qx = min(ss):max(ss);
interp_max_ncc = interp1(ss, max_nccs, fx, 'linear');
ncc_thr = interp_max_ncc(fx==ss_min);

%% Determine number of frames to register
ref_link = frames(ref_frame).link_id;
ref_cluster = frames(ref_frame).cluster;
n_frames = numel(find([frames.link_id] == ref_link & ...
    [frames.cluster] == ref_cluster));

% Plot
figure;
subplot(231);
imshow(img);
title(sprintf('RF: %i', ref_frame));

subplot(232);
surf(autocorr), shading flat;
title(sprintf('range(AC): %1.2f', max_corr_diff));

subplot(234);
scatter(all_ss, all_nccs, '.k');
hold on
scatter(ss, max_nccs, 'rx');
hold off
xlabel('Strip size(px)', 'fontname','arial','fontsize',18);
ylabel('Non-overlapping NCC', 'fontname','arial','fontsize',18);
axis tight square

subplot(235);
plot(fx, cost_fx(fx), '-r');
xlabel('Strip size(px)', 'fontname','arial','fontsize',18);
ylabel('Cost(strip size)', 'fontname','arial','fontsize',18);
axis tight square

subplot(236)
plot(fx,fy,'--m');
hold on;
scatter(all_ss, obj_fx, '.k')
plot([ss_min, ss_min], get(gca, 'ylim'), '--m');
hold off
xlabel('Strip size(px)', 'fontname','arial','fontsize',18);
ylabel('O(S)', 'fontname','arial','fontsize',18);
set(gca,'tickdir','out');
axis tight square
legend({'(ax^{-0.5}+c)+(bx^2+d)', 'Measured', 'Global Min'}, ...
    'location', 'southeast');
suptitle(sprintf('rf: %i, lps: %i, thr: %1.2f, #frames: %i', ...
    ref_frame, ss_min, ncc_thr, n_frames));

% Done
close(wb);

