function [status, errs] = par_create_mods(in_path, direct_fnames, do_par)
%par_create_mods Parallel process creation of split and avg videos

%% Constants
MIN_N_VIDS = 13;

%% Defaults
status  = false(size(direct_fnames));
errs    = cell(size(direct_fnames));
% if exist(do_par, 'var') == 0 || isempty(do_par)
%     do_par = true;
% end

%% Parallel process if necessary
if exist('parfor', 'builtin') ~= 0 && numel(direct_fnames) > MIN_N_VIDS && ... 
        do_par
    parfor ii=1:numel(direct_fnames)
        [status(ii), errs{ii}] = fn_create_split_avg(...
            in_path, direct_fnames{ii});
    end
else
    for ii=1:numel(direct_fnames)        
        [status(ii), errs{ii}] = fn_create_split_avg(...
            in_path, direct_fnames{ii});
    end
end

end

