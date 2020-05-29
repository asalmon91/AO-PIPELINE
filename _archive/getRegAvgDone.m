function [vids_done, failed] = getRegAvgDone(in_path)
%getRegAvgDone Searches the directory for a .mat file that only exists
%after a video is finished processing

%% Defaults
vids_done = {};
failed = [];

%% Search
regAvgDir = dir(fullfile(in_path, '*_regAvg.mat'));
if isempty(regAvgDir)
    return;
end

%% Get video number
% This is probably a dangerous way to do it. Likely to break if anything
% changes
vids_done = cell(numel(regAvgDir), 1);
failed = false(numel(regAvgDir), 1);
for ii=1:numel(regAvgDir)
    fname = regAvgDir(ii).name;
    vids_done{ii} = fname(1:4);
    
    % Warn about failures once
    load(fullfile(in_path, fname), 'status');
    if ~status % fail
        failed(ii) = true;
        try
            load(fullfile(in_path, fname), 'warned');
        catch
            warned = true; %#ok<NASGU>
            save(fullfile(in_path, fname), 'warned', '-append');
            load(fullfile(in_path, fname), 'msg');
            
            msgbox(sprintf('Video %s failed.\n%s', vids_done{ii}, msg), ...
                'RegAvg Failure', 'Error');
        end
    end
end


end

