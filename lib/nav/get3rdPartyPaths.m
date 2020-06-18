function ini = get3rdPartyPaths(root_path)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% Remove function name from root path
root_path = root_path(1:max(strfind(root_path, filesep)));

%% Required programs
% python 2.7
% python 3.7
% Photoshop
% Guesses to their locations based on common default install paths
% todo: read this from a text file or something

% Python 2.7, required for DeMotion and Eye-motion-repair
guess(1).name = 'Python 2.7';
guess(1).path = {
    fullfile('C:', 'Python27', 'python.exe')};

% Python 3.7 required for UCL Automontager
guess(2).name = 'Python 3.7';
guess(2).path = {
    fullfile('C:', 'Python37', 'python.exe');
    fullfile('C:', 'Program Files', 'Python37', 'python.exe')};

% Create .dmb files python script
guess(3).name = 'createDmb';
search_results = subdir(fullfile(root_path, 'mods', '*createDmb.py'));
% todo: handle unexpected results from recursive file search
guess(3).path = {search_results(1).name};

% Process .dmb files python script
guess(4).name = 'callDemotion';
search_results = subdir(fullfile(root_path, 'mods', '*callDemotion.py'));
guess(4).path = {search_results(1).name};

% Re-process from .dmp python script
guess(5).name = 'reprocessWithDMP';
search_results = subdir(fullfile(root_path, 'mods', '*reprocessWithDMP.py'));
guess(5).path = {search_results(1).name};

% UCL Automontager
guess(6).name = 'UCL_AM';
search_results = subdir(fullfile(root_path, 'mods', '*call_auto_montage.py'));
guess(6).path = {search_results(1).name};


% Find programs
ini = findPrograms(guess);


end

