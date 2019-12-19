function live_data = updateCalDB(live_data)
%updateCalDB updates the calibration database

cal_vid_dir = dir(fullfile(paths.cal, '*.avi'));

avi_fnames = {cal_vid_dir.name}';
mat_fnames = strrep(avi_fnames, '.avi', '.mat');

% Check to see if video or header has been overwritten
% If nothing is new, we can return
if ~isempty(live_data)
        
end

% Get FOV & wavelength
fovs = getFOV(fullfile(paths.cal, mat_fnames));
wavelengths = getWavelength(mat_fnames);


% Check for existing desinusoid matrices
cal_dsin_dir = dir(fullfile(paths.cal, 'desinusoid_matrix*.mat'));



% Pair up horizontal and vertical videos












end

