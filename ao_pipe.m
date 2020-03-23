function live_data = ao_pipe(varargin)
%live_pipe Waits for new videos in root_path and begins processing them
% optional "name, value" pair input arguments include:
%   #root_path: the full path to the directory which contains the "Raw" and
%   "Calibration" folders. If not given, a ui folder browser will be opened
%   #num_workers: the number of workers used in parallel processing. If not
%   given, default is the maximum number of workers available. If
%   num_workers is 1, then a parallel pool will not be used and the process
%   will wait until a video set is finished before starting the next one.
%   #pipe_gui is a pipe_progress_App object that contains settings and user
%   preferences necessary for running, as well as several tables for
%   reporting progress

%% Imports
% fprintf('Initializing...\n');
addpath(genpath('classes'), genpath('mods'), genpath('lib'));

%% Installation
% ini = checkFirstRun();

%% Inputs & system settings
[root_path, num_workers, gui] = handle_input(varargin);

%% Update LIVE state and options
if gui.run_live
    [live_data, sys_opts, paths] = load_previous_session(root_path, 'live');
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

    %% Handle paths
    paths = initPaths(root_path);
    % Create output path
    if ~isfield(paths, 'out') || isempty(paths.out)
        paths.out = fullfile(paths.pro, 'LIVE');
        if exist(paths.out, 'dir') == 0
            mkdir(paths.out)
        end
    end

    %% Update all progress
    % in case it was interrupted
    update_pipe_progress(live_data, paths, 'cal', gui);
    update_pipe_progress(live_data, paths, 'vid', gui);
    update_pipe_progress(live_data, paths, 'mon', gui);

    %% Get ARFS information
    if gui.run_live && ...
            (~isfield(live_data.vid, 'arfs_opts') || ...
            isempty(live_data.vid.arfs_opts))
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
    
    %% Set up queues
    [pff_cal, ~, pff_vid, ~, pff_mon, ~] = initQueues();
    % todo: figure out how to allow multiple threads for videos, at that point,
    % the queue/afterEach/send procedure may be useful
    % afterEach(q_c, @(x) update_pipe_progress(x, paths, 'cal', gui));
    % afterEach(q_v, @(x) update_pipe_progress(x, paths, 'vid', gui));
    % afterEach(q_m, @(x) update_pipe_progress(x, paths, 'mon', gui));
end

%% Set up parallel pool
if num_workers > 1 && exist('parfor', 'builtin') ~= 0
    cpool = gcp('nocreate');
    if isempty(cpool) || ~cpool.Connected || cpool.NumWorkers ~= num_workers
        delete(gcp('nocreate'))
        cpool = parpool(num_workers, 'IdleTimeout', 120);
    end
end

%% LIVE LOOP
while isvalid(gui.fig) && gui.run_live && ~live_data.done
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
    if ~isvalid(gui.fig) || gui.quitting
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

%% Determine GPU status
gpuDevice(1);

%% Set up queues for sending updates in a parfor
[~, q] = initQueues();

%% Run FULL pipe on each dataset in the list
for ii=1:numel(gui.root_path_list)
    %% Init paths
    root_path = gui.root_path_list{ii};
    
    %% Full -> Live -> New
    % Load previous session initializes a new database by default if one
    % doesn't already exist
    [~, opts, paths, pipe_data] = load_previous_session(root_path, 'full');
    if isempty(opts)
        [pipe_data, opts, paths] = load_previous_session(paths.root, 'live');
        pipe_data.filename = 'AO_PIPE_FULL.mat'; % Overwrite
    end
    if isempty(pipe_data.eye) || isempty(pipe_data.date)
        [date_str, eye_str] = getDateAndEye(paths.root);
        pipe_data.date = date_str;
        pipe_data.eye = eye_str;
    end
    
    %% Setup output
    % R/A output
    if ~isfield(paths, 'out') || isempty(paths.out) || exist(paths.out, 'dir') == 0
        paths.out = fullfile(paths.pro, 'FULL');
        if exist(paths.out, 'dir') == 0
            mkdir(paths.out);
        end
    end
    % Montage output
    if ~isfield(paths, 'mon_out') || isempty(paths.mon_out) || exist(paths.mon_out, 'dir') == 0
        paths.mon_out = fullfile(paths.mon, 'FULL');
        if exist(paths.mon_out, 'dir') == 0
            mkdir(paths.mon_out);
        end
    end
    
    %% Update options
    % todo: this might break in batch mode
    % Output modalities must be overwritten
    opts.mod_order = gui.mod_order_uit.Data(:,1)';
    if isempty(opts)
        opts.lambda_order   = cell2mat(cellfun(@str2double, ...
            gui.mod_order_uit.Data(:,2)', 'uniformoutput', false));
        opts.n_frames = gui.n_frames_full_txt.Value;
        opts.lpmm = gui.grid_freq.Value/25.4;
        opts.me_f_mm = gui.grid_focal.Value;
        if ~isfield(opts, 'subject') || isempty(opts.subject)
            opts.subject = gui.subject;
        end
    end
    
    % Get arfs parameters
    search = subdir('pcc_thresholds.txt');
    if numel(search) == 1
        opts.pcc_thrs = ...
            single(getPccThr(search.name, opts.mod_order));
    else
        warning('PCC thresholds not found for ARFS, using defaults');
        opts.pcc_thrs = ones(size(opts.mod_order)).*0.01;
    end
    save(fullfile(paths.root, pipe_data.filename), 'pipe_data', 'opts', 'paths')

    %% Calibration
    pipe_data = calibrate_FULL(pipe_data, paths, opts, q, gui);
    save_full_pipe(pipe_data, opts, paths);
    uiwait(gui.fig, 1);
    
    %% Videos - Secondaries, Registration/Averaging, EMR
    pipe_data = process_vids_FULL(pipe_data, paths, opts, q, gui);
    save_full_pipe(pipe_data, opts, paths);
    uiwait(gui.fig, 1);

    %% Montaging
    pipe_data = montage_FULL(pipe_data, paths, opts);
    save_full_pipe(pipe_data, opts, paths);
    uiwait(gui.fig, 1);
    
    %% Analysis
    [pipe_data, paths] = analysis_FULL(pipe_data, paths, opts);
    save_full_pipe(pipe_data, opts, paths);
    uiwait(gui.fig, 1);
    
    %% REPORT
    
end

end

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
