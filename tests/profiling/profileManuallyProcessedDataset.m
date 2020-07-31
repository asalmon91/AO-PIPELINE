%% Get profile for manually processed dataset
% Total processing time
% WARNING: this must be run on the original dataset, not a copy.
% Time-created is modified after copying, so numbers will be meaningless

%% Imports
import System.IO.File.GetCreationTime
addpath(genpath('lib'), genpath('mods'), genpath('classes'));

%% Constants
MOD_TAG = 'split_det';

%% Get root path to dataset
root_path = uigetdir('.', 'Select root directory of dataset');
if isnumeric(root_path)
	return;
end

%% Initiate paths
paths = initPaths(root_path);

%% Calibration
% Negligible, skip

%% Secondary modalities
aviSets = getAviSets(paths.raw);
t_secondary = zeros(size(aviSets));
for vid = 1:numel(aviSets)
	% Get secondary video of interest
	v_idx = find(~cell2mat(cellfun(@isempty, strfind(aviSets(vid).fnames, MOD_TAG), 'uniformoutput', false)));
	if isempty(v_idx)
		error('Modality not found for video %i', aviSets(vid).num);
	end
	this_fname = aviSets(vid).fnames{v_idx};
	
	% Get creation time - changes if the file is copied
	d = GetCreationTime(fullfile(paths.raw, this_fname));
	t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
	t_create = days2sec(datenum(t_create));
	
	% Get modified time
	this_vid = dir(fullfile(paths.raw, this_fname));
	t_last_mod = days2sec(this_vid.datenum);
    
    t_secondary(vid) = t_last_mod - t_create;
end

%% ARFS
arfs_data_info = dir(fullfile(paths.raw, '*dmbdata.mat'));
if numel(arfs_data_info) ~= 1
	error('Failed to find 1 arfs data file in %s', paths.raw);
end
load(fullfile(paths.raw, arfs_data_info.name), 'dmb');

% Loop through fov's
t_arfs = zeros(size(aviSets));
dmb_list = {}; % need this for next module; todo: could preallocate for efficiency
k=0;
for fov = 1:numel(dmb)
    template_dmb_fname = dmb(fov).name;
    suffix = template_dmb_fname(strfind(template_dmb_fname, 'lps_') : end);
    
    % Find the timestamp for each .dmb made by arfs
    for vid_idx = 1:numel(dmb(fov).arfs)
        this_vid_fname = dmb(fov).arfs(vid_idx).data.name;
        this_vid_rflist = dmb(fov).arfs(vid_idx).rfList;
        
        t_dmb = zeros(size(this_vid_rflist));
        for rf = 1:numel(this_vid_rflist)
            search_fname = sprintf('%s_ref_%i_%s', ...
                strrep(this_vid_fname, '.avi', ''), this_vid_rflist(rf), suffix);
            search_results = dir(fullfile(paths.raw, search_fname));
            if numel(search_results) ~= 1
                error('Investigate failed search for: %s', search_fname);
            end
            t_dmb(rf) = days2sec(search_results.datenum);
            dmb_list = [dmb_list; {search_fname}]; %#ok<AGROW>
        end
        % todo: if the order matters, match this video to aviSets, until then, just add to next
        % available slot
        k=k+1;
        t_arfs(k) = max(t_dmb); % Choose the last dmb made by arfs
    end
end
t_arfs = diff(sort(t_arfs));
% figure; histogram(t_arfs)

%% DeMotion
dmp_list = strrep(dmb_list, '.dmb', '.dmp');
t_dmp = zeros(size(dmp_list));
for dmp_idx = 1:numel(dmp_list)
    dmp_search = dir(fullfile(paths.raw, dmp_list{dmp_idx}));
    if numel(dmp_search) ~= 1
        error('Investigate failed search for: %s', dmb_list{dmp_idx});
    end
    t_dmp(dmp_idx) = days2sec(dmp_search.datenum);
end
t_dmp = diff(sort(t_dmp));
% figure; histogram(t_dmp)

%% Culling
% Negligible, skip

%% EMR
% Can be a tad slow
% Finding these might be a bit tricky
emr_path_guess = fullfile(paths.mon, 'AM_in', 'Repaired');
if ~exist(emr_path_guess, 'dir')
    emr_path = uigetdir(paths.mon, 'Select folder containing repaired images');
    if isnumeric(emr_path)
        error('Canceled by user');
    end
else
    emr_path = emr_path_guess;
end
emr_search = dir(fullfile(emr_path, '*_repaired.tif'));
if isempty(emr_search)
    error('No repaired images found in %s', emr_path);
end
t_emr = diff(sort(days2sec([emr_search.datenum])))';
% figure; histogram(t_emr)

%% Trim
% Negligible

%% Automontaging
% This one will be really tricky if they don't save the runtime in the data file
% I had to modify the automontager to use the clock feature, now it saves a file called profile.mat
% which stores the processing time in seconds.
mon_profile_guess = fullfile(paths.mon, 'AM_out', 'profile.mat');
if ~exist(mon_profile_guess, 'file')
    [mon_fname, mon_path] = uigetfile('*.mat', 'Select montage profile file');
    if isnumeric(mon_fname)
        error('Canceled by user');
    end
else
    [mon_path, mon_name, mon_ext] = fileparts(mon_profile_guess);
    mon_fname = [mon_name, mon_ext];    
end
load(fullfile(mon_path, mon_fname), 't_automontage');
    
%% Get the number of images montaged
[img_fnames, img_path] = uigetfile('*.tif', 'Select images included in montage', ...
    'multiselect', 'on');

%% Plot results
% Figure defaults
fn = 'arial';
fst = 8;
fsl = 10;
fw = 'bold';

% Fig 1 - µ±? of processing module/video
f1 = figure;
x_cat = {'Secondaries', 'ARFS', 'DeMotion', 'EMR', 'SIFT-Automontager'};
% Secondary
mu_t_secondary = mean(t_secondary);
sd_t_secondary = std(t_secondary);
% ARFS
mu_t_arfs = mean(t_arfs);
sd_t_arfs = std(t_arfs);
% DeMotion
mu_t_dmp = mean(t_dmp);
sd_t_dmp = std(t_dmp);
% EMR
mu_t_emr = mean(t_emr);
sd_t_emr = std(t_emr);
% Automontager
mu_t_am = t_automontage / numel(img_fnames);
sd_t_am = 0; % Couldn't measure processing time directly

mu = [mu_t_secondary, mu_t_arfs, mu_t_dmp, mu_t_emr, mu_t_am] ;
bar(mu);
set(gca, 'xticklabel', categorical(x_cat), 'xticklabelrotation', 30, 'tickdir', 'out', ...
    'box', 'off', 'fontname', fn, 'fontsize', fst)
xlabel('Module', 'fontname', fn, 'fontsize', fsl, 'fontweight', fw)
ylabel('Time/Unit (s)', 'fontname', fn, 'fontsize', fsl, 'fontweight', fw);
hold on;
errorbar(mu, [sd_t_secondary, sd_t_arfs, sd_t_dmp, sd_t_emr, sd_t_am], ...
    '.k')

% Figure 2 - plot cumulative total processing time
lw = 2;
figure;
cmap = jet(numel(x_cat));
hold on;
% Secondaries
cs_secondary = cumsum(t_secondary);
x_secondary = 1:numel(cs_secondary);
plot(x_secondary, cs_secondary./3600, 'color', cmap(1,:), 'linewidth', lw);
% ARFS
cs_arfs = cumsum(t_arfs) + max(cs_secondary);
x_arfs = (1:numel(cs_arfs)) + max(x_secondary);
plot(x_arfs, cs_arfs./3600, 'color', cmap(2,:), 'linewidth', lw);
% DeMotion
cs_dmp = cumsum(t_dmp) + max(cs_arfs);
x_dmp = (1:numel(cs_dmp)) + max(x_arfs);
plot(x_dmp, cs_dmp./3600, 'color', cmap(3,:), 'linewidth', lw);
% EMR
cs_emr = cumsum(t_emr) + max(cs_dmp);
x_emr = (1:numel(cs_emr)) + max(x_dmp);
plot(x_emr, cs_emr./3600, 'color', cmap(4,:), 'linewidth', lw);
% AM - slightly different because we don't have time/image
cs_am = ((1:numel(img_fnames)) .* mu_t_am) + max(cs_emr);
x_am = (1:numel(img_fnames)) + max(x_emr);
plot(x_am, cs_am./3600, 'color', cmap(5,:), 'linewidth', lw);
hold off;
legend(x_cat, 'location', 'southeast', 'box', 'off')
xlabel('# Files Processed', 'fontname', fn, 'fontsize', fsl, 'fontweight', fw);
ylabel('Cumulative Time (hr)', 'fontname', fn, 'fontsize', fsl, 'fontweight', fw);
set(gca, 'tickdir', 'out', 'fontname', fn, 'fontsize', fst);



