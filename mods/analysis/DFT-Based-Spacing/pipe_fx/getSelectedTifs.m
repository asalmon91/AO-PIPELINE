function tif_fnames = getSelectedTifs(in_path, modality, wavelength)
%getSelectedTifs filters the tifs in the folder by modality and wavelength

%% Find all tifs
tif_search = dir(fullfile(in_path, '*.tif'));
if numel(tif_search) == 0
    error('No .tif''s found');
end

tif_fnames = {tif_search.name}';
mod_filter = contains(tif_fnames, sprintf('_%s_', modality));
wl_filter = contains(tif_fnames, sprintf('_%inm_', wavelength));

tif_fnames = tif_fnames(mod_filter & wl_filter);

end

