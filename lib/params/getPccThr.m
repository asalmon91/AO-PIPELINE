function pccThr = getPccThr(pcc_thr_ffname, mod_order)
%getPccThr Reads the results of ARFS PCC threshold training and matches the
%thresholds to the modalities

%% Default
DEF_PCC_THR = 0.01;

%% Read contents
txt_contents = tdfread(pcc_thr_ffname);
mod_list = cellstr(txt_contents.mod);
thr_list = txt_contents.thr;

%% Match PCC thresholds to their modality
pccThr = zeros(size(mod_order));
for ii=1:numel(mod_order)
    mod_idx = contains(mod_list, mod_order{ii});
    if ~any(mod_idx)
        pccThr(ii) = DEF_PCC_THR;
        warning('ARFS not trained on %s, default to threshold: %0.3f', ...
            mod_order{ii}, DEF_PCC_THR)
    else
        pccThr(ii) = thr_list(mod_idx);
    end
end

end
