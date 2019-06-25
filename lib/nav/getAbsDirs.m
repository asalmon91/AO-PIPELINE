function absDirs = getAbsDirs(srch_path)
%getAbsDirs returns a cell array containing the names of folders in
%srch_path excluding the relative . and .. paths

dirs = dir(srch_path);

absDirs = {dirs([dirs.isdir]' & ...
    ~strcmp({dirs.name}', '.') & ...
    ~strcmp({dirs.name}', '..')).name}';

end

