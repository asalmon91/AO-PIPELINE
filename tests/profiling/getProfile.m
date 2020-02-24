function getProfile(live_data_file)
%getProfile profiles processing time for the live pipeline

load(live_data_file, 'live_data')
root_path = fileparts(live_data_file);
paths = initPaths(root_path);

proc_times = zeros(numel(live_data.vid.vid_set), 5);
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
    
    % Get time processing ended
    proc_times(ii,5) = days2sec(clock2datenum(live_data.vid.vid_set(ii).t_proc_end));
    
    % Subtract all by creation time
    proc_times(ii, :) = proc_times(ii, :) - proc_times(ii, 1);
end

figure; plot(proc_times', 'k')
set(gca, ...
    'XTick', 1:size(proc_times,2), ...
    'XTickLabel', {'Created', 'Detected', 'Written', 'Started', 'Ended'}, ...
    'XTickLabelRotation', 30);
xlabel('Processing Stage');
ylabel('Time (s)');

end