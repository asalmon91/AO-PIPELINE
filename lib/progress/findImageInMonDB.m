function key = findImageInMonDB(ld, img_fnames)
%findImageInMonDB returns the index of the montage database that contains
%this image

%% Constants
% todo: will break without confocal
DEF_MOD = 'confocal';

%% Shortcuts
montages = ld.mon.montages;

%% Filter out non-primary
remove = ~contains(img_fnames, DEF_MOD);
img_fnames(remove) = [];
key = zeros(numel(img_fnames), 2); % montage database has 2 levels
for ff=1:numel(img_fnames)
    
    for ii=1:numel(ld.mon.montages)
        % Get all image names
        all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false)';
        [~, all_names, all_exts] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
        all_fnames = cellfun(@(x,y) [x,y], all_names, all_exts, 'uniformoutput', false);
        
        txfm_idx = find(strcmp(img_fnames{ff}, all_fnames));
        if ~isempty(txfm_idx)
            key(ff, :) = [ii, txfm_idx];
        end
    end
end


end

