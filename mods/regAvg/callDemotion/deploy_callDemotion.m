function [status, stdout] = deploy_callDemotion(...
    py2_path, dmb_path, dmb_fname, outputImages)
%deploy_callDemotion calls a python script which contains the relevant
%registration and averaging modules in Demotion

%% Send .dmb to DeMotion
calling_fx_ffname = mfilename('fullpath');
path_parts = strsplit(calling_fx_ffname, filesep);
py_path = calling_fx_ffname(1:end-numel(path_parts{end}));
dmp_py_fname = 'callDemotion.py';

% Build string to send to cmd line
cmd_prompt = sprintf('"%s" "%s" -p "%s" -n "%s" -o %i', ...
    py2_path, ... % Python 2.7 path
    fullfile(py_path, dmp_py_fname), ... % Script full file name
    dmb_path, dmb_fname, ... % path, name
    outputImages); % Write images

%% Send to OS
[status, stdout] = system(cmd_prompt);

end

