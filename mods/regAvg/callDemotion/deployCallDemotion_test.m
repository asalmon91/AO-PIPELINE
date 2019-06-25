%% Deploy callDemotion
py_path = 'E:\Code\AO\AO-PIPE\mods\callDemotion';
dmb_py_fname = 'createDmb.py';
dmp_py_fname = 'callDemotion.py';
% addpath(py_path);
% addpath('E:\Code\AO\AO-PIPE\lib\AVI');

% test video
cal_path    = 'E:\Code\AO\AO-PIPE\mods\NEST\dev\results\1-ctrl\JC_0200-20180308-OD\Calibration';
cal_fname   = 'desinusoid_matrix_790nm_1p0_deg_118p1_lpmm_fringe_15p018_pix.mat';
vid_path    = 'E:\Code\AO\AO-PIPE\mods\NEST\dev\results\1-ctrl\JC_0200-20180308-OD\Raw';
vid_fname   = 'JC_0200_790nm_OD_confocal_0011.avi';

% Get dimensions w/o reading video
m = load(fullfile(vid_path, strrep(vid_fname, '.avi', '.mat')));
frame_ht = m.optical_scanners_settings.visible_lines_in_frame;
frame_wd = m.optical_scanners_settings.n_pixels_per_line;
n_frames = m.image_acquisition_settings.n_frames_to_record;

% Test parameters
ref_frame = 1;
lps = 42;
lbss = 6;

cmd_prompt = sprintf(horzcat(...
    ... % Formatting string for cmd line evaluation
    '! python "%s" ', ... % Script full file name
    '--calPath "%s" --calFname "%s" ', ... % Desinusoid info
    '--vidPath "%s" --vidFname "%s" ', ... % Primary video
    '--refFrame %i ', ... % Reference frame
    '--nRowsRaw %i --nColsRaw %i --vidNFrames %i ', ... % Video info
    '--lps %i --lbss %i --nccThr %1.2f ', ... % Strip reg params
    '--ffrMaxFrames %i --srMaxFrames %i ', ... % N frames to register
    '--ffrMinFrames %i --srMinFrames %i '), ...% Min overlap for cropping
    ... % Input
    fullfile(py_path, dmb_py_fname), ... % Script full file name
    cal_path, cal_fname, ... % Desinusoid info
    vid_path, vid_fname, ... % Primary video
    ref_frame, ... % Reference frame
    frame_ht, frame_wd, n_frames, ... % Video info
    lps, lbss, 0.85, ... % Strip reg params
    50, 50, ... % N frames to register
    2, 2); % Min overlap for cropping

%% Send to OS
eval(cmd_prompt)

%% Send .dmb to DeMotion
% Predict filename
[~,vid_name,~] = fileparts(vid_fname);
dmb_fname = sprintf('%s_ref_%i_lps_%i_lbss_%i.dmb', ...
    vid_name, ref_frame, lps, lbss);

% Build string to send to cmd line
cmd_prompt = sprintf('! python "%s" -p %s -n %s', ...
    fullfile(py_path, dmp_py_fname), ... % Script full file name
    vid_path, dmb_fname); % path, name

%% Send to OS
eval(cmd_prompt)
