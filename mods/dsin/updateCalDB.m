function ld = updateCalDB(ld, paths, opts)
%updateCalDB updates the calibration database

%% Constants
VID_EXT = '.avi';
HEAD_EXT = '.mat';
DSIN_MAT_EXPR = 'desinusoid_matrix*.mat';

%% Initialize
if isempty(ld.cal) || ~isfield(ld.cal, 'dsin')
    % Initialize and record most recent file
    ld.cal.dsin = [];
end

%% Update scaling information
lpmm = opts.lpmm;
me_f = opts.me_f_mm*1000; % convert to microns
for ii=1:numel(ld.cal.dsin)
    if isempty(ld.cal.dsin(ii).ppd)
        fringe = ld.cal.dsin(ii).fringe_px;
        ld.cal.dsin(ii).ppd = 1/(((1000/lpmm)/fringe/me_f)*(180/pi));
    end
end

%% Check directory for videos and headers
cal_vid_dir = dir(fullfile(paths.cal, ['*', VID_EXT]));
if isempty(cal_vid_dir)
    return;
end
avi_fnames = {cal_vid_dir.name}';
mat_fnames = strrep(avi_fnames, VID_EXT, HEAD_EXT);

%% Check if directory has any new files
if ~isfield(ld.cal, 'latest_datenum') || isempty(ld.cal.latest_datenum)
    ld.cal.latest_datenum = max([cal_vid_dir.datenum]);    
else
    % If nothing is new, we can return
    datenums = [cal_vid_dir.datenum];
    if ~any(datenums > ld.cal.latest_datenum)
        return;
    else % Update most recent file
        ld.cal.latest_datenum = max(datenums);
    end
end

%% Get FOV, wavelength, & orientation
fovs = getFOV(fullfile(paths.cal, mat_fnames));
wavelengths = getWavelength(mat_fnames);
orientations = getOrientation(mat_fnames);

%% Check for redundancy
remove = remove_redundant_cal_files(orientations, fovs, wavelengths, ...
    [cal_vid_dir.datenum]);
if any(remove)
    cal_vid_dir(remove)     = [];
    fovs(remove)            = [];
    wavelengths(remove)     = [];
    orientations(remove)    = [];
    avi_fnames(remove)      = [];
    mat_fnames(remove)      = [];
end

%% Remove unreadable files (most likely still being written)
remove = ~isReadable(paths.cal, avi_fnames);
if any(remove)
    cal_vid_dir(remove)     = [];
    fovs(remove)            = [];
    wavelengths(remove)     = [];
    orientations(remove)    = [];
    avi_fnames(remove)      = [];
    mat_fnames(remove)      = [];
end

%% Check for files that no longer exist
% TODO (not as important)

%% Pair up horizontal and vertical videos
gridPairs = pairHorzVert(orientations, fovs, wavelengths, avi_fnames);

%% Check for existing desinusoid matrices in database
remove = false(size(gridPairs));
for ii=1:numel(ld.cal.dsin)
    this_dsin = ld.cal.dsin(ii);
    fovs        = [gridPairs.fov]';
    wavelengths = [gridPairs.wl_nm]';
    h_fnames    = {gridPairs.h_fname}';
    v_fnames    = {gridPairs.v_fname}';
    remove(ii) = any(...
        this_dsin.fov == fovs & ...
        this_dsin.wavelength == wavelengths & ...
        strcmp(this_dsin.h_filename, h_fnames) & ...
        strcmp(this_dsin.v_filename, v_fnames));    
end
gridPairs(remove) = [];

%% Check for existing desinusoid matrices in directory
cal_dsin_dir = dir(fullfile(paths.cal, DSIN_MAT_EXPR));
dsin_fovs = [];
dsin_wavelengths = [];
if ~isempty(cal_dsin_dir)
    dsin_fovs = getFOV(fullfile(paths.cal, {cal_dsin_dir.name}'));
    dsin_wavelengths = getWavelength({cal_dsin_dir.name}');
end
% Remove the ones that are already in the database
if ~isempty(ld.cal.dsin)
    remove = false(size(cal_dsin_dir));
    for ii=1:numel(cal_dsin_dir)
        remove(ii) = any(dsin_fovs(ii) == [ld.cal.dsin.fov]' & ...
            dsin_wavelengths(ii) == [ld.cal.dsin.wavelength]');
    end
    cal_dsin_dir(remove) = [];
end

% Add remaining to database
new_dsin = repmat(dsin, numel(cal_dsin_dir), 1);
for ii=1:numel(new_dsin)
    dsin_data = load(fullfile(paths.cal, cal_dsin_dir(ii).name));
    
    new_dsin(ii).filename   = cal_dsin_dir(ii).name;
    new_dsin(ii).fov        = dsin_fovs(ii);
    new_dsin(ii).wavelength = dsin_wavelengths(ii);
    
    new_dsin(ii).h_filename = dsin_data.horizontal_fringes_filename;
    new_dsin(ii).v_filename = dsin_data.vertical_fringes_filename;
    
    new_dsin(ii).mat        = dsin_data.vertical_fringes_desinusoid_matrix;
    new_dsin(ii).fringe_px  = dsin_data.horizontal_fringes_fringes_period;
    new_dsin(ii).lpmm       = opts.lpmm;
    new_dsin(ii).processed  = true;
end
ld.cal.dsin = vertcat(ld.cal.dsin, new_dsin);

%% Determine if there are any grid pairs that don't have a
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
    new_dsin(ii).fov        = gridPairs(ii).fov;
    new_dsin(ii).wavelength = gridPairs(ii).wl_nm;
    new_dsin(ii).h_filename = gridPairs(ii).h_fname;
    new_dsin(ii).v_filename = gridPairs(ii).v_fname;
    new_dsin(ii).lpmm       = opts.lpmm;
end

%% Add relevant data to live_data structure
ld.cal.dsin = vertcat(ld.cal.dsin, new_dsin);

%% There must be some bug that is duplicating dsins, until it's squished,
% go through the database and remove any redundant dsins
% duplicates = false(size(ld.cal.dsin));
% for ii=1:numel(ld.cal.dsin)
%     for jj=1:numel(ld.cal.dsin)
%         
%     
%     end
% end
fprintf('There are currently %i dsin objects\n', numel(ld.cal.dsin));

end






