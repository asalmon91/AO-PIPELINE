function [status, stdout] = deployUCL_AM(...
    py3_path, imgPath, posFFName, eyeLabel, outPath)
%deployUCL_AM runs call_auto_montage.py from the cmd line

% todo: read from .ini
py_fname        = 'call_auto_montage.py';
py_file_info    = dir(fullfile(mfilename('fullpath'), '..', py_fname));
py_path         = py_file_info.folder;

% Deconstruct position full file name into path and file name
[posPath, posName, posExt] = fileparts(posFFName);
posFname = [posName, posExt];

%% Construct string for command line
cmd_prompt = sprintf([...
    ... % Formatting string for cmd line evaluation
    '"%s" "%s" ', ... % Python version and Script full file name
    '--imgPath "%s" ', ... % Path to images
    '--posPath "%s" --posFname "%s" ', ... % Position file info
    '--eyeOX "%s" ', ...
    '--outPath "%s"'], ... % location to save .jsx
    ... % Input
    py3_path, ...
    fullfile(py_path, py_fname), ... % Script full file name
    imgPath, ... % Path to images
    posPath, posFname, ... % Position file info
    eyeLabel, ... % eye: OD or OS
    outPath); % location to save .jsx

%% Send to OS
[status, stdout] = system(cmd_prompt);


end

