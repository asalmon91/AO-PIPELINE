function ld = updateCalDB(ld, paths)
%updateCalDB updates the calibration database

%% Constants
VID_EXT = '.avi';
HEAD_EXT = '.mat';
DSIN_MAT_EXPR = 'desinusoid_matrix*.mat';

%% Check directory for videos and headers
cal_vid_dir = dir(fullfile(paths.cal, ['*', VID_EXT]));
avi_fnames = {cal_vid_dir.name}';
mat_fnames = strrep(avi_fnames, VID_EXT, HEAD_EXT);

% Check to see if video or header has been overwritten
% If nothing is new, we can return
if isempty(ld.cal)
    ld.cal.dsin = [];
else
    % todo
end

% Get FOV, wavelength, & orientation
fovs = getFOV(fullfile(paths.cal, mat_fnames));
wavelengths = getWavelength(mat_fnames);
orientations = getOrientation(mat_fnames);
horz = strcmp(orientations, 'horz');
vert = strcmp(orientations, 'vert');

% TODO
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
gridPairs(numel(h_avi_fnames), 1).fov = h_fovs(1);
for ii=1:numel(h_avi_fnames)
    gridPairs(ii).fov       = h_fovs(ii);
    gridPairs(ii).wl_nm     = h_wls(ii);
    gridPairs(ii).h_fname   = h_avi_fnames{ii};
    gridPairs(ii).v_fname   = v_avi_fnames{ii};
end

%% Check for existing desinusoid matrices
cal_dsin_dir = dir(fullfile(paths.cal, DSIN_MAT_EXPR));
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

%% Construct new desinusoid objects
new_dsin = repmat(dsin, numel(gridPairs), 1);
for ii=1:numel(new_dsin)
    new_dsin(ii).fov = gridPairs(ii).fov;
    new_dsin(ii).wavelength = gridPairs(ii).wl_nm;
    new_dsin(ii).h_filename = gridPairs(ii).h_fname;
    new_dsin(ii).v_filename = gridPairs(ii).v_fname;
end

%% Add relevant data to live_data structure
ld.cal.dsin = vertcat(ld.cal.dsin, new_dsin);

end

