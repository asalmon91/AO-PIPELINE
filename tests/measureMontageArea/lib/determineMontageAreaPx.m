function n_px = determineMontageAreaPx(png_ffname)
%determineMontageAreaPx just checks the transparency layer for 1s

%% Read transparency layer
[~,~,alpha_layer] = imread(png_ffname);
n_px = numel(find(alpha_layer == 1)); % convert to logical to save space

end

