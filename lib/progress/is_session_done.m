function session_complete = is_session_done(in_path)
%is_session_done checks if a done.txt file exists indicating session
%completion

session_complete = exist(fullfile(in_path, 'done.txt'), 'file') ~= 0;

end

