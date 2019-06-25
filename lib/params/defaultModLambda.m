function DEF_DATA = defaultModLambda()
%defaultModLambda gets user input on the order of modalities and wavelengths

% Change these to adjust defaults
N_CHANNELS = 16;
DEF_MODS = {'confocal'; 'confocal'; 'split_det'; 'avg'};
DEF_WL = [790; 680; 790; 790];
DEF_USE = false(N_CHANNELS, 1);
DEF_USE([1,3,4]) = true;

% Add labels
C_LABELS = {'Modality','Wavelength (nm)', 'Use'};
DEF_DATA = cell(N_CHANNELS, numel(C_LABELS));

% Add check boxes to turn channels off
DEF_DATA(:, strcmpi(C_LABELS, 'use')) = num2cell(DEF_USE);

% Add modalities
DEF_DATA(1:numel(DEF_MODS), strcmpi(C_LABELS, 'modality')) = DEF_MODS;

% Add wavelengths
DEF_DATA(1:numel(DEF_WL), strcmpi(C_LABELS, 'wavelength (nm)')) = ...
    num2cell(DEF_WL);
end

