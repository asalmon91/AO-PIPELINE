function ini = findPrograms(guess)
%findPrograms 

% Check if it exists, if not, maybe it's 32-bit, try switching program
% files, if all else fails, ask the user
ini(numel(guess)).path = '';
for ii=1:numel(guess)
    ini(ii).name = guess(ii).name;
    
    path_found = false;
    for jj=1:numel(guess(ii).path)
        if exist(guess(ii).path{jj}, 'file') ~= 0
            path_found = true;
            ini(ii).path = guess(ii).path{jj};
            break;
        end
    end
    if ~path_found % Ask user for help
        [~, name, ext] = fileparts(guess(ii).path{1});
        
        [usr_fname, usr_path] = uigetfile([name, ext], ...
            sprintf('Locate %s or cancel to quit', guess(ii).name), ...
            'multiselect', 'off');
        if isnumeric(usr_fname)
            return;
        else
            ini(ii).path = fullfile(usr_path, usr_fname);
        end
    end
end

end

