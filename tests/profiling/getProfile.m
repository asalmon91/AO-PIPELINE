function getProfile(db_ffname)
%getProfile profiles processing time for the live pipeline

% Extract data about the file
[root_path, db_name, db_ext] = fileparts(db_ffname);
if ~strcmpi(db_ext, '.mat')
    error('Input must be a .mat');
end

% Determine db_type
if contains(db_name, 'FULL')
    db_type = 'full';
elseif contains(db_name, 'LIVE')
    db_type = 'live';
else
    error('Unrecognized database type: %s', db_name);
end

% Set up the different profiles
switch db_type
    case 'live'
        pipe_var_name = 'live_data';
        paths = initPaths(root_path);
        % Some hard-coding going on here
        % These things measured offline and are only relevant for live mode:
        import System.IO.File.GetCreationTime
        T_OFFLINE = {
            'Created';
            'Written'};
        % These things measured online:
        T_LUT = {
            't_proc_create',    'Detected';
            't_proc_start',     'R/A begin';
            't_proc_read',      'Read';
            't_proc_dsind',     'Desinusoided';
            't_proc_arfs',      'Reference Frames';
            't_proc_ra',        'R/A end';
            't_proc_end',       'R/A output';
            't_proc_mon',       'Montaged'};
        
    case 'full'
        pipe_var_name = 'pipe_data';
        T_LUT = {
            't_proc_create',    'Detected';
            't_full_mods',      'Secondaries';
            't_proc_start',     'R/A begin';
            't_proc_read',      'Read';
            't_proc_dsind',     'Desinusoided';
            't_proc_arfs',      'Reference Frames';
            't_proc_ra',        'R/A end';
            't_proc_emr',       'Dewarping';
            't_proc_end',       'R/A output';
            't_proc_mon',       'Montaged'};
        
    otherwise
        error('Unrecognized input: %s, options are: "live" and "full".', db_type)
end

% Rename the pipe variable to db
db = load(db_ffname, pipe_var_name);
fn = fieldnames(db);
db = db.(fn{1});

%% Measure times for each video set
n_vids = numel(db.vid.vid_set);
if n_vids == 0
    error('No video data for %s', db_ffname);
end
all_times = nan(n_vids, size(T_LUT, 1));
for ii=1:n_vids
    for jj=1:size(T_LUT, 1)
        this_clock = db.vid.vid_set(ii).(T_LUT{jj,1});
        if isempty(this_clock)
            warning('Missing clock data for video %i, module: %s.', ...
                db.vid.vid_set(ii).vidnum, T_LUT{jj,2});
            continue;
        end
        
        all_times(ii,jj) = days2sec(clock2datenum(this_clock));
    end
end

%% Add offline measurements for live pipe
if strcmp(db_type, 'live')
    offline_times = nan(n_vids, numel(T_OFFLINE));
    for ii=1:n_vids
        vid_ffname = fullfile(paths.raw, db.vid.vid_set(ii).vids(1).filename);
        
        for jj=1:numel(T_OFFLINE)
            if strcmpi(T_OFFLINE{jj}, 'created')
                % Get time of creation
                % Import statement in earlier switch:case
                d = GetCreationTime(vid_ffname);
                t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
                offline_times(ii,jj) = days2sec(datenum(t_create));
            elseif strcmpi(T_OFFLINE{jj}, 'written')
                % Get last-modified time
                this_vid = dir(vid_ffname);
                t_last_mod = days2sec(this_vid.datenum);
                offline_times(ii,jj) = t_last_mod;
            else
                error('Unrecognized input in T_OFFLINE');
            end
        end
    end
    
    % Concatenate offline and online measurements
    all_times = [offline_times, all_times];
    labels = [T_OFFLINE; T_LUT(:,2)];
else
    labels = T_LUT(:,2);
end

%% Set reference point
if strcmpi(db_type, 'live')
    ref_idx = strcmpi(labels, 'written');
% 	ref_idx = strcmpi(labels, 'detected');
else
    % todo: should have a more general "start" time for full
    ref_ixd = strcmpi(labels, 'secondaries'); 
end

all_times = all_times - all_times(:, ref_idx);

% temporarily ignore first two
% remove = any(isnan(all_times), 2);
% all_times = all_times(~remove, :);
% all_times = all_times(:, 3:end);
% labels = labels(3:end);

figure; plot(all_times', 'k')
set(gca, ...
    'XTick', 1:numel(labels), ...
    'XTickLabel', labels, ...
    'XTickLabelRotation', 30);
xlabel('Processing Stage');
ylabel('Time (s)');

% Get time / module
rel_times = diff(all_times, 1, 2);
mean_rel_times = mean(rel_times, 1);
std_rel_times = std(rel_times, [], 1);

figure;
boxplot(rel_times, labels(2:end))
set(gca, 'XTickLabelRotation', 30);
xlabel('Processing Stage');
ylabel('Time (s)');

end