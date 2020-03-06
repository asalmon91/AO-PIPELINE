function save_full_pipe(pipe_data, opts, paths)
%save_full_pipe saves useful variables

save(fullfile(paths.root, pipe_data.filename), ...
    'pipe_data', 'opts', 'paths');

end

