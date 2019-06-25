%% Profile par_create_mods
% Ensure parallel pool is shut down prior to profiling

%% Import
addpath(genpath('E:\Code\AO\AO-PIPE\mods\retro-create-mod'));

in_path = uigetdir('.', ...
    'Select test directory with direct and reflect .avi''s');
direct_dir = dir(fullfile(in_path, '*_direct_*.avi'));
direct_fnames = {direct_dir.name}';

%% Run in parallel
do_par = true;
tic
par_create_mods(in_path, direct_fnames, do_par);
t_par_tot = toc;

%% Delete all split and avg videos
split_dir = dir(fullfile(in_path, '*_split_det_*.avi'));
avg_dir = dir(fullfile(in_path, '*_avg_*.avi'));
split_fnames = {split_dir.name}';
avg_fnames = {avg_dir.name}';
rem_fnames = [split_fnames; avg_fnames];
for ii=1:numel(rem_fnames)
    delete(fullfile(in_path, rem_fnames{ii}));
end

%% Run in serial
do_par = false;
tic
par_create_mods(in_path, direct_fnames, do_par);
t_ser_tot = toc;

%% Calculate proc time per video
proc_time_par = t_par_tot/numel(direct_fnames);
proc_time_ser = t_ser_tot/numel(direct_fnames);

%% Output
out_path = 'output';
if exist(out_path, 'dir') == 0
    mkdir(out_path)
end

ts = datestr(datetime('now'), 'yyyymmddHHMMss');
out_fname = sprintf('%s-profile.xlsx', ts);
xlswrite(fullfile(out_path, out_fname), ...
    [{'parallel', 'serial'}; {proc_time_par, proc_time_ser}]);



