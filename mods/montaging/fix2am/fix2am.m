%% Convert Fixation GUI output to Automontager Input
% Created - 2018.12.17 - Alex Salmon

%% Imports
addpath('.\lib');
addpath('.\templates');

%% Get file and preferences
% Get .csv
[csv_fname, csv_path] = uigetfile('*.csv', 'Select fixation data file', ...
    'multiselect', 'off');
if isnumeric(csv_fname)
    return;
end

% todo: validate csv type

% Get output type (Penn or UCL)
% todo: handle different versions of each AM
% todo: when this is part of the automated pipeline, get this data from
% pipeline object
re = questdlg('Penn or UCL', 'Which Automontager?', ...
    'Penn', 'UCL', 'Both', 'Penn');

% Penn requires desinusoid files
if strcmpi(re, 'Penn') || strcmpi(re, 'Both')
    [cal_fnames, cal_path] = uigetfile('*.mat', ...
        'Select ALL desinusoid files', csv_path, ...
        'multiselect', 'on');
    if isnumeric(cal_fnames)
        return;
    end
    if ~iscell(cal_fnames)
        cal_fnames = {cal_fnames};
    end
    cal_fnames = cal_fnames';
end


%% Waitbar
wb = waitbar(0, sprintf('Loading %s', csv_fname));
wb.Children.Title.Interpreter = 'none';

%% Read, process file
loc_data = processLocFile(csv_path, csv_fname);

if strcmpi(re, 'Penn') || strcmpi(re, 'Both')
    fringe_tbl = getFringes(cal_path, cal_fnames);
    posfile = getPennPosFile(loc_data, fringe_tbl);
    ok = writePosFile(...
        csv_path, 'pf_v1_ID_yyyymmdd_OX_Penn.xlsx', ...
        posfile, 'penn.xlsx');
end
if strcmpi(re, 'UCL') || strcmpi(re, 'Both')
    posfile = getUclPosFile(loc_data);
    ok = writePosFile(...
        csv_path, 'pf_v1_ID_yyyymmdd_OX_UCL.xlsx', ...
        posfile, 'ucl.xlsx');    
end

% End of script







