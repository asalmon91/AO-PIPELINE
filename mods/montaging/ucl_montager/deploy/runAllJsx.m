function jsx_fnames = runAllJsx(jsx_path)
%runAllJsx Runs all the .jsx files (photoshop script) in jsx_path
%   Are you worried that it won't wait until the jsx finishes processing
%   before opening a new one, potentially creating many instances of
%   photoshop all using up a lot of RAM and destroying your computer? Me
%   too!

JSX_EXT = '*.jsx';

jsx_dir = dir(fullfile(jsx_path, JSX_EXT));
jsx_fnames = {jsx_dir.name}';

for ii=1:numel(jsx_fnames)
    winopen(fullfile(jsx_path, jsx_fnames{ii}));
end

end

