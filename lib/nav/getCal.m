function cal_lut = getCal(in_path)
%getCal Determines the desinusoid files to use based on the fov information in dmb
%   The goal here is to read in the desinusoid files, read which files were used, then get the
%   fov information from those files in order to match the fov to the desinusoid file.
%   this is necessary because filename parsing of the desinusoid file, historically, has been problematic.
%   Alex Salmon - 2016.06.17
%   Modified - 2018.11.07 to make wb optional - Alex Salmon
%   Modified - 2019.04.18 for use with AO-PIPE

%% Constants
H_FNAME_LABEL   = 'horizontal_fringes_filename';
V_FNAME_LABEL   = 'vertical_fringes_filename';
SCANNER_LABEL   = 'optical_scanners_settings';
FOV_LABEL       = 'raster_scanner_amplitude_in_deg';
FRINGE_LABEL    = 'vertical_fringes_fringes_period';
DSIN_MATRIX_TAG = 'vertical_fringes_desinusoid_matrix';

%% Load all .mat data in the directory
cal_dir = dir(fullfile(in_path, '*.mat'));
for ii=1:numel(cal_dir)
    cal_dir(ii).data = load(fullfile(in_path, cal_dir(ii).name));
end

%% Determine if a .mat is a desinusoid file or a video header
is_cal_file     = false(size(cal_dir));
is_head_file    = is_cal_file;
for ii=1:numel(cal_dir)
    
    if isfield(cal_dir(ii).data, H_FNAME_LABEL)
        % Desinusoid file
        is_cal_file(ii) = true;
        
    elseif isfield(cal_dir(ii).data, SCANNER_LABEL)
        % Video header
        is_head_file(ii) = true;
    end
end

%% Sort into Desinusoid files and Video headers
cal = cal_dir(is_cal_file);
head_data = cal_dir(is_head_file);
clear cal_dir; % Don't need anything else

%% Prepare Calibration look-up table (only relevant information)
cal_lut(numel(cal)).fname = cal(end).name;
remove = false(size(cal));
for ii=1:numel(cal)
    cal_lut(ii).fname       = cal(ii).name;
    cal_lut(ii).fringe      = getfield(cal(ii).data, FRINGE_LABEL); %#ok<*GFLD>
    cal_lut(ii).dsin_matrix = single(...
        getfield(cal(ii).data, DSIN_MATRIX_TAG));
    
    % Try to find FOV from associated headers
    h_fname = strrep(...
        getfield(cal(ii).data, H_FNAME_LABEL), '.avi', '.mat');
    v_fname = strrep(...
        getfield(cal(ii).data, V_FNAME_LABEL), '.avi', '.mat');
    
    h_data = head_data(strcmp({head_data.name}', h_fname)).data; %#ok<*NASGU>
    v_data = head_data(strcmp({head_data.name}', v_fname)).data;
    
    h_fov = eval(sprintf('h_data.%s.%s', SCANNER_LABEL, FOV_LABEL));
    v_fov = eval(sprintf('v_data.%s.%s', SCANNER_LABEL, FOV_LABEL));
    
    cal_lut(ii).fov = h_fov;
    
    % Check to see if they match
    if h_fov ~= v_fov
        warning('FOV mismatch in %s, %1.2f & %1.2f', ...
            cal(ii).name, h_fov, v_fov);
        remove(ii) = true;
    end
end

%% Remove any failures
cal_lut(remove) = [];


end

