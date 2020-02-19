% Launch PIPE
% Imports, and initializes GUI

m = msgbox('Initializing the AOSLO pipeline', 'Initializing', 'help');
addpath(genpath('classes'), genpath('mods'), genpath('lib'));
pipe_progress_App;
if isvalid(m)
    close(m);
end