function ini = checkFirstRun()
%checkFirstRun verifies pre-requisites
% todo: consider using venv for the UCL automontager
% todo: make some paths optional depending on the chosen pipeline
% todo: input arguments will be the set of chosen modules

%% Default
ini = [];

%% First check if the .ini file exists
INI_PATH = fullfile('C:', 'AOSLO-PIPE-INI');
ini_search = dir(fullfile(INI_PATH, '*ini.mat'));
if numel(ini_search) ~= 0
    ini_dates = [ini_search.datenum]';
    this_ini = ini_search(ini_dates == max(ini_dates));
    load(fullfile(INI_PATH, this_ini.name), 'ini');
    return;
end

%% Required programs
% python 2.7
% python 3.7
% Photoshop
% Guesses to their locations based on common default install paths
% todo: read this from a text file or something
guess(1).name = 'Python 2.7';
guess(1).path = {
    fullfile('C:', 'Python27', 'python.exe')};
guess(2).name = 'Python 3.7';
guess(2).path = {
    fullfile('C:', 'Python37', 'python.exe');
    fullfile('C:', 'Program Files', 'Python37', 'python.exe')};
guess(3).name = 'Adobe Photoshop';
guess(3).path = {
    fullfile('C:', 'Program Files', 'Adobe', 'Adobe Photoshop CS6 (64 Bit)', 'Photoshop.exe');
    fullfile('C:', 'Program Files (x86)', 'Adobe', 'Adobe Photoshop CS6', 'Photoshop.exe')};

% Find programs
ini = findPrograms(guess);

%% Write output
ts = datestr(datetime('now'), 'yyyymmddHHMMss');
out_fname = sprintf('%s-ini.mat', ts);
if exist(INI_PATH, 'dir') == 0
    mkdir(INI_PATH);
end
save(fullfile(INI_PATH, out_fname), 'ini');

end

