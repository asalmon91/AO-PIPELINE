function conds = getConds(root_dir)
%getConds outputs a cell array of condition labels given a root directory
% (e.g., {'1-ctrl', '2-achm', '3-alb'} 

root_dirs = dir(root_dir);
ignore = {'.', '..'};
isfolders = [root_dirs.isdir];
root_dirs(~isfolders) = [];
root_dirs = {root_dirs.name}';
root_dirs(contains(root_dirs, ignore)) = [];
conds = root_dirs;

end

