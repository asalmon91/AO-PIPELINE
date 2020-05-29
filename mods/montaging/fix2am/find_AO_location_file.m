function loc_file_data = find_AO_location_file(in_path)
%find_AO_location_file finds and validates a live-updating position file
%   in_path should be the folder which contains the Raw, Processed,
%   Montages, and Calibration folders. Recursive search of the root allows
%   the user to place this file anywhere within root and name it whatever
%   they want (as long as it's still a .csv). This will validate the
%   contents so we know we have the right file.

%% Constants
LOC_FILE_EXT = '*.csv';

%% Defaults
loc_file_data = [];

%% Search for location file
% Should only have to do this once, so the expense of a 
% recursive/exhaustive file search for the sake of allowing any file naming
% convention is fine
search_results = subdir(fullfile(in_path, LOC_FILE_EXT));
loc_file_found = false;
for ii=1:numel(search_results)
    [loc_file_found, ~, ver_no] = ...
        verifyLocFile(search_results(ii).name);
    if loc_file_found
        break;
    end
end

if loc_file_found
    loc_file_data = search_results(ii);
    loc_file_data.ver = ver_no; % Add version # to structure
end

end

