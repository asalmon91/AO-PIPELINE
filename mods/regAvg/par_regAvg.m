function [status, msgs] = par_regAvg(root_path, raw_path, cal_path, ...
    aviSet, dsins, mods, wls)
%regAvg chooses parallel or serial processing

% Default outputs
status = false(size(aviSet));
msgs = cell(size(aviSet));

%% Get trained ARFS parameters
% todo: make optional
u_mods = unique(mods);
pcc_thrs = getPccThr(...
    fullfile('mods', 'ARFS', 'pcc_thresholds.xlsx'), u_mods);

% Just check if parfor can be used
if exist('parfor', 'builtin') ~= 0
    parfor ii=1:numel(aviSet)
        [status(ii), msgs{ii}] = regAvg(...
            root_path, raw_path, cal_path, aviSet(ii), dsins, mods, wls, pcc_thrs);
    end
else
    for ii=1:numel(aviSet)
        [status(ii), msgs{ii}] = regAvg(...
            root_path, raw_path, cal_path, aviSet(ii), dsins, mods, wls, pcc_thrs);
    end
end

end

