function live_data = ao_pipe(varargin)
%live_pipe Waits for new videos in root_path and begins processing them
% optional "name, value" pair input arguments include:
%   @root_path: the full path to the directory which contains the "Raw" and
%   "Calibration" folders. If not given, a ui folder browser will be opened
%   @num_workers: the number of workers used in parallel processing. If not
%   given, default is the maximum number of workers available. If
%   num_workers is 1, then a parallel pool will not be used and the process
%   will wait until a video set is finished before starting the next one.
%   @pipe_gui is a pipe_progress_App object that contains settings and user
%   preferences necessary for running, as well as several tables for
%   reporting progress

%% Imports
% fprintf('Initializing...\n');
addpath(genpath('classes'), genpath('mods'), genpath('lib'));

%% Installation
% ini = checkFirstRun();

%% Inputs & system settings
[root_path, num_workers, gui] = handle_input(varargin);

%% Handle paths
paths = initPaths(root_path);
% Create output path
if ~isfield(paths, 'out') || isempty(paths.out)
    paths.out = fullfile(paths.pro, 'LIVE');
    if exist(paths.out, 'dir') == 0
        mkdir(paths.out)
    end
end

%% Update LIVE state and options
[live_data, sys_opts] = load_live_session(paths.root);
[live_data.date, live_data.eye] = getDateAndEye(paths.root);
if isempty(sys_opts) && exist('gui', 'var') ~= 0 && ~isempty(gui)
    % todo: Should we make a function that parses gui data to sys_opts?
    sys_opts.lpmm           = gui.grid_freq.Value/25.4; % lines per mm spacing in grids
    sys_opts.me_f_mm        = gui.grid_focal.Value; % model eye focal length (mm)
    sys_opts.strip_reg      = gui.sr_live_cb.Value;
    sys_opts.n_frames       = gui.n_frames_live_txt.Value; % # frames to average
    sys_opts.mod_order      = gui.in_mods_uit.Data(:,1)';
    sys_opts.lambda_order   = cell2mat(cellfun(@str2double, ...
        gui.in_mods_uit.Data(:,2)', 'uniformoutput', false));
end
live_data = updateLIVE(paths, live_data, sys_opts, gui);

%% Update all progress
% in case it was interrupted
update_pipe_progress(live_data, paths, 'cal', gui);
update_pipe_progress(live_data, paths, 'vid', gui);
update_pipe_progress(live_data, paths, 'mon', gui);

%% Get ARFS information
if ~isfield(live_data.vid, 'arfs_opts') || isempty(live_data.vid.arfs_opts)
    search = subdir('pcc_thresholds.txt');
    if numel(search) == 1
        live_data.vid.arfs_opts.pcc_thrs = ...
            single(getPccThr(search.name, sys_opts.mod_order));
    else
        warning('PCC thresholds not found for ARFS, using defaults');
        live_data.vid.arfs_opts.pcc_thrs = ones(size(sys_opts.mod_order)).*0.01;
    end
end

%% Set up montaging
live_data.mon.opts.mods = gui.mod_order_uit.Data(:,1)';
live_data.mon.opts.min_overlap = 0.25; % minimum proportion of overlap
% todo: decide if min_overlap should be a setting; this is just for
% feedback, so it's probably fine to hard-code
mon_app = montage_display_App(gui.mod_order_uit.Data);

%% Set up parallel pool
if num_workers > 1 && exist('parfor', 'builtin') ~= 0
    cpool = gcp('nocreate');
    if isempty(cpool) || ~cpool.Connected || cpool.NumWorkers ~= num_workers
        delete(gcp('nocreate'))
        cpool = parpool(num_workers, 'IdleTimeout', 120);
    end
end

%% Set up queues
[pff_cal, ~, pff_vid, ~, pff_mon, ~] = initQueues();
% todo: figure out how to allow multiple threads for videos, at that point,
% the queue/afterEach/send procedure may be useful
% afterEach(q_c, @(x) update_pipe_progress(x, paths, 'cal', gui));
% afterEach(q_v, @(x) update_pipe_progress(x, paths, 'vid', gui));
% afterEach(q_m, @(x) update_pipe_progress(x, paths, 'mon', gui));

%% LIVE LOOP
while ~live_data.done && gui.run_live
    %% Calibration Loop
    [live_data, pff_cal] = calibrate_LIVE(...
        live_data, paths, pff_cal, cpool, gui);
    
    %% Registration/Averaging
    [live_data, pff_vid] = ra_LIVE(...
        live_data, paths, sys_opts, pff_vid, cpool, gui);
    
    %% Montaging
    [live_data, pff_mon, paths] = montage_LIVE(...
        live_data, paths, sys_opts, pff_mon, cpool, gui);
    
    %% Update live database
    live_data = updateLIVE(paths, live_data, sys_opts, gui, mon_app);
    if ~isvalid(gui) || gui.quitting
        return;
    end
    
    %% Update GUI
    uiwait(gui.fig, 1)
end

% =========================================================================
% END OF LIVE PIPELINE
% =========================================================================

%% Check FULL preference
if ~gui.start_full
    return;
end

%% FULL LOOP
clear live_data;

%% Set up a new parallel pool (supercluster if possible)
% addpath(fullfile(matlabroot, 'toolbox', 'local'));

%% Set up queues for sending updates in a parfor
[pff, q] = initQueues();

for ii=1:numel(gui.root_path_list)
    %% Init paths
    paths = initPaths(gui.root_path_list{ii});
    paths.out = fullfile(paths.pro, 'FULL');
    
    %% Load live data if it exists
    [pipe_data, opts] = load_live_session(paths.root);
    pipe_data.filename = 'AO_PIPE_FULL.mat';
    % Update options
    opts.mod_order      = gui.mod_order_uit.Data(:,1)';
    opts.lambda_order   = cell2mat(cellfun(@str2double, ...
        gui.mod_order_uit.Data(:,2)', 'uniformoutput', false));
    save(fullfile(paths.root, db.filename), 'pipe_data', 'opts')
    
    % Get arfs parameters
    search = subdir('pcc_thresholds.txt');
    if numel(search) == 1
        opts.pcc_thrs = ...
            single(getPccThr(search.name, opts.mod_order));
    else
        warning('PCC thresholds not found for ARFS, using defaults');
        opts.pcc_thrs = ones(size(sys_opts.mod_order)).*0.01;
    end

    %% Calibration
    afterEach(q, @(x) update_pipe_progress(pipe_data, paths, 'cal', gui, x))
    pipe_data = calibrate_FULL(pipe_data, paths, opts, q, gui);
    save(fullfile(paths.root, db.filename), 'pipe_data')
    uiwait(gui.fig, 1);
    
    %% Videos - Secondaries, Registration/Averaging, EMR
    pipe_data = process_vids_FULL(pipe_data, paths, opts, q, gui);
    uiwait(gui.fig, 1);

    %% Montaging
    vl_setup;
    % vl_version verbose
    % Get position file
    paths.mon_out = fullfile(paths.mon, 'FULL');
    if exist(paths.mon_out, 'dir') == 0
        mkdir(paths.mon_out);
    end
    loc_search = find_AO_location_file(paths.root);
    [loc_folder, loc_name, loc_ext] = fileparts(loc_search.name);
    loc_data = processLocFile(loc_folder, [loc_name, loc_ext]);
    [out_ffname, ~, ok] = fx_fix2am(loc_search.name, ...
                    'human', 'penn', pipe_data.cal.dsin, [], ...
                    pipe_data.id, pipe_data.date, pipe_data.eye, paths.mon);
    
    % Call Penn automontager
    txfm_type   = 1; % Rigid
    append      = false;
    featureType = 0; % SIFT
    exportToPS  = false;
    montage_file = AOMosiacAllMultiModal(paths.out, out_ffname{1}, ...
        paths.mon_out, 'multi_modal', opts.mod_order', txfm_type, ...
        append, [], exportToPS, featureType)
    
    %% Analysis
    % Estimate spacing for whole montage, highest density used as 0,0
    % Extract ROIs outward from 0,0
    % Run CNN cone counts on these ROIs
end

end

%     
%     %% Update list of videos
%     fprintf('Searching for videos\n');
%     aviSets = getAviSets(raw_path);
%     if isempty(aviSets)
%         continue;
%     else
%         if ~video_found
%             video_found = true;
%             sub_id = getID(aviSets(1));
%         end
%     end
%     
%     %% Remove currently processing and finished videos from the list
%     remove = false(size(aviSets));
%     vids_done = getRegAvgDone(raw_path);
%     if isempty(vids_done)
%         vids_done = {'-9999'};
%     end
%     for ii=1:numel(aviSets)
%         remove(ii) = any(contains(vids_start, aviSets(ii).num));
%         remove(ii) = any(contains(vids_done, aviSets(ii).num));
%     end
%     aviSets(remove) = [];
%     
%     %% Get additional information for each set
% %     aviSets = getMods(aviSets);
% %     aviSets = getFOV(raw_path, aviSets);
% %     aviSets = getWavelength(aviSets);
% 
%     aviSets = updateAviSets(aviSets, raw_path);
%     
%     % Remove videos that don't need to be processed
%     aviSets = filtOutDNP(aviSets, mod_order, lambda_order);
%     
%     %% Build proc_queue
%     for ii=1:numel(aviSets)
%         if ~any(contains(proc_queue, aviSets(ii).num)) %&& ...
%                 %any(contains(aviSets(ii).mods, 'split_det')) && ...
%                 %any(contains(aviSets(ii).mods, 'avg'))
%             proc_queue = [proc_queue; {aviSets(ii).num}]; %#ok<*AGROW>
%         end
%     end
%     
%     %% Update queues
%     [proc_queue, par_queue] = updateQueues(proc_queue, par_queue);
%     
%     %% Registration and averaging
%     for ii=1:numel(par_queue)
%             if isempty(par_queue{ii}) || ...
%                     any(contains(vids_start, par_queue{ii}))
%                 if isempty(par_queue{ii})
%                     fprintf('Open slot in parallel queue\n');
%                 else
%                     fprintf('Video %s is still processing.\n', ...
%                         par_queue{ii});
%                 end
%                 continue;
%             end
%             
%             this_aviSet = aviSets(strcmp({aviSets.num}, par_queue{ii}));
%             fprintf('Sending video %s for processing\n', this_aviSet.num);
%             
%             if do_par % parallel processing
%                 parfeval(current_pool, @regAvg, 0, ini, ...
%                     root_path, raw_path, ...
%                     this_aviSet, dsins, mod_order, lambda_order, pcc_thrs, true);
%             else
%                 regAvg(ini, root_path, raw_path, ...
%                     this_aviSet, dsins, mod_order, lambda_order, pcc_thrs, true);
%             end
%             
%             % Update list of videos that have been started
%             vids_start = [vids_start; par_queue{ii}];
%     end
%     
%     %% Update finished sets
%     vids_done = getRegAvgDone(raw_path);
%     
%     %% Subtract finished from parallel queue
%     for ii=1:numel(vids_done)
%         if all(cellfun(@isempty, par_queue))
%             break;
%         end
%         vid_done_index = find(contains(par_queue, vids_done{ii}));
%         if ~isempty(vid_done_index)
%             par_queue{vid_done_index} = '';
%         end
%     end
%     
%     %% Update State
%     live_data = updateLIVE(paths);
%     wbh.vid_uit = updateUIT(wbh.vid_uit, aviSets, raw_path);
%     pause(WAIT);
% end
% % End LIVE LOOP
% 
% %% Recalculate aviSets now that everything's done
% aviSets = getAviSets(raw_path);
% aviSets = updateAviSets(aviSets, raw_path);
% aviSets = filtOutDNP(aviSets, mod_order, lambda_order);
% 
% %% Crop out warped edges after emr
% img_path = fullfile(root_path, 'Processed', 'SR_TIFs', 'Repaired');
% % img_path = trim_emr_edges(img_path);
% 
% %% Automontage
% out_path = fullfile(root_path, 'Montages', 'UCL_AM');
% if exist(out_path, 'dir') == 0
%     mkdir(out_path);
% end
% 
% % Find location file
% [loc_csv_ffname, loc_type] = getLocCSV(raw_path);
% 
% % Generate Automontager input
% [pos_ffname, locs] = fx_fix2am(loc_csv_ffname, loc_type, 'ucl', ...
%     dsins, aviSets, sub_id, date_tag, eye_tag);
% % Get python 3 path
% py3 = getIniPath(ini, 'Python 3.7');
% fprintf('Montaging...\n');
% deployUCL_AM(py3, img_path, pos_ffname{1}, eye_tag, out_path);
% 
% %% Montage feedback
% % todo: functionalize
% jsx_search = dir(fullfile(out_path, '*.jsx'));
% montages = parseJSX(fullfile(out_path, jsx_search.name));
% % quickDisplayMontage(montages);
% overwrite = false;
% 
% %% Targeted approach
% % Figure out which videos are part of the disjoint, determine which
% % direction we would need to go to fix it
% if numel(montages) > 1
%     [reprocess_vid_nums, vid_pairs, montages] = ...
%         getReprocessVids(montages, locs);
%     % Montages now includes video pairings, amounts, and angles
%     % Check to see if it's even possible to connect 
%     all_mi = getMontageIndex(reprocess_vid_nums, montages);
% 
%     for ii=1:numel(reprocess_vid_nums)
%         this_aviSet = aviSets(strcmp({aviSets.num}, reprocess_vid_nums{ii})); %#ok<PFBNS>
%         angles = getAngles(this_aviSet.num, montages);
%         frame_ids = getArfsFramesAngle(this_aviSet.num, raw_path, angles);
% 
%         for jj=1:numel(frame_ids)
%             [ra_success, msg] = regAvg(...
%                 ini, root_path, raw_path, ...
%                 this_aviSet, dsins, mod_order, lambda_order, ...
%                 pcc_thrs, overwrite, frame_ids(jj));
%             if ~ra_success
%                 disp(msg);
%                 continue;
%             end
%         end
%     end
%     
%     % Set up mini-montages
%     fixable_montages = unique(all_mi);
%     if numel(montages) ~= numel(fixable_montages)
%         warning('Cannot fix all breaks in the montage; missing images or insufficient overlap');
%     end
%     
%     % Start tracking which disjoints can be fixed by minimontaging
%     disjoint_fixed = false(size(montages));
%     disjoint_fixed(1) = true; % 1 is master
%     % Just ignore the impossible ones by saying they're fixed
%     disjoint_fixed(~ismember(1:numel(montages), fixable_montages)) = true;
%     
%     for ii=1:size(vid_pairs, 1)
%         % Get image pair
%         vid_nums = vid_pairs(ii,:);
%         mi = getMontageIndex(vid_nums, montages);
%         
%         % Figure out which disjoint this would fix
%         if all(disjoint_fixed(mi))
%             continue;
%         end
%         
%         mm_path = prepMiniMontage(img_path, vid_nums);
%         deployUCL_AM(py3, mm_path, pos_ffname{1}, eye_tag, mm_path);
%         jsx_search = dir(fullfile(mm_path, '*.jsx'));
%         mini_montage = parseJSX(fullfile(mm_path, jsx_search.name));
%         % Delete that minimontage
%         rmdir(mm_path, 's');
%         
%         if numel(mini_montage) == 1
%             disjoint_fixed(mi) = true;
%         end
%     end
% end
% 
% % todo: Last ditch effort to connect disjoints, process remaining best
% % frames from each video. Try other modalities as well?
% 
% if exist('disjoint_fixed', 'var') ~= 0 && any(disjoint_fixed(2:end))
%     deployUCL_AM(py3, img_path, pos_ffname{1}, eye_tag, out_path);
% %     jsx_search = dir(fullfile(out_path, '*.jsx'));
% %     montages = parseJSX(fullfile(out_path, jsx_search.name));
% %     quickDisplayMontage(montages);
% end
% 
% %% Montage those guys
% % ps = getIniPath(ini, 'Adobe Photoshop');
% % runAllJsx(ps, out_path)
% 
% %% Output aligned images for use in whole-montage spacing assessment
% % aligned_tif_path = uigetdir(out_path, ...
% %     'Select directory containing aligned images');
% % fx_montage_dft_analysis(aligned_tif_path, mod_order{1}, lambda_order(1), do_par);
% 
% %% Done
% % Any final reports could go here
% close(wbf);
% 
% %% Output profile
% % if PROFILING
% %     ts = datestr(datetime('now'), 'yyyymmddHHMMss');
% %     out_fname = sprintf('pipe-profile-%s.xlsx', ts);
% %     
% %     prof_head = {'dsin', 'mods', 'reg', 'am calc', 'am disp'};
% %     prof_body = {dsin_time, mod_time, reg_avg_time, ...
% %         ucl_am_time, ucl_disp_time};
% %     
% %     xlswrite(fullfile(root_path, out_fname), [prof_head; prof_body]);
% % end
% 
% 
% end


function [root_path, num_workers, pipe_gui] = handle_input(usr_input)

%% Defaults
root_path = '';
num_workers = 1;
pipe_gui = [];

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
isValidGui = @(x) isa(x, 'pipe_progress_App');

%% Optional input parameters
opt_params = {...
    'root_path',        '',             isValidPath;
    'num_workers',      max_n_workers,	isValidNumWorkers;
    'pipe_gui',         [],             isValidGui};

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
