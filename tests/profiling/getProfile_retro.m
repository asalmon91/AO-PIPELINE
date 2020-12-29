function getProfile_retro(db_ffname)
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
        load(fullfile(db_ffname), 'live_data');
        
        LFIELDS = {
            'Queue Start',      't_proc_start';
            'Read',             't_proc_read';
            'Desinusoided',     't_proc_dsind';
            'ARFS',             't_proc_arfs';
            'Reg/Avg',          't_proc_ra';
            '2nd Mod Output',   't_proc_end';
            'Add to Montage',   't_proc_mon'};
        cmap = jet(size(LFIELDS, 1));
        pfig = figure;
        hold on;
        max_time = 0;
        total_lag = zeros(size(live_data.vid.vid_set));
        pipe_profile = zeros(numel(live_data.vid.vid_set), size(LFIELDS, 1));
        for ii=1:numel(live_data.vid.vid_set)
            init_time = days2sec(clock2datenum(...
                live_data.vid.vid_set(ii).(LFIELDS{1,2})));
            prev_time = 0;
            for jj=2:size(LFIELDS, 1)
                try
                    this_time = days2sec(clock2datenum(...
                        live_data.vid.vid_set(ii).(LFIELDS{jj,2}))) - init_time;
                    pipe_profile(ii, jj) = this_time;
                    if this_time > max_time
                        max_time = this_time;
                    end
                catch
                    warning('Failed to measure "%s" for video %i', ...
                        LFIELDS{jj, 1}, live_data.vid.vid_set(ii).vidnum);
                    continue;
                end
                plot([jj-2, jj-1], [prev_time, this_time], ...
                    'color', cmap(jj, :));
                prev_time = this_time;
            end
            
            % Measure total lag (time from queue start to montage)
            try
                total_lag(ii) = days2sec(...
                    clock2datenum(live_data.vid.vid_set(ii).(LFIELDS{end, 2})) - ...
                    clock2datenum(live_data.vid.vid_set(ii).(LFIELDS{2, 2})));
            catch
            end
        end
        set(gca, 'tickdir', 'out', 'xlim', [0, size(LFIELDS,1)-1], ...
            'xtick', 0:size(LFIELDS, 1)-1, ...
            'xticklabel', categorical(LFIELDS(:,1)), ...
            'XTickLabelRotation', 45);
        ylabel('Time (s)');
        total_lag(total_lag == 0) = [];
        title(sprintf('Lag: %1.1f±%1.1fs', ...
            mean(total_lag), std(total_lag)));
        
        out_ffname = fullfile(root_path, 'live-pipe-profile.fig');
        savefig(pfig, out_ffname);
        saveas(pfig, strrep(out_ffname, '.fig', '.svg'));
        
        profile_table = [LFIELDS(:,1)'; num2cell(pipe_profile)];
        xlswrite(fullfile(root_path, 'live-pipe-profile.xlsx'), profile_table);
        
%         pipe_var_name = 'live_data';
%         paths = initPaths(root_path);
%         % Some hard-coding going on here
%         % These things measured offline and are only relevant for live mode:
%         import System.IO.File.GetCreationTime
%         T_OFFLINE = {
%             'Created';
%             'Written'};
%         % These things measured online:
%         T_LUT = {
%             't_proc_create',    'Detected';
%             't_proc_start',     'R/A begin';
%             't_proc_read',      'Read';
%             't_proc_dsind',     'Desinusoided';
%             't_proc_arfs',      'Reference Frames';
%             't_proc_ra',        'R/A end';
%             't_proc_end',       'R/A output';
%             't_proc_mon',       'Montaged'};
%         
    case 'full'
        pipe_var_name = 'pipe_data';
        T_LUT = {
            't_proc_start',     'R/A begin';
            't_full_mods',      'Secondaries';
            't_proc_read',      'Read';
            't_proc_dsind',     'Desinusoided';
            't_proc_arfs',      'ARFS';
            't_proc_ra',        'R/A end'};
        % EMR not measured, but pretty negligible
        dt = nan(...
            numel(pipe_data.vid.vid_set), size(T_LUT, 1));
        for ii=1:numel(pipe_data.vid.vid_set)
            for jj=2:size(T_LUT, 1)
                try
                    dt(ii, jj) = days2sec(...
                        clock2datenum(pipe_data.vid.vid_set(ii).(T_LUT{jj,1})) - ...
                        clock2datenum(pipe_data.vid.vid_set(ii).(T_LUT{jj-1,1})));
                catch
                    warning('Failed');
                end
            end
        end
        
        
    otherwise
        error('Unrecognized input: %s, options are: "live" and "full".', db_type)
end

% % Rename the pipe variable to db
% db = load(db_ffname, pipe_var_name);
% fn = fieldnames(db);
% db = db.(fn{1});
% 
% %% Measure times for each video set
% n_vids = numel(db.vid.vid_set);
% if n_vids == 0
%     error('No video data for %s', db_ffname);
% end
% all_times = nan(n_vids, size(T_LUT, 1));
% for ii=1:n_vids
%     for jj=1:size(T_LUT, 1)
%         this_clock = db.vid.vid_set(ii).(T_LUT{jj,1});
%         if isempty(this_clock)
%             warning('Missing clock data for video %i, module: %s.', ...
%                 db.vid.vid_set(ii).vidnum, T_LUT{jj,2});
%             continue;
%         end
%         
%         all_times(ii,jj) = days2sec(clock2datenum(this_clock));
%     end
% end
% 
% %% Add offline measurements for live pipe
% if strcmp(db_type, 'live')
%     offline_times = nan(n_vids, numel(T_OFFLINE));
%     for ii=1:n_vids
%         vid_ffname = fullfile(paths.raw, db.vid.vid_set(ii).vids(1).filename);
%         
%         for jj=1:numel(T_OFFLINE)
%             if strcmpi(T_OFFLINE{jj}, 'created')
%                 % Get time of creation
%                 % Import statement in earlier switch:case
%                 d = GetCreationTime(vid_ffname);
%                 t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
%                 offline_times(ii,jj) = days2sec(datenum(t_create));
%             elseif strcmpi(T_OFFLINE{jj}, 'written')
%                 % Get last-modified time
%                 this_vid = dir(vid_ffname);
%                 t_last_mod = days2sec(this_vid.datenum);
%                 offline_times(ii,jj) = t_last_mod;
%             else
%                 error('Unrecognized input in T_OFFLINE');
%             end
%         end
%     end
%     
%     % Concatenate offline and online measurements
%     all_times = [offline_times, all_times];
%     labels = [T_OFFLINE; T_LUT(:,2)];
% else
%     labels = T_LUT(:,2);
% end
% 
% %% Set reference point
% if strcmpi(db_type, 'live')
%     ref_idx = strcmpi(labels, 'written');
% % 	ref_idx = strcmpi(labels, 'detected');
% else
%     % todo: should have a more general "start" time for full
%     ref_ixd = strcmpi(labels, 'secondaries'); 
% end
% 
% all_times = all_times - all_times(:, ref_idx);
% 
% % temporarily ignore first two
% % remove = any(isnan(all_times), 2);
% % all_times = all_times(~remove, :);
% % all_times = all_times(:, 3:end);
% % labels = labels(3:end);
% 
% figure; plot(all_times', 'k')
% set(gca, ...
%     'XTick', 1:numel(labels), ...
%     'XTickLabel', labels, ...
%     'XTickLabelRotation', 30);
% xlabel('Processing Stage');
% ylabel('Time (s)');
% 
% % Get time / module
% rel_times = diff(all_times, 1, 2);
% mean_rel_times = mean(rel_times, 1);
% std_rel_times = std(rel_times, [], 1);
% 
% figure;
% boxplot(rel_times, labels(2:end))
% set(gca, 'XTickLabelRotation', 30);
% xlabel('Processing Stage');
% ylabel('Time (s)');

end