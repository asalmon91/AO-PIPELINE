function getProfile(live_data_file)
%getProfile profiles processing time for the live pipeline

load(live_data_file, 'live_data')
root_path = fileparts(live_data_file);
paths = initPaths(root_path);

% Get number of processing time fields
fn = fieldnames(live_data.vid.vid_set(1));
fn(~contains(fn, 't_proc')) = [];

proc_times = zeros(numel(live_data.vid.vid_set), 2+numel(fn));
for ii=1:numel(live_data.vid.vid_set)
    % Get time of creation of a video in this set
    vid_ffname = fullfile(paths.raw, live_data.vid.vid_set(ii).vids(1).filename);
    d = System.IO.File.GetCreationTime(vid_ffname);
    t_create = datetime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
    proc_times(ii,1) = days2sec(datenum(t_create));
    
    % Get time this video was detected
    t_detect = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_create));
    proc_times(ii,2) = t_detect;
    
    % Get last modified for that video
    this_vid = dir(vid_ffname);
    t_last_mod = days2sec(this_vid.datenum);
    proc_times(ii,3) = t_last_mod;
    
    % Get time processing started
    proc_times(ii,4) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_start));
    
    % Get intermediary processing times
    proc_times(ii,5) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_read));
    proc_times(ii,6) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_dsind));
    proc_times(ii,7) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_arfs));
    proc_times(ii,8) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_ra));
    proc_times(ii,9) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_end));
    proc_times(ii,10) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_mon));
    
    % Get time processing ended
    
    % Subtract all by creation time
    proc_times(ii, :) = proc_times(ii, :) - proc_times(ii, 3);
end

figure; plot(proc_times', 'k')
set(gca, ...
    'XTick', 1:size(proc_times,2), ...
    'XTickLabel', {'Created', 'Detected', 'Written', 'Started', 'Read', 'Desinusoided', 'ARFS', 'Demotion', 'R/A', 'Montaged'}, ...
    'XTickLabelRotation', 30);
xlabel('Processing Stage');
ylabel('Time (s)');

end