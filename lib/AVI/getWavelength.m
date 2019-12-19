function wavelengths = getWavelength(fnames)
%getWavelength Extracts wavelength from file name and adds the field
% Only succeeds if wavelength is in filename and the units are nm
% Returns NaN if not found

if ~iscell(fnames)
    fnames = {fnames};
end

% Search for an underscore surrounded set of digits followed by nm
expr_start = '[_][\d]+nm[_]';
expr_end = 'nm[_]';

wl_starts = cellfun(@(x) regexp(x, expr_start), fnames, ...
    'uniformoutput', false);
wl_ends = cellfun(@(x) regexp(x, expr_end), fnames, ...
    'uniformoutput', false);
wavelengths = str2double(cellfun(@(x, y, z) x(y+1:z-1), ...
    fnames, wl_starts, wl_ends, ...
    'uniformoutput', false));

end

