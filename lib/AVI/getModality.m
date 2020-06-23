function aviSet = getModality(aviSet)
%getMods Extracts the modalities from the file name
            
for ii=1:numel(aviSet)
    % Separate by underscore
    sep_fnames = cellfun(@(x) strsplit(x, '_'), aviSet(ii).fnames, ...
        'uniformoutput', false);
    % Modality token will always be 2nd last
    mods = cellfun(@(x) x{end-1}, sep_fnames, ...
        'uniformoutput', false);
    % Replace 'det' with 'split_det' (dumb)
    aviSet(ii).mods = cellfun(@(x) strrep(x, 'det', 'split_det'), mods, ...
        'uniformoutput', false);
end

end

