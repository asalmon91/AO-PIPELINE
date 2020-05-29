function gridPairs = pairHorzVert(orientations, fovs, wavelengths, fnames)
%pairHorzVert pairs up horizontal and vertical grid videos

%% Default
gridPairs = [];

%% Get horizontal files and match to vertical
% fov and wavelength must match
horz = strcmp(orientations, 'horz');
vert = strcmp(orientations, 'vert');
h_fovs = fovs(horz);
h_wls  = wavelengths(horz);
v_fovs = fovs(vert);
v_wls  = wavelengths(vert);
h_avi_fnames = fnames(horz);
v_avi_fnames = fnames(vert);
order = zeros(size(h_avi_fnames));
remove = false(size(h_avi_fnames));
for ii=1:numel(h_avi_fnames)
    match_idx = find(v_fovs == h_fovs(ii) & v_wls == h_wls(ii));
    if isempty(match_idx) % No match found
        remove(ii) = true;
        % todo: should probably warn user somehow
        warning('No matching vertgrid found for %s', ...
            h_avi_fnames{ii});
    else
        order(ii) = match_idx;
    end
end
% Remove horizontal components with no match
h_avi_fnames(remove)    = [];
h_fovs(remove)          = [];
h_wls(remove)           = [];
order(remove)           = [];
if isempty(h_avi_fnames)
    return;
end

% Re-order vertical files so that they match the horizontal order
v_avi_fnames = v_avi_fnames(order);

%% Construct grid pair structure
gridPairs(numel(h_avi_fnames), 1).fov = h_fovs(1);
for ii=1:numel(h_avi_fnames)
    gridPairs(ii).fov       = h_fovs(ii);
    gridPairs(ii).wl_nm     = h_wls(ii);
    gridPairs(ii).h_fname   = h_avi_fnames{ii};
    gridPairs(ii).v_fname   = v_avi_fnames{ii};
end


end

