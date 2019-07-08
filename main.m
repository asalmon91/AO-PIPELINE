function main(varargin)
%live_pipe Waits for new videos in root_path and begins processing them
% optional "name, value" pair input arguments include:
%   @root_path: the full path to the directory which contains the "Raw" and
%   "Calibration" folders. If not given, a ui folder browser will be opened
%   @num_workers: the number of workers used in parallel processing. If not
%   given, default is the maximum number of workers available. If
%   num_workers is 1, then a parallel pool will not be used and the process
%   will wait until a video set is finished before starting the next one.

%% Imports
fprintf('Initializing...\n');
addpath(genpath('mods'));
addpath(genpath('lib'));

%% Installation
ini = checkFirstRun();

%% Constants
WAIT = 5; % seconds
% PROFILING = false;
% PRIME_MOD = {'confocal'; 'confocal'; 'split_det'; 'avg'};
% PRIME_LAMBDA = [790; 680; 790; 790];

%% Inputs
[root_path, num_workers] = handle_input(varargin);
[mod_order, lambda_order] = getModLambdaOrder();
[wbf, wbh] = pipe_progress();
set(wbh.root_path_txt, 'string', root_path);


%% Infer file locations
raw_path = guessPath(root_path, 'Raw');
cal_path = guessPath(root_path, 'Calibration');
[date_tag, eye_tag] = getDateAndEye(root_path);
set(wbh.raw_path_txt, 'string', raw_path);
set(wbh.cal_path_txt, 'string', cal_path);

%% Set up parallel pool
do_par = true;
if num_workers > 1
    delete(gcp('nocreate'))
    current_pool = parpool(num_workers, 'IdleTimeout', 120);
else
    do_par = false;
end


%% Get desinusoid information
dsins = [];
while isempty(dsins)
    dsins = createDsin(cal_path);
    
    if isempty(dsins)
        warning('No grid videos found in %s\n', cal_path);
        warning('Files must contain "horz..." and "vert..."\n');
        pause(WAIT);
    end
end
% Update progress
wbh.dsin_uit = updateUIT(wbh.dsin_uit, dsins);

%% Get ARFS information
% todo: make optional
u_mods = unique(mod_order);
search = subdir('pcc_thresholds.txt');
if numel(search) == 1
    pcc_thrs = getPccThr(search.name, u_mods);
else
    warning('PCC thresholds not found for ARFS, using defaults');
    pcc_thrs = [0.02; 0.01; 0.01];
end

%% Look for new videos until done.txt exists in the root_dir
% Set up queues and progress tracking
video_found = false;
proc_queue  = {};
vids_done   = {'-9999'};
vids_start  = {'-9999'};
par_queue   = cell(num_workers, 1);
while ~video_found || ...
        exist(fullfile(root_path, 'done.txt'), 'file') == 0 || ...
        ~isempty(proc_queue) || ...
        any_vids_still_processing(vids_start, vids_done)
    % Wait some time before looking for more videos
    pause(WAIT);
    
    %% Update list of videos
    fprintf('Searching for videos\n');
    aviSets = getAviSets(raw_path);
    if isempty(aviSets)
        continue;
    else
        if ~video_found
            video_found = true;
            sub_id = getID(aviSets(1));
        end
    end
    
    %% Remove currently processing and finished videos from the list
    remove = false(size(aviSets));
    vids_done = getRegAvgDone(raw_path);
    if isempty(vids_done)
        vids_done = {'-9999'};
    end
    for ii=1:numel(aviSets)
        remove(ii) = any(contains(vids_start, aviSets(ii).num));
        remove(ii) = any(contains(vids_done, aviSets(ii).num));
    end
    aviSets(remove) = [];
    
    %% Get additional information for each set
%     aviSets = getMods(aviSets);
%     aviSets = getFOV(raw_path, aviSets);
%     aviSets = getWavelength(aviSets);
%     
    %% Try to create secondaries for all current aviSets without split
    direct_fnames = cell(size(aviSets));
    remove = false(size(aviSets));
    for ii=1:numel(aviSets)
        if any(contains(aviSets(ii).fnames, {'split_det'; 'avg'})) || ...
                ~any(contains(aviSets(ii).fnames, 'direct')) || ...
                ~any(contains(aviSets(ii).fnames, 'reflect'))
            remove(ii) = true;
        else
            direct_fnames{ii} = aviSets(ii).fnames{...
                contains(aviSets(ii).fnames, 'direct')};
        end
    end
    direct_fnames(remove) = [];
    
    % Create split and avg
    par_create_mods(raw_path, direct_fnames, do_par);
    aviSets = updateAviSets(aviSets, raw_path);
    
    % Remove videos that don't need to be processed
    aviSets = filtOutDNP(aviSets, mod_order, lambda_order);
    
    %% Build proc_queue
    for ii=1:numel(aviSets)
        if ~any(contains(proc_queue, aviSets(ii).num)) && ...
                any(contains(aviSets(ii).mods, 'split_det')) && ...
                any(contains(aviSets(ii).mods, 'avg'))
            proc_queue = [proc_queue; {aviSets(ii).num}]; %#ok<*AGROW>
        end
    end
    
    %% Update queues
    [proc_queue, par_queue] = updateQueues(proc_queue, par_queue);
    
    %% Registration and averaging
    for ii=1:numel(par_queue)
            if isempty(par_queue{ii}) || ...
                    any(contains(vids_start, par_queue{ii}))
                if isempty(par_queue{ii})
                    fprintf('Open slot in parallel queue\n');
                else
                    fprintf('Video %s is still processing.\n', ...
                        par_queue{ii});
                end
                continue;
            end
            
            this_aviSet = aviSets(strcmp({aviSets.num}, par_queue{ii}));
            fprintf('Sending video %s for processing\n', this_aviSet.num);
            
            if do_par % parallel processing
                parfeval(current_pool, @regAvg, 0, ini, ...
                    root_path, raw_path, ...
                    this_aviSet, dsins, mod_order, lambda_order, pcc_thrs, true);
            else
                feval(@regAvg, ini, root_path, raw_path, ...
                    this_aviSet, dsins, mod_order, lambda_order, pcc_thrs, true);
            end
            
            % Update list of videos that have been started
            vids_start = [vids_start; par_queue{ii}];
    end
    
    %% Update finished sets
    vids_done = getRegAvgDone(raw_path);
    
    %% Subtract finished from parallel queue
    for ii=1:numel(vids_done)
        if all(cellfun(@isempty, par_queue))
            break;
        end
        vid_done_index = find(contains(par_queue, vids_done{ii}));
        if ~isempty(vid_done_index)
            par_queue{vid_done_index} = '';
        end
    end
    
    %% Update progress window
    wbh.vid_uit = updateUIT(wbh.vid_uit, aviSets, raw_path);
end

%% Recalculate aviSets now that everything's done
aviSets = getAviSets(raw_path);
aviSets = updateAviSets(aviSets, raw_path);
aviSets = filtOutDNP(aviSets, mod_order, lambda_order);

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
[pos_ffname, locs] = fx_fix2am(loc_csv_ffname, loc_type, 'ucl', ...
    dsins, aviSets, sub_id, date_tag, eye_tag);
% Get python 3 path
py3 = getIniPath(ini, 'Python 3.7');
fprintf('Montaging...\n');
deployUCL_AM(py3, am_in_path, pos_ffname{1}, eye_tag, out_path);

%% Montage feedback
% todo: functionalize
jsx_search = dir(fullfile(out_path, '*.jsx'));
montages = parseJSX(fullfile(out_path, jsx_search.name));
quickDisplayMontage(montages);
overwrite = false;

%% Targeted approach
% Figure out which videos are part of the disjoint, determine which
% direction we would need to go to fix it
if numel(montages) > 1
    [reprocess_vid_nums, vid_pairs, montages] = ...
        getReprocessVids(montages, locs);
    % Montages now includes video pairings, amounts, and angles
    
    parfor ii=1:numel(reprocess_vid_nums)
        this_aviSet = aviSets(strcmp({aviSets.num}, reprocess_vid_nums{ii})); %#ok<PFBNS>
        angles = getAngles(this_aviSet.num, montages);
        frame_ids = getArfsFramesAngle(this_aviSet.num, raw_path, angles);
        
        for jj=1:numel(frame_ids)
            [ra_success, msg, tif_fnames] = regAvg(...
                ini, root_path, raw_path, ...
                this_aviSet, dsins, mod_order, lambda_order, ...
                pcc_thrs, overwrite, frame_ids);
            if ~ra_success
                disp(msg);
                continue;
            end
            trim_emr_edges(img_path, tif_fnames);
        end
    end
    
    % Set up mini-montages
    disjoint_fixed = false(size(montages));
    disjoint_fixed(1) = true; % 1 is master
    for ii=1:size(vid_pairs, 1)
        % Get image pair
        vid_nums = vid_pairs(ii,:);
        mi = getMontageIndex(vid_nums, montages);
        
        % Figure out which disjoint this would fix
        if all(disjoint_fixed(mi))
            continue;
        end
        
        mm_path = prepMiniMontage(am_in_path, vid_nums);
        deployUCL_AM(py3, mm_path, pos_ffname{1}, eye_tag, mm_path);
        jsx_search = dir(fullfile(mm_path, '*.jsx'));
        mini_montage = parseJSX(fullfile(mm_path, jsx_search.name));
        % Delete that minimontage
        rmdir(mm_path, 's');
        
        if numel(mini_montage) ==1
            disjoint_fixed(mi) = true;
        end
    end
end

% todo: Last ditch effort to connect disjoints, process remaining best
% frames from each video. Try other modalities as well?

if all(disjoint_fixed)
    deployUCL_AM(py3, am_in_path, pos_ffname{1}, eye_tag, out_path);
    jsx_search = dir(fullfile(out_path, '*.jsx'));
    montages = parseJSX(fullfile(out_path, jsx_search.name));
    quickDisplayMontage(montages);
end

%% Montage those guys
ps = getIniPath(ini, 'Adobe Photoshop');
runAllJsx(ps, out_path)
% todo: until I can figure out how to get the transformations from the
% automontager, we'll have the user verify when the montage is done
% building and the layers have been exported

%% Output aligned images for use in whole-montage spacing assessment
aligned_tif_path = uigetdir(out_path, ...
    'Select directory containing aligned images');
fx_montage_dft_analysis(aligned_tif_path, mod_order{1}, lambda_order(1), do_par);

%% Done
% Any final reports could go here
close(wbf);

%% Output profile
% if PROFILING
%     ts = datestr(datetime('now'), 'yyyymmddHHMMss');
%     out_fname = sprintf('pipe-profile-%s.xlsx', ts);
%     
%     prof_head = {'dsin', 'mods', 'reg', 'am calc', 'am disp'};
%     prof_body = {dsin_time, mod_time, reg_avg_time, ...
%         ucl_am_time, ucl_disp_time};
%     
%     xlswrite(fullfile(root_path, out_fname), [prof_head; prof_body]);
% end


end

function [root_path, num_workers] = handle_input(usr_input)

%% Defaults
root_path = '';
num_workers = 1;

% Get maximum number of workers
this_pc_cluster = parcluster('local');
max_n_workers = this_pc_cluster.NumWorkers;

%% Create input parser object
ip = inputParser;
ip.FunctionName = mfilename;

%% Input validation fxs
isValidPath = @(x) ischar(x) && (exist(x, 'dir') ~= 0);
isValidNumWorkers = @(x) isnumeric(x) && isscalar(x) && ...
    x >= 1 && x <= max_n_workers;

%% Optional input parameters
% todo: support batch by allowing cell arrays
opt_params = {...
    'root_path',        '',             isValidPath;
    'num_workers',      max_n_workers,	isValidNumWorkers};

% Add to parser
for ii=1:size(opt_params, 1)
    addParameter(ip, ...
        opt_params{ii, 1}, ...  % name
        opt_params{ii, 2}, ...  % default
        opt_params{ii, 3});     % validation fx
end

%% Parse optional inputs
parse(ip, usr_input{:});

%% Unpack parser
input_fields = fieldnames(ip.Results);
for ii=1:numel(input_fields)
    eval(sprintf('%s = getfield(ip.Results, ''%s'');', ...
        input_fields{ii}, input_fields{ii}));
end

%% Get user input if not directly input
if isempty(root_path)
    root_path = uigetdir('.', ...
        'Select directory containing "Raw" and "Calibration" folders');
    if isnumeric(root_path)
        return;
    end
end

end
