function status = writePosFile(out_path, out_fname, posfile, template)
%writePosFile 
% todo: format the output name automatically with
% pf_v_ID_yyyymmdd_OX

% Get template
this_ffname = mfilename('fullpath');
[this_path, ~, ~] = fileparts(this_ffname);
copyfile(fullfile(this_path, '..', 'templates', template), ...
    fullfile(out_path, out_fname));

status = xlswrite(fullfile(out_path, out_fname), posfile);

end

