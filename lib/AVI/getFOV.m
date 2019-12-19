function fov = getFOV(header_ffnames)
%getFOV extracts field-of-view from header
%   To our knowledge, only compatible with Savior v1.0 videos

%% Constants
SCAN_TAG    = 'optical_scanners_settings';
FOV_TAG     = 'resonant_scanner_amplitude_in_deg';

%% Allow header_ffnames to be char array or cell array
if ~isa(header_ffnames, 'cell')
    header_ffnames = {header_ffnames};
end

%% Load data
fov = zeros(size(header_ffnames));
for ii=1:numel(header_ffnames)
    load(header_ffnames{ii}, SCAN_TAG);
    fov(ii) = eval(sprintf('%s.%s', SCAN_TAG, FOV_TAG));
end

end

