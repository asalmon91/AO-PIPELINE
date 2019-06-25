function posfile = getPennPosFile(locs, fringes)
%createPennPosFile 

% Current format of the Penn AM position file is
% Vidnum | nominal location (unused for this) | abs coords | fringe
poshead = {'num', 'nom', 'loc', 'fringe'};
numc = strcmpi(poshead, 'num');
nomc = strcmpi(poshead, 'nom'); %#ok<NASGU>
locc = strcmpi(poshead, 'loc');
fringec = strcmpi(poshead, 'fringe');

posfile = cell(size(locs.vidnums, 1), numel(poshead));
posfile(:, numc) = locs.vidnums;

for ii=1:size(locs.vidnums, 1)
%     posfile{ii, numc} = string(locs.vidnums{ii});
    
    % Process loc (whitespace)
    posfile{ii, locc} = strrep(...
        strrep(locs.coords(ii, :), ' ', ''), ...
        ',', ', ');
    % FOV to fringe
    posfile{ii, fringec} = fringes(locs.fovs(ii) == fringes(:, 1), 2);
end



end

