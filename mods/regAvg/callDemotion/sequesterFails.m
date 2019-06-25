function sequesterFails(in_path, fail_fname)
%sequesterFails Moves failed files into a fail folder

fail_path = fullfile(in_path, 'fail');
if exist(fail_path, 'dir') == 0
    mkdir(fail_path);
end
movefile(fullfile(in_path, fail_fname), fail_path, 'f')

end

