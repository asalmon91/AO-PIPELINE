%% Collect all montages and AO_PIPE_FULL.mat's for analysis

%% Imports
cd('\\burns.rcc.mcw.edu\aoip\1-Software\AO_Tools\2-Processing\AO-PIPELINE-beta\AO-PIPELINE');
addpath(genpath('classes'), genpath('lib'), genpath('mods'));

%% Input and output paths
src_root = '\\burns.rcc.mcw.edu\aoip\2-Purgatory\Test_Imaging\AO-PIPE-test\retro';
trg_root = 'C:\Users\asalmon\Box\PRO-30741\WIP_Salmon_Manuscript_PIPE\figs\0X-RetroFull\montages';

%% Constants
FOLDER_EXPR = '\d-*';
DSET_EXPR = 'auto-*';
DATE_EYE_EXPR = '\d{4}_\d{2}_\d{2}_O[DS]';
COND_KEY = {
    '1-ctrl',   'Control';
    '2-achm',   'ACHM';
    '3-alb',    'Albinism';
    '4-tlgs',   '13-LGS'};

%% Get mode
re = questdlg('Live or Full?', 'Mode', 'Live', 'Full', 'Cancel', 'Live');
switch re
	case 'Live'
		db_fname = 'AO_PIPE_LIVE.mat';
        folder_append = 'LIVE';
        pipe_var_name = 'live_data';
        end_time_field = 't_proc_mon';
	case 'Full'
		db_fname = 'AO_PIPE_FULL.mat';
        folder_append = 'FULL';
        pipe_var_name = 'pipe_data';
        end_time_field = 't_proc_end';
	case 'Cancel'
		return
	otherwise
		return;
end

%% Get data dirs in src
src_dir = dir(src_root);
% Filter by expected format
src_names = {src_dir.name}';
src_filt = ~cell2mat(cellfun(@isempty, ...
    (regexp(src_names, FOLDER_EXPR)), ...
    'UniformOutput', false));
src_dir = src_dir(src_filt);

%% Launch photoshop to analyze montages
addpath(genpath('C:\Program Files\Adobe\Adobe Photoshop CS6 (64 Bit)\Matlab-PS-CS6-integration\MATLAB_Win64\Required'))
pslaunch;

%% Copy these to trg
% t_proc_time_hr_all = cell(size(src_dir));
% n_vid_all = t_proc_time_hr_all;
% n_missing_imgs = t_proc_time_hr_all;
% n_mon_deg2_all = t_proc_time_hr_all;
% n_pieces_all = t_proc_time_hr_all;
% n_mon_imgs_all = t_proc_time_hr_all;
% dset_names      = t_proc_time_hr_all;
for ii=1:numel(src_dir)
    src_dir(ii).dsets = dir(fullfile(src_root, src_dir(ii).name, DSET_EXPR));
    
    t_proc_time_cond	= nan(size(src_dir(ii).dsets));
    n_vids_cond         = t_proc_time_cond;
    n_missing_imgs_dset = t_proc_time_cond;
    a_mon_dset          = t_proc_time_cond;
    n_pieces_dset       = t_proc_time_cond;
    n_mon_imgs_dset     = t_proc_time_cond;
    for jj=1:numel(src_dir(ii).dsets)
        % Get date/eye folder name
        dset_folder_names = {dir(fullfile(src_dir(ii).dsets(jj).folder, ...
            src_dir(ii).dsets(jj).name)).name}';
        date_eye_filt = ~cell2mat(cellfun(@isempty, ...
            (regexp(dset_folder_names, DATE_EYE_EXPR)), ...
            'UniformOutput', false));
        date_eye_folder_name = dset_folder_names{date_eye_filt};
        
        % Make a duplicate copy of the folder in trg
        out_dir = fullfile(trg_root, src_dir(ii).name, ...
            src_dir(ii).dsets(jj).name, date_eye_folder_name);
        if ~exist(out_dir, 'dir')
            mkdir(out_dir);
        end
        
        % Copy and rename the database file
        db_ffname = fullfile(src_root, src_dir(ii).name, ...
            src_dir(ii).dsets(jj).name, date_eye_folder_name, db_fname);
        db_out_ffname = strrep(db_ffname, src_root, trg_root);
        name_parts = strsplit(src_dir(ii).dsets(jj).name, '-');
        db_out_ffname = strrep(db_out_ffname, db_fname, [name_parts{2}, '-', db_fname]);
        if exist(db_ffname, 'file')
            fprintf('Database file found!\n%s\n', db_ffname);
            % Copy to trg
            if ~exist(db_out_ffname, 'file')
                [success, msg] = copyfile(db_ffname, db_out_ffname);
                if ~success
                    warning(msg)
                end
            end
            
            % Profile while we're here
            db = load(db_ffname, pipe_var_name);
            % convert to a common variable name
            db = db.(pipe_var_name);
            
            % Number of video sets
            n = numel(db.vid.vid_set);
            
            % Measure total processing time
            try
                start_times = {db.vid.vid_set(:).t_proc_start}';
                remove = cell2mat(cellfun(@isempty, start_times, ...
                    'UniformOutput', false));
                start_times(remove) = [];
                start_dn = min(cellfun(@clock2datenum, ...
                    start_times));
                end_times = {db.vid.vid_set(:).(end_time_field)}';
                % remove empties
                remove = cell2mat(cellfun(@isempty, end_times, ...
                    'UniformOutput', false));
                end_times(remove) = [];
                end_dn = max(cellfun(@clock2datenum, ...
                    end_times));
                t_proc_time_cond(jj) = days2sec(end_dn - start_dn);
            catch me % one subject failed to montage any images
                % Just leave as NaN
            end
            % Measure number of videos attempted
            n_vids_cond(jj) = numel(start_times);
            
            % Get number of videos that failed to process
            switch re
                case 'Live'
                    missingImgs = getMissingImgs(...
                        fullfile(src_root, src_dir(ii).name, ...
                        src_dir(ii).dsets(jj).name, date_eye_folder_name, ...
                        'Montages', folder_append), ...
                        fullfile(src_root, src_dir(ii).name, ...
                        src_dir(ii).dsets(jj).name, date_eye_folder_name, ...
                        'Raw'));
                    n_missing_imgs_dset(jj) = ...
                        numel(find(~missingImgs(:,2)));
                case 'Full'
                    n_missing_imgs_dset(jj) = ...
                        sum(~[db.vid.vid_set.hasAnySuccess]) - numel(find(remove));
            end
        else
            warning('Failed to find %s', db_ffname);
        end
        
        %% Find the montage file
        psd_found = false;
        try
            src_psd = subdir(fullfile(src_root, src_dir(ii).name, ...
                src_dir(ii).dsets(jj).name, date_eye_folder_name, ...
                'Montages', folder_append, '*.psd'));
        catch me
            warning(me.message)
            src_psd = [];
        end
        if numel(src_psd) ~= 1 % Unexpected search result
            if isempty(src_psd) % Not found
                warning('Failed to find a montage within %s', ...
                    fullfile(src_root, src_dir(ii).name, dset_dir(jj).name));
            elseif numel(src_psd) > 1 % Multiple found
                [psd_fname, psd_path] = uigetfile('*.psd', ...
                    'Select the montage file (more than 1 found)', ...
                    fullfile(src_root, src_dir(ii).name, dset_dir(jj).name));
                if isnumeric(psd_fname)
                    warning('Skipped by user');
                end
                psd_ffname = fullfile(psd_path, psd_fname);
                psd_found = true;
            end
        else % Successfully found
            psd_ffname = src_psd.name;
            psd_found = true;
        end
        % Copy to trg
        if psd_found
            fprintf('Montage found!\n%s\n',psd_ffname);
            % Get output name
            [psd_path, psd_name, psd_ext] = fileparts(psd_ffname);
            psd_out_ffname = fullfile(out_dir, sprintf('%s-%s.psd', ...
                name_parts{2}, folder_append));
            if ~exist(psd_out_ffname, 'file')
                [success, msg] = copyfile(psd_ffname, psd_out_ffname);
                if ~success
                    warning(msg);
                end
            end
            
            % We don't actually need to do it this way
            % If I had imported the ao-pipe classes, we could have used the
            % clocks
            if strcmp(re, 'Full') 
                % Re-measure total processing time to include montage time
                start_times = {db.vid.vid_set(:).t_proc_start}';
                remove = cell2mat(cellfun(@isempty, start_times, ...
                    'UniformOutput', false));
                start_times(remove) = [];
                start_dn = min(cellfun(@clock2datenum, ...
                    start_times));
%                 mod2_dir = dir(fullfile(src_root, src_dir(ii).name, dset_dir(jj).name, ...
%                     'Raw', '*_split_det_*.avi'));
%                 n_vids_cond(jj) = numel(mod2_dir);
%                 start_dn = min([mod2_dir.datenum]);
                % Get automontager file
                mon_search_path = fullfile(...
                    src_root, src_dir(ii).name, ...
                    src_dir(ii).dsets(jj).name, date_eye_folder_name, ...
                    'Montages', folder_append);
                mon_dir = dir(fullfile(mon_search_path, 'AOMontageSave.mat'));
                t_proc_time_cond(jj) = days2sec(mon_dir.datenum - start_dn);
                if ~exist(fullfile(out_dir, mon_dir.name), 'file')
                    [success, msg] = copyfile(...
                        fullfile(mon_dir.folder, mon_dir.name), out_dir);
                    if ~success
                        warning(msg);
                    end
                end
                
                % Also get the total montage area and number of disconnections
                [mon_scale, vn, N] = getMontageScale(...
                    fullfile(mon_dir.folder, mon_dir.name), db);
                
                [~, n_pieces, max_mon_px] = ...
                    getMontageAreaAndUnits(psd_ffname);
                a_mon_dset(jj) = max_mon_px * (1/mon_scale^2);
                n_pieces_dset(jj)  = n_pieces;

                % Get number of images in the montage
                n_mon_imgs_dset(jj) = N;
            else % LIVE
                n_pieces_dset(jj) = numel(db.mon.montages);
                
                % Find the minimum FOV used in this montage
                min_fov = inf;
                for mm=1:numel(db.mon.montages)
                    for nn=1:numel(db.mon.montages(mm).txfms)
                        img_ffname = db.mon.montages(mm).txfms{nn}{1};
                        [~,img_name, img_ext] = fileparts(img_ffname);
                        kv = findImageInVidDB(db, [img_name, img_ext]);
                        this_fov = db.vid.vid_set(kv(1)).fov;
                        if this_fov < min_fov
                            min_fov = this_fov;
                        end
                    end
                end
                % Get the pixels per degree that was used for this montage
                this_ppd = db.cal.dsin([db.cal.dsin.fov] == min_fov).ppd;
                
                % Convert all txfms from deg to px
                mon = db.mon.montages;
                montage_areas = zeros(size(mon));
                n_mon_imgs_dset(jj) = 0;
                for mm=1:numel(mon)
                    minx_maxx = zeros(numel(mon(mm).txfms), 2);
                    miny_maxy = minx_maxx;
                    for nn=1:numel(mon(mm).txfms)
                        n_mon_imgs_dset(jj) = n_mon_imgs_dset(jj) +1;
                        this_txfm = mon(mm).txfms{nn}(2:5);
                        this_txfm_px = cellfun(@(x) x.*this_ppd, this_txfm, ...
                            'UniformOutput', false);
                        this_txfm_px_mat = cell2mat(this_txfm_px);
                        minx_maxx(nn, 1) = this_txfm_px_mat(1)-this_txfm_px_mat(4)/2;
                        minx_maxx(nn, 2) = this_txfm_px_mat(1)+this_txfm_px_mat(4)/2;
                        miny_maxy(nn, 1) = this_txfm_px_mat(2)-this_txfm_px_mat(3)/2;
                        miny_maxy(nn, 2) = this_txfm_px_mat(2)+this_txfm_px_mat(3)/2;
                        mon(mm).txfms{nn}(2:5) = this_txfm_px;
                    end
                    minx = min(floor(minx_maxx(:,1)));
                    maxx = max(ceil(minx_maxx(:,2)));
                    miny = min(floor(miny_maxy(:,1)));
                    maxy = max(ceil(miny_maxy(:,2)));
                    
                    canvas = false(maxy-miny+1, maxx-minx+1);
                    for nn=1:numel(mon(mm).txfms)
                        this_txfm = cell2mat(mon(mm).txfms{nn}(2:5));
                        this_txfm(1) = this_txfm(1) - minx +1;
                        this_txfm(2) = this_txfm(2) - miny +1;
                        canvas(...
                            round(this_txfm(2)-this_txfm(3)/2) : round(this_txfm(2)+this_txfm(3)/2), ...
                            round(this_txfm(1)-this_txfm(4)/2) : round(this_txfm(1)+this_txfm(4)/2)) = true;
                    end
                    montage_areas(mm) = numel(find(canvas));
                end
                
%                 % Construct a binary canvas for each disjoint to measure
%                 % segment area
%                 montage_areas = zeros(size(db.mon.montages));
%                 n_mon_imgs_dset(jj) = 0;
%                 for mm=1:numel(db.mon.montages)
%                     canvas = [];
%                     for nn=1:numel(db.mon.montages(mm).txfms)
%                         n_mon_imgs_dset(jj) = n_mon_imgs_dset(jj)+1;
%                         im_ffname = db.mon.montages(mm).txfms{nn}{1};
%                         [~,im_name,~] = fileparts(im_ffname);
%                         im = imread(fullfile(...
%                             src_root, src_dir(ii).name, ...
%                             src_dir(ii).dsets(jj).name, ...
%                             date_eye_folder_name, 'Montages', ...
%                             folder_append, [im_name, '.tif']));
%                         if isempty(canvas)
%                             canvas = im(:,:,2) > 0;
%                         else
%                             try
%                                 canvas = canvas | im(:,:,2) > 0;
%                             catch me % Extremely rare rounding error
%                                 if strcmp(me.identifier, 'MATLAB:dimagree')
%                                     im = imresize(im, size(canvas));
%                                     canvas = canvas | im(:,:,2) > 0;
%                                 end
%                             end
%                         end
%                     end
%                     montage_areas(mm) = numel(find(canvas));
%                 end
                max_mon_px = max(montage_areas);
                a_mon_dset(jj) = max_mon_px * (1/this_ppd^2);
            end
        end
    end
    
    src_dir(ii).t_proc_time     = t_proc_time_cond;
    src_dir(ii).n_vid           = n_vids_cond;
    src_dir(ii).n_missing_imgs  = n_missing_imgs_dset;
    src_dir(ii).a_mon_deg2      = a_mon_dset;
    src_dir(ii).n_pieces        = n_pieces_dset;
    src_dir(ii).dset_names      = {src_dir(ii).dsets.name}';
    src_dir(ii).n_mon_imgs      = n_mon_imgs_dset;
end

%% Compile total_proc_time results
cond = cell(size(src_dir));
for ii=1:numel(src_dir)
    cond{ii} = cellstr(repmat(src_dir(ii).name, ...
        numel(src_dir(ii).dsets), 1));
end
cond = vertcat(cond{:});

%% Get formatted x-labels
for ii=1:size(COND_KEY, 1)
    cond = cellfun(@(x) strrep(x, COND_KEY{ii, 1}, COND_KEY{ii,2}), ...
        cond, 'uniformoutput', false);
end
t_proc      = cell2mat({src_dir(:).t_proc_time}');
n_vids      = cell2mat({src_dir(:).n_vid}');
n_missing   = cell2mat({src_dir(:).n_missing_imgs}');
a_mon_deg2  = cell2mat({src_dir(:).a_mon_deg2}');
n_mon_imgs  = cell2mat({src_dir(:).n_mon_imgs}');
n_pieces    = cell2mat({src_dir(:).n_pieces}');

dset_all_names = cell(size(src_dir));
for ii=1:numel(src_dir)
    dset_all_names{ii} = {src_dir(ii).dsets.name}';
end
dset_all_names = vertcat(dset_all_names{:});
% Make a table 
full_table = table(categorical(cond), dset_all_names, ...
    t_proc, n_vids, n_missing, a_mon_deg2, n_pieces, n_mon_imgs, ...
    'VariableNames', ...
    {'Condition', 'Dataset', 'TotalProcessingTime_s', 'N_Videos', ...
    'N_Vids_Missing_Imgs', 'A_mon_deg2', 'N_Pieces', 'N_ImgsInMon'});

%% Start outputs
out_path = uigetdir(src_root, 'Select output directory');
writetable(full_table, fullfile(out_path, 'full_table.xlsx'));
save(fullfile(out_path, 'full_table.mat'), 'full_table');

%% Figure constants
fn = 'arial';
fs = 7;
fsl = 9;
fst = 12;
fw = 'bold';

%% Plot timing data
f1 = figure;
% Absolute time
subplot(3,3,1);
boxplot(t_proc./3600, cond)
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
xlabel('Condition', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylabel('Absolute Total Time (hr)', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylim([0, 15]);
axis square
title('A', 'units', 'normalized', 'position', [-.1, 1.01, 1], ...
    'FontName', fn, 'FontSize', fst, 'FontWeight', fw);

% Time/Video
subplot(3,3,2);
boxplot(t_proc./n_vids./60, cond)
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
xlabel('Condition', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylabel('Time/Video (min)', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylim([0, 15]);
axis square
title('B', 'units', 'normalized', 'position', [-.1, 1.01, 1], ...
    'FontName', fn, 'FontSize', fst, 'FontWeight', fw);

% % Time/Video if run serially
subplot(3,3,3);
boxplot(t_proc./n_vids.*4./60, cond)
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
xlabel('Condition', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylabel('Serial Time/Video (min)', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylim([0, 60]);
axis square
title('C', 'units', 'normalized', 'position', [-.1, 1.01, 1], ...
    'FontName', fn, 'FontSize', fst, 'FontWeight', fw);

%% Do an ANOVA
[p, tbl, stats] = anova1(t_proc./n_vids, cond);
[c,m,h,gnames] = multcompare(stats);

save(fullfile(out_path, 'anova_results.mat'), 'p', 'stats', 'c', 'gnames');
% savefig(f1, fullfile(out_path, 'profile_fig.fig'));

%% Plot percentage of failed videos
% ff = figure;
subplot(3,3,7)
boxplot(n_missing./n_vids.*100, cond);
ylim([-10, 100])
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
ylabel('Failure Rate (%)', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
% savefig(ff, fullfile(out_path, 'failurerate.fig'));

%% Plot montage connectivity
% fmc = figure;
subplot(3,3,8)
boxplot(1- ((n_pieces-1)./n_mon_imgs), cond)
ylim([0, 1])
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
ylabel('Montage Connectivity (AU)', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
% savefig(fmc, fullfile(out_path, 'montage_connectivity.fig'));

%% Determine representative subjects and get a single dataset profile
if strcmp(re, 'Live')
    T_LUT = {
        't_proc_start',     'Start';
        't_proc_read',      'Read';
        't_proc_dsind',     'Desinusoided';
        't_proc_arfs',      'ARFS';
        't_proc_ra',        'R&A';
        't_proc_end',       'Montaged'};
else % Full
    T_LUT = {
        't_proc_start',     'Start';
        't_full_mods',      'Secondaries';
        't_proc_read',      'Read';
        't_proc_dsind',     'Desinusoided';
        't_proc_arfs',      'ARFS';
        't_proc_ra',        'R&A'};
end

mod_tbls = cell(size(src_dir));
figure;
for ii=1:numel(src_dir)
    % Determine which subject is representative
    these_times = src_dir(ii).t_proc_time./src_dir(ii).n_vid;
    % Will need to remove nans for subjects who completely failed
    idx = 1:numel(these_times);
    remove = isnan(these_times);
    these_times(remove) = [];
    idx(remove) = [];
    % Get min distance from median
    [~, I] = min(abs(these_times - median(these_times)));
    orig_idx = idx(I);
    
    % Load this subject's db file
    dset_path = fullfile(src_root, src_dir(ii).name, ...
        src_dir(ii).dsets(orig_idx).name);
    db_search = subdir(fullfile(dset_path, db_fname));
    db = load(db_search.name, pipe_var_name);
    db = db.(pipe_var_name);
    
    n = numel(db.vid.vid_set);
    all_t = NaN(n, size(T_LUT, 1));
    labels = cell(size(all_t));
    
    for jj=1:n
        % Normalize to number of frames
        this_n_frames = numel(db.vid.vid_set(jj).vids(1).frames); 
        ref_time = clock2datenum(db.vid.vid_set(jj).t_proc_start);
        for kk=1:size(T_LUT, 1)
            try
                this_time = clock2datenum(db.vid.vid_set(jj).(T_LUT{kk,1}));
                all_t(jj, kk) = days2sec(this_time - ref_time)/this_n_frames;
                labels{jj, kk} = T_LUT{kk, 2};
                if strcmp(re, 'Full')
                    ref_time = this_time;
                end
            catch
                warning('Couldn''t measure %s time for video %i.', ...
                    T_LUT{kk,2}, db.vid.vid_set(jj).vidnum);
            end
        end
    end
    subplot(1,numel(src_dir), ii);
    plot(cumsum(all_t, 2)', '-k');
    set(gca, 'xtick', 1:size(T_LUT, 1), 'xticklabel', T_LUT(:,2), ...
        'xticklabelrotation', 90, 'tickdir', 'out', 'box', 'off', ...
        'fontname', fn, 'fontsize', fs);
    title(src_dir(ii).name, ...
        'fontname', fn, 'fontsize', fsl, 'FontWeight', fw)
    axis square
    if ii==1
        ylabel('Cumulative Time/# frames (s)', ...
            'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
    end
    
    % Format into table
    label_vec   = labels(:);
    t_vec       = all_t(:);
    remove      = isnan(t_vec);
    label_vec(remove)   = [];
    t_vec(remove)      = [];

    % Add acquisition timestamps if live
    if strcmp(re, 'Live')
        src_dset_path = fullfile(src_root, src_dir(ii).name, src_dir(ii).dsets(orig_idx).name);
        this_dir = dir(src_dset_path);
        dset_folder_names = {this_dir.name}';
        date_eye_filt = ~cell2mat(cellfun(@isempty, ...
                (regexp(dset_folder_names, DATE_EYE_EXPR)), ...
                'UniformOutput', false));
        date_eye_folder_name = dset_folder_names{date_eye_filt};
        src_raw_path = fullfile(src_dset_path, date_eye_folder_name, 'Raw');
        vid_dir = dir(fullfile(src_raw_path, '*_confocal_*.avi'));
        if numel(vid_dir) ~= n
            error('Mismatch between measured number of videos and actual');
        end
        acq_lag = days2sec(diff(sort([vid_dir.datenum])))';
    
        % Concatenate acquisition times
        t_vec = [t_vec; acq_lag];
        label_vec = [label_vec; cellstr(repmat('Acquisition Delay', size(acq_lag)))];
    end
    
    % Get condition and dataset labels
    this_cond   = cellstr(repmat(src_dir(ii).name, size(t_vec)));
    this_dset   = cellstr(repmat(src_dir(ii).dsets(orig_idx).name, size(t_vec)));
    mod_tbls{ii} = table(this_cond, this_dset, label_vec, t_vec, ...
        'VariableNames', {'Condition', 'Dataset', 'ProcStep', 'Time_s'});
end
% Combine tables
comb_mod_tbls = vertcat(mod_tbls{:});

% Remove start (all 0)
remove = strcmp(comb_mod_tbls.ProcStep, 'Start');
comb_mod_tbls(remove, :) = [];

% Calculate time as a % of total processing time
u_cond = unique(comb_mod_tbls.Condition);
u_mods = {'Read', 'Secondaries', 'Desinusoided', 'ARFS', 'R&A'};
stack_table_mu = zeros(numel(u_cond), numel(u_mods));
stack_table_sd = stack_table_mu;
for ii=1:numel(u_cond)
    this_cond = strcmp(comb_mod_tbls.Condition, u_cond{ii});
    this_dataset = unique(comb_mod_tbls.Dataset(this_cond));
    total_time = full_table.TotalProcessingTime_s(...
        strcmp(full_table.Dataset, this_dataset{1}));
    for jj=1:numel(u_mods)
        this_mod = strcmp(comb_mod_tbls.ProcStep, u_mods{jj});
        these_times = sum(comb_mod_tbls.Time_s(this_cond & this_mod))./total_time.*100;
        
        stack_table_mu(ii,jj) = these_times;
%         stack_table_sd(ii,jj) = std(these_times);
    end
end

figure;
bar(categorical(u_cond), stack_table_mu, 'stacked')
legend(u_mods)

percent_total_time = zeros(size(comb_mod_tbls, 1), 1);
for ii=1:numel(u_cond)
    this_cond = strcmp(comb_mod_tbls.Condition, u_cond(ii));
    this_dataset = unique(comb_mod_tbls.Dataset(this_cond));
    total_time = full_table.TotalProcessingTime_s(...
        strcmp(full_table.Dataset, this_dataset));
%     total_time = sum(comb_mod_tbls.Time_s(this_cond));
    percent_total_time(this_cond) = comb_mod_tbls.Time_s(this_cond)./total_time.*100;
end
comb_mod_tbls = [comb_mod_tbls, table(percent_total_time, ...
    'VariableNames', {'ModTimePerTotalTime_percent'})];

% modfig = figure;
subplot(3,3,4:6)
boxplot(percent_total_time, ...
    {comb_mod_tbls.ProcStep, comb_mod_tbls.Condition}, ...
    'ColorGroup', categorical(comb_mod_tbls.Condition), ...%     'plotstyle', 'compact', ...
    'LabelVerbosity', 'minor');
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'FontSize', fs)
ylim([-.5, 10])
ylabel('Module Time / Total Time (%)', ...
    'FontName', fn, 'FontSize', fsl, 'FontWeight', fw);
title('D', 'FontName', fn, 'FontSize', fst, 'FontWeight', fw);
% xlabel('Processing Step');
writetable(comb_mod_tbls, fullfile(out_path, 'retro_modular_profile.xlsx'));
save(fullfile(out_path, 'retro_modular_profile.mat'), 'comb_mod_tbls');

% Get manually montaged table
[man_fname, man_path] = uigetfile('*man_mon_table.mat', 'Select man_mon_table.mat');
load(fullfile(man_path, man_fname), 'man_table');

full_table = sortrows(full_table, 'Dataset');
man_table  = sortrows(man_table, 'Dataset');
merge_table = [full_table, man_table(:, 2:end)];
merge_table.Properties.VariableNames = {...
	'Condition', 'Dataset', 'TotalProcessingTime_s', 'N_Vids', 'N_MissingImgs', ...
	'AutoMonArea_deg2', 'AutoNPieces', 'N_ImgsInMon', 'ManMonArea_deg2', 'ManNPieces'};

%% Get a figure of relative montage area
subplot(3,3,9)
boxplot(merge_table.AutoMonArea_deg2 ./ merge_table.ManMonArea_deg2 .*100, {merge_table.Condition}, ...
	'GroupOrder', {'Control', 'ACHM', 'Albinism', '13-LGS'})
set(gca, 'tickdir', 'out', 'box', 'off', ...
    'fontname', fn, 'fontsize', fs);
xlabel('Condition', 'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylabel('Largest Segment (Auto/Manual; %)', ...
	'fontname', fn, 'fontsize', fsl, 'FontWeight', fw);
ylim([0, 150]);
axis square
title('G', 'units', 'normalized', 'position', [-.1, 1.01, 1], ...
    'FontName', fn, 'FontSize', fst, 'FontWeight', fw);

savefig(f1, fullfile(out_path, 'full.fig'));

% out_table = table(all_cond, all_steps, all_times, ...
% 	'VariableNames', {'Condition', 'ProcStep', 'Time_s'});
% [out_fname, out_path] = uiputfile('*.mat', 'Save data', 'retro_live_modular_profile.mat');








