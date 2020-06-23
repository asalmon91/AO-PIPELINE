%% Imports
addpath(genpath('..\mods'));
% addpath(genpath('lib'));

%% Get data
src_path = '\\burns.rcc.mcw.edu\AOIP\17439-FullBank\';
src = dir(src_path);
ignore = {'.'; '..'};
BUILD_TAG = 'AO_2_3_SLO';
hasAO2p3 = false(size(src));
hasLocFile = hasAO2p3;
parfor ii=1:numel(src)
    if ~src(ii).isdir || any(strcmp(src(ii).name, ignore))
        continue;
    end
    contents = dir(fullfile(src_path, src(ii).name));
    folder_names = {contents.name}';
    if any(strcmp(BUILD_TAG, folder_names))
        hasAO2p3(ii) = true;
        fprintf('%s has %s\n', src(ii).name, BUILD_TAG);
        
        loc_file = find_AO_location_file(...
            fullfile(src(ii).folder, src(ii).name, BUILD_TAG));
        if ~isempty(loc_file)
            hasLocFile(ii) = true;
            fprintf('and has a location file at %s\n', loc_file.folder);
        end
    end
end

%% Filter
src = src(hasAO2p3 & hasLocFile);

%% Open for manual viewing
trg = uigetdir(src_path, 'Select output folder');
if isnumeric(trg)
    return;
end
for ii=1:numel(src)
    loc_file = find_AO_location_file(...
            fullfile(src(ii).folder, src(ii).name, BUILD_TAG));
    winopen(loc_file.folder);
    
    re = questdlg('Copy this dataset?','Copy?','Yes','No','Quit','Yes');
    switch re
        case 'Quit'
            break;
        case 'No'
            continue;
        case 'Yes'
            out_path = fullfile(trg, loc_file.folder(numel(src_path):end));
            mkdir(out_path);
            copyfile(loc_file.name, out_path);
    end
end

% 790nm AND (confocal OR direct OR reflect) AND (.avi OR .mat)
