function aviSet = filtOutDNP(aviSet, mods, wls)
%filtOutDNP Remove "do not process", usually direct and reflect
%   Include videos matching modality/wavelength pairings

for ii=1:numel(aviSet)
    remove = false(size(aviSet(ii).fnames));
    
    for jj=1:numel(aviSet(ii).fnames)
        remove(jj) = ~any(...
            strcmp(mods, aviSet(ii).mods{jj}) & ...
            wls == aviSet(ii).wl(jj));
    end
    
    % This is why each video needs to be its own object, lousy to have to
    % remove each field individually. It would be much better to be able to
    % do something like aviSet(ii).vids(remove) = [];
    aviSet(ii).fnames(remove)   = [];
    aviSet(ii).wl(remove)       = [];
    aviSet(ii).mods(remove)     = [];
end



end

