function aviSets = updateAviSets(aviSets, in_path)
%updateAviSets updates an existing aviSet array, rather than starting from
%scratch

for ii=1:numel(aviSets)
    % Update file names
    search = dir(fullfile(in_path, sprintf('*_%s.avi', aviSets(ii).num)));
    aviSets(ii).fnames = {search.name}';
end

% Update other information
aviSets = getFOV(in_path, aviSets);
aviSets = getMods(aviSets);
aviSets = getWavelength(aviSets);

end

