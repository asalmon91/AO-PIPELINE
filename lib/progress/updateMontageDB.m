function ld = updateMontageDB(ld, paths)
%updateMontageDB Updates the montage database
%   Updates the position file info
%   Checks for images to be montaged

%% Handle position file
read_loc_file = false;
if isempty(ld.mon) || ~isfield(ld.mon, 'loc_file') || isempty(ld.mon.loc_file)
    % Find if not already loaded
    ld.mon.loc_file = find_AO_location_file(paths.root);
    if ~isempty(ld.mon.loc_file)
        read_loc_file = true;
    end
else
    % Check for updates
    file_info = dir(ld.mon.loc_file.name);
    if file_info.datenum > ld.mon.loc_file.datenum
        % File has been updated
        read_loc_file = true;
        ld.mon.loc_file.datenum = file_info.datenum;
    end
end
if read_loc_file
    [loc_path, loc_name, loc_ext] = fileparts(ld.mon.loc_file.name);
    try
        ld.mon.loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
        disp(ld.mon.loc_data.vidnums)
    catch MException
        % Sometimes we catch it while it's writing, just wait until the
        % next iteration and try again
        if strcmp(MException.identifier, ...
                'MATLAB:xlsread:WorksheetNotActivated')
        else
            rethrow(MException);
        end
    end
end

%% Check...
% % Check if the live processed folder has been updated
% tif_dir = dir(fullfile(paths.out, '*.tif'));
% most_recent_datenum = max([tif_dir.datenum]);
% if ~isfield(ld.mon, 'img_datenum') || isempty(ld.mon.img_datenum) || ...
%         most_recent_datenum > ld.mon.img_datenum
%     ld.mon.img_datenum = most_recent_datenum;
% else
%     return;
% end






end

