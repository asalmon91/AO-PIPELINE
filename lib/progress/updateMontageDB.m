function ld = updateMontageDB(ld, paths)
%updateMontageDB Updates the montage database
%   Updates the position file info
%   Checks for images to be montaged

%% Handle position file
read_loc_file = false;
if isempty(ld.mon) || ~isfield(ld.mon, 'loc_file') || isempty(ld.mon.loc_file)
    % Find if not already loaded
    ld.mon.loc_file = find_AO_location_file(paths.root);
    read_loc_file = true;
else
    % Check for updates
    file_info = dir(ld.mon.loc_file.name);
    if file_info.datenum > ld.mon.loc_file.datenum
        % File has been updated
        read_loc_file = true;
    end
end
if read_loc_file
    [loc_path, loc_name, loc_ext] = fileparts(ld.mon.loc_file.name);
    ld.mon.loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
end

%% Determine which images need montaging yet



end

