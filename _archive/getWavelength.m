function aviSet = getWavelength(aviSet)
%getWavelength Extracts wavelength from file name and adds the field

% Search for an underscore surrounded set of digits followed by nm
expr_start = '[_][\d]+nm[_]';
expr_end = 'nm[_]';

for ii=1:numel(aviSet)
    wl_starts = cellfun(@(x) regexp(x, expr_start), aviSet(ii).fnames, ...
        'uniformoutput', false);
    wl_ends = cellfun(@(x) regexp(x, expr_end), aviSet(ii).fnames, ...
        'uniformoutput', false);
    aviSet(ii).wl = str2double(cellfun(@(x, y, z) x(y+1:z-1), ...
        aviSet(ii).fnames, wl_starts, wl_ends, ...
        'uniformoutput', false));
end

end

