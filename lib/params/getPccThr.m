function pccThr = getPccThr(pcc_thr_ffname, mods)
%getPccThr Reads the results of ARFS PCC threshold training and matches the
%thresholds to the modalities

%% Read contents
txt_contents = tdfread(pcc_thr_ffname);
mod_list = cellstr(txt_contents.mod);
thr_list = txt_contents.thr;

%% Match PCC thresholds to their modality
pccThr = zeros(size(thr_list));
for ii=1:numel(mods)
    pccThr(ii) = thr_list(contains(mod_list, mods{ii}));
end

end

%% Archive
% This block was used when the pcc thresholds were stored in a .xlsx
% [~,~,raw] = xlsread(pcc_thr_ffname);
% mod_col = contains(raw(1,:), 'mod');
% thr_col = contains(raw(1,:), 'thr');
% mod_list = raw(2:end, mod_col);
% thr_list = raw(2:end, thr_col);
