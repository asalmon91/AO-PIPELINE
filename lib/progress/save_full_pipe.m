function save_full_pipe(pipe_data, opts, paths)
%save_full_pipe saves useful variables

if exist(fullfile(paths.root, pipe_data.filename), 'file') == 0
    save(fullfile(paths.root, pipe_data.filename), ...
        'pipe_data', 'opts', 'paths');
else
    save(fullfile(paths.root, pipe_data.filename), ...
        'pipe_data', 'opts', 'paths', '-append');
end

end

