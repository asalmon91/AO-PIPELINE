function out_path = guessPath(root_dir, subdir_name)
%guessPath guesses at a subdirectory name, checks if it exists

out_path = fullfile(root_dir, subdir_name);
if exist(out_path, 'dir') == 0 % Try lowercase
    contents = dir(root_dir);
    contents = {contents([contents.isdir]).name}';
    search_contents = strcmpi(contents, subdir_name);
    if any(search_contents)
        out_path = fullfile(root_dir, contents{search_contents});
    else
        warning('Could not find subdirectory in %s', root_dir);
    end
end
 
end

