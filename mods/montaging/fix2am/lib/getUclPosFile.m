function posfile = getUclPosFile(locs)
%createUclPosFile 

% Current format of the UCL AM position file is
% Vidnum | nominal or absolute location (unused for this) | fov
poshead = {'num', 'loc', 'fov'};
numc = strcmpi(poshead, 'num');
locc = strcmpi(poshead, 'loc');
fovc = strcmpi(poshead, 'fov');

posfile = cell(size(locs.vidnums, 1), numel(poshead));
posfile(:, numc) = locs.vidnums;

for ii=1:size(locs.vidnums, 1)
%     posfile{ii, numc} = string(locs.vidnums{ii});
    
    % Process loc (whitespace)
    xy_str = locs.coords(ii, :);
    if iscell(xy_str)
        xy_str = xy_str{1};
    end
    posfile{ii, locc} = strrep(strrep(xy_str, ' ', ''), ',', ', ');
    % FOV to fringe
    posfile{ii, fovc} = locs.fovs(ii);
end


end

