function [status, stdout] = deployEMR(py2_path, imgPath, dmbPath, dmbFname)
%deployEMR runs emr_single.py from the cmd line on the specified .dmb/p

% todo: make dmbFname optional, and if not included, acts on all .dmp''s in
% dmbPath

%% DeMotion python scripts
calling_fx_ffname = mfilename('fullpath');
path_parts = strsplit(calling_fx_ffname, filesep);
py_path = calling_fx_ffname(1:end-numel(path_parts{end}));
emr_py_fname = 'emr_single.py';

%% Construct string for command line
cmd_prompt = sprintf([...
    ... % Formatting string for cmd line evaluation
    '"%s" "%s" ', ... % Python path and script full file name
    '--imgPath "%s" ', ... % Path to images
    '--dmbPath "%s" --dmbFname "%s"'], ... % .dmb file info
    ... % Input
    py2_path, ... % Python path
    fullfile(py_path, emr_py_fname), ... % Script full file name
    imgPath, ... % Path to images
    dmbPath, dmbFname);

%% Send to OS
[status, stdout] = system(cmd_prompt);

end

