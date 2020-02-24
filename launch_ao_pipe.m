% Launch PIPE
% Imports, and initializes GUI

wb = waitbar(0, 'Initializing the AOSLO pipeline');
addpath(genpath('classes'), genpath('mods'), genpath('lib'));
pipe_progress_App;
if isvalid(wb)
    close(wb);
end
clear wb;