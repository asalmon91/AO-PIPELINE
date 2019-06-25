function [prime_mod, prime_lambda] = getModLambda()
%getModLambda gets user input on the order of modalities and wavelengths

N_CHANNELS = 16;
C_LABELS = {'Modality','Wavelength (nm)', 'Use'};
DEF_DATA = cell(N_CHANNELS, numel(C_LABELS));

% Add check boxes to turn channels off
DEF_USE = false(N_CHANNELS, 1);
DEF_USE([1,3,4]) = true;
DEF_DATA(:, strcmpi(C_LABELS, 'use')) = num2cell(DEF_USE);

% Add modalities
DEF_MODS = {'confocal'; 'confocal'; 'split_det'; 'avg'};
DEF_DATA(1:numel(DEF_MODS), strcmpi(C_LABELS, 'modality')) = DEF_MODS;

% Add wavelengths
DEF_WL = [790; 680; 790; 790];
DEF_DATA(1:numel(DEF_WL), strcmpi(C_LABELS, 'wavelength (nm)')) = ...
    num2cell(DEF_WL);
% 
% def_data = horzcat(DEF_MODS, num2cell(DEF_WL), num2cell(DEF_USE));
% def_data = vertcat(def_data, ...
%     cell(N_CHANNELS - size(def_data,1), size(def_data,2)));
% 
% fig = figure;
% uit = uitable(fig, 'data', def_data, 'columnname', C_LABELS);
% uit.ColumnEditable = true;
% 
% while isvalid(fig)
%     out_table = uit.Data;
% end




end

