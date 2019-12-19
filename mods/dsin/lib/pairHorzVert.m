function gridPairs = pairHorzVert(in_path)
%pairHorzVert pairs up horizontal and vertical grid videos
% todo: include default wavelength as optional input arg

%% Constants
SCAN_TAG    = 'optical_scanners_settings';
FOV_TAG     = 'resonant_scanner_amplitude_in_deg';

%% Get .avi's and .mat's
avi_dir = dir(fullfile(in_path, '*.avi'));
avi_fnames = {avi_dir.name}';
mat_fnames = strrep(avi_fnames, '.avi', '.mat');

%% Get all FOVs
fovs = zeros(size(mat_fnames));
for ii=1:numel(mat_fnames)
    scan_data = load(fullfile(in_path, mat_fnames{ii}), SCAN_TAG); %#ok<NASGU>
    fovs(ii) = eval(sprintf('scan_data.%s.%s', SCAN_TAG, FOV_TAG));
end

%% Sort into horizontal and vertical by filename
% Not ideal, but there's no metadata for this
% Could try fitting horizontal sinusoid to each and sorting by R2... but
% this seems excessive
is_horz = (contains(avi_fnames, 'horz', 'IgnoreCase', true));

% Check for issues
if numel(find(is_horz)) ~= numel(find(~is_horz))
    warning('Mismatch in # horz & vert videos; may fail');
elseif ~any(is_horz)
%     winopen(in_path);
    warning('No files containing "horz" found');
    gridPairs = [];
    return;
end

% Sort
h_fovs = fovs(is_horz);
v_fovs = fovs(~is_horz);
h_avi_fnames = avi_fnames(is_horz);
v_avi_fnames = avi_fnames(~is_horz);

%% Match by FOV then by file name
fails = false(size(h_fovs));
gridPairs(numel(h_fovs)).fov = h_fovs(end);
for ii=1:numel(h_fovs)
    v_fnames_w_same_fov = v_avi_fnames(v_fovs == h_fovs(ii));
    
    % Remove video number from name
    name_parts = strsplit(h_avi_fnames{ii}, '_');
    h_name_wo_num = strjoin(name_parts(1:end-1), '_');
    
    % See if just one of the vertical videos matches this name after
    % replacing horz with vert
    match_results = contains(v_fnames_w_same_fov, ...
        strrep(h_name_wo_num, 'horz', 'vert'));
    
    fails(ii) = numel(find(match_results)) ~= 1;
    if fails(ii)
        warning('Matching failed for %s', h_avi_fnames{ii});
        continue;
    end
    
    %% Extract wavlength from file name
    % todo: make this a function
    expr_start  = '[_]\d+nm[_]';
    expr_end    = 'nm[_]';
    wl_start    = regexp(h_avi_fnames{ii}, expr_start);
    wl_end      = regexp(h_avi_fnames{ii}, expr_end);
    try
        wl = str2double(h_avi_fnames{ii}(wl_start+1 : wl_end -1));
        if isnan(wl)
            wl = 790;
        end
    catch
        wl = 790;
    end
    
    %% Add to output
    gridPairs(ii).fov = h_fovs(ii);
    gridPairs(ii).wl_nm = wl;
    gridPairs(ii).h_fname = h_avi_fnames{ii};
    gridPairs(ii).v_fname = v_fnames_w_same_fov{match_results};
end

%% Remove failures
gridPairs(fails) = [];


end

