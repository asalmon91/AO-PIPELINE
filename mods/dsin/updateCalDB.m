function live_data = updateCalDB(live_data)
%updateCalDB updates the calibration database

cal_vid_dir = dir(fullfile(paths.cal, '*.avi'));

avi_fnames = {cal_vid_dir.name}';
mat_fnames = strrep(avi_fnames, '.avi', '.mat');

% Check to see if video or header has been overwritten
% If nothing is new, we can return
if ~isempty(live_data)
    
    
    
    
end

% Get FOV, wavelength & orientation
fovs = getFOV(fullfile(paths.cal, mat_fnames));
wavelengths = getWavelength(mat_fnames);
orientations = getOrientation(mat_fnames);
horz = strcmp(orientations, 'horz');
vert = strcmp(orientations, 'vert');

% Check that there is only one video for each combination of fov,
% wavelength, and orientation. If there is redundancy, warn user and use
% newest version of that combination



%% Combine FOV & wavelength for horz videos, find matching vert videos
% todo: make this section the new pairHorzVert function
h_fovs = fovs(horz);
h_wls  = wavelengths(horz);
v_fovs = fovs(vert);
v_wls  = wavelengths(vert);

h_avi_fnames = avi_fnames(horz);
v_avi_fnames = avi_fnames(vert);
order = zeros(size(h_avi_fnames));
for ii=1:numel(h_avi_fnames)
    order(ii) = find(v_fovs == h_fovs(ii) & v_wls == h_wls(ii));
end
v_avi_fnames = v_avi_fnames(order);

% Construct grid pair structure
gridPairs(numel(h_avi_fnames)).fov = h_fovs(1);
for ii=1:numel(h_avi_fnames)
    gridPairs(ii).fov       = h_fovs(ii);
    gridPairs(ii).wl_nm     = h_wls(ii);
    gridPairs(ii).h_fname   = h_avi_fnames{ii};
    gridPairs(ii).v_fname   = v_avi_fnames{ii};
end

%% Check for existing desinusoid matrices
cal_dsin_dir = dir(fullfile(paths.cal, 'desinusoid_matrix*.mat'));
dsin_fovs = [];
dsin_wavelengths = [];
if ~isempty(cal_dsin_dir)
    dsin_fovs = getFOV(fullfile(paths.cal, {cal_dsin_dir.name}'));
    dsin_wavelengths = getWavelength({cal_dsin_dir.name}');
end

% Determine if there are any grid pairs that don't have a
% corresponding desinusoid matrix
needs_dsin = false(size(gridPairs));
for ii=1:numel(gridPairs)
    dsin_match = dsin_fovs == gridPairs(ii).fov & ...
        dsin_wavelengths == gridPairs(ii).wl_nm;
    if ~any(dsin_match)
        needs_dsin(ii) = true;
    end
end
gridPairs(~needs_dsin) = [];

%% Add relevant data to live_data structure
for ii=1:numel(cal_vid_dir)
    
    
    
end
% live_data.calDB = 








end

