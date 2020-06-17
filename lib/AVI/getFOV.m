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
        meta_data = persistent_load(header_ffnames{ii});
        
        if isfield(meta_data, SCAN_TAG) % AOSLO video header
            fov(ii) = eval(sprintf('meta_data.%s.%s', SCAN_TAG, FOV_TAG));
        else % Try to extract from file name
            name_parts  = strsplit(names{ii}, '_');
            fov_token   = name_parts{find(strcmpi(name_parts, 'deg'))-1};
            fov(ii)     = str2double(strrep(fov_token, 'p', '.'));
        end
    else % todo: DRY violation, fix
        name_parts  = strsplit(names{ii}, '_');
		if any(strcmpi(name_parts, 'deg')) % See if they helped out by adding a deg token
			fov_token = name_parts{find(strcmpi(name_parts, 'deg'))-1};
		else % More often, this is skipped and they just have something like _1p00_
			try
				fov_token = name_parts{~cell2mat(...
					cellfun(@isempty, regexp(name_parts, '\d+p\d+'), 'uniformoutput', false)...
					)};
			catch
				warning('Failed to determine FOV for %s', names{ii});
				fov(ii) = 0;
			end
		end
		fov(ii) = str2double(strrep(fov_token, 'p', '.'));
    end
end

end

