%% AOSLO PIPE Skeleton
% Created - 2019.04.16 - Alex Salmon - asalmon@mcw.edu

%% Imports
addpath(genpath('mods'));
addpath(genpath('lib'));

%% Constants
PRIME_MOD = {'confocal'; 'confocal'; 'split_det'; 'avg'};
PRIME_LAMBDA = [790; 680; 790; 790];
PROFILING = true;

%% Get directory
root_path = uigetdir('.', ...
    'Select directory with "Raw" & "Calibration" folders');

%% Infer file locations
raw_path = guessPath(root_path, 'Raw');
cal_path = guessPath(root_path, 'Calibration');
[date_tag, eye_tag] = getDateAndEye(root_path);

%% Create desinusoid files
if PROFILING; tic; end
dsins = createDsin(cal_path);
if PROFILING; dsin_time = toc/numel(dsins); end

%% Create secondaries
direct_search = dir(fullfile(raw_path, '*_direct_*.avi'));
direct_fnames = {direct_search.name}';
if PROFILING; tic; end
[success, errs] = par_create_mods(raw_path, direct_fnames);
if PROFILING; mod_time = toc/numel(direct_fnames); end

%% Collect videos and properties
% todo: make aoslo_vid a class
% todo: make aoslo_set a class
% aviSets = getAviSets(raw_path);
% aviSets = getWavelength(aviSets);
% aviSets = getModalities(aviSets);

% todo: begin feedback loop which tries other modalities
%% temporary collection of videos until classes are made
aviSets = getAviSets(raw_path);
aviSets = getFOV(raw_path, aviSets);
aviSets = getWavelength(aviSets);
aviSets = getMods(aviSets);
aviSets = filtOutDNP(aviSets, PRIME_MOD, PRIME_LAMBDA);
sub_id  = getID(aviSets(1));

%% Register and Average Videos
if PROFILING; tic; end
[ra_status, ra_errs] = par_regAvg(root_path, raw_path, cal_path, ...
    aviSets, dsins, PRIME_MOD, PRIME_LAMBDA);
if PROFILING; reg_avg_time = toc/numel(aviSets); end

%% Crop out warped edges after emr
img_path = fullfile(root_path, 'Processed', 'SR_TIFs', 'Repaired');
am_in_path = trim_emr_edges(img_path);

%% Automontage
out_path = fullfile(root_path, 'Montages', 'UCL_AM');
if exist(out_path, 'dir') == 0
    mkdir(out_path);
end

% Find location file
[loc_csv_ffname, loc_type] = getLocCSV(raw_path);

% Generate Automontager input
pos_ffname = fx_fix2am(loc_csv_ffname, loc_type, 'ucl', ...
    dsins, aviSets, sub_id, date_tag, eye_tag);

if PROFILING; tic; end
deployUCL_AM(am_in_path, pos_ffname{1}, eye_tag, out_path);
if PROFILING; ucl_am_time = toc/numel(aviSets); end

%% Montage feedback
% todo: get transforms from one of the automontagers. If any breaks, try
% the other reference frames by loading the arfs.mat files. Could check for
% any predicted to help close the gap. Right now I have it so that it stops
% registering and averaging after the first successful image is produced
% per video, as opposed to trying the best reference frame from each
% cluster

% Montage those guys
if PROFILING; tic; end
runAllJsx(out_path)
if PROFILING; ucl_disp_time = toc/numel(aviSets); end

%% Output profile
if PROFILING
    ts = datestr(datetime('now'), 'yyyymmddHHMMss');
    out_fname = sprintf('pipe-profile-%s.xlsx', ts);
    
    prof_head = {'dsin', 'mods', 'reg', 'am calc', 'am disp'};
    prof_body = {dsin_time, mod_time, reg_avg_time, ...
        ucl_am_time, ucl_disp_time};
    
    xlswrite(fullfile(root_path, out_fname), [prof_head; prof_body]);
end


