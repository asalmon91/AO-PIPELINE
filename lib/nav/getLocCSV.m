function [loc_ffname, loc_type] = getLocCSV(in_path)
%getLocCSV finds a .csv named "locations.csv" within in_path
% todo: better search
% todo: check format to make sure it matches expectations
% todo: needs to match all video numbers, aviSets will need to be input

search_opts = {
    fullfile(in_path, '*ocations.csv'); % Humans
    fullfile(in_path, '..', 'Imaging_Notes*.xlsx'); % Animals
    fullfile(in_path, 'locations.xlsx') % created for testing
    };

loc_types = {
    'human';
    'animal';
    'human'
    };

for ii=1:numel(search_opts)
    search_results = dir(search_opts{ii});
    if numel(search_results) == 1
        break
    elseif numel(search_results) > 1
        error('Expected 1 location file, found %i.', ...
            numel(search_results));
    elseif ii == numel(search_opts) && numel(search_results) == 0
        error('Location file never found');
    end
end

loc_ffname = fullfile(search_results.folder, search_results.name);
loc_type = loc_types{ii};

end

