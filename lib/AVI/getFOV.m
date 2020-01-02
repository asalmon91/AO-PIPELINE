function fov = getFOV(header_ffnames)
%getFOV extracts field-of-view from header
%   To our knowledge, only compatible with Savior v1.0 videos

%% Constants
SCAN_TAG    = 'optical_scanners_settings';
FOV_TAG     = 'resonant_scanner_amplitude_in_deg';

%% Allow header_ffnames to be char array or cell array
if ~iscell(header_ffnames)
    header_ffnames = {header_ffnames};
end

% Throw error if file type is not .mat
[~,names,exts] = cellfun(@fileparts, header_ffnames, 'uniformoutput', false);
if ~all(strcmpi(exts, '.mat'))
    error('Invalid file type, must be .mat')
end

%% Load data
fov = zeros(size(header_ffnames));
for ii=1:numel(header_ffnames)
    if exist(header_ffnames{ii}, 'file') ~= 0
        meta_data = load(header_ffnames{ii});
        if isfield(meta_data, SCAN_TAG) % AOSLO video header
            fov(ii) = eval(sprintf('meta_data.%s.%s', SCAN_TAG, FOV_TAG));
        else % Try to extract from file name
            name_parts  = strsplit(names{ii}, '_');
            fov_token   = name_parts{find(strcmpi(name_parts, 'deg'))-1};
            fov(ii)     = str2double(strrep(fov_token, 'p', '.'));
        end
    else % todo: DRY violation, fix
        name_parts  = strsplit(names{ii}, '_');
        fov_token   = name_parts{find(strcmpi(name_parts, 'deg'))-1};
        fov(ii)     = str2double(strrep(fov_token, 'p', '.'));
    end
end

end

