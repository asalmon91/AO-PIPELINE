function [n_montage_px, n_connections, max_n_montage_px] = ...
    getMontageAreaAndUnits(psd_ffname, writeOutput)
%getMontageAreaAndUnits opens a montage photoshop file and binarizes it to
%determine the number of montage pixels and the number of connected pieces

psopendoc(fullfile(psd_ffname));
try
    pssetactivelayer('Background');
    pssetpixels(psgetpixels().*0)
catch me
    % No background, now we have to make one
    [w, h] = psdocinfo();
    psnewlayermatrix(zeros(h, w, 'uint8'));
    re = psjavascriptu('var layerRef = app.activeDocument.artLayers.getByName("Layer 1");');
    n = num2str(psnumlayers-1);
    re = psjavascriptu(['app.activeDocument.layers[0].move(app.activeDocument.layers[',n,'], ElementPlacement.PLACEAFTER);']);
    
    warning(me.message);
end
pspx_bin = psimread(fullfile(psd_ffname), true, true) > 0;

if exist('writeOutput', 'var') && ~isempty(writeOutput) && writeOutput
    [psd_path, psd_name, psd_ext] = fileparts(psd_ffname);
    imwrite(uint8(pspx_bin.*255), fullfile(psd_path, [psd_name, '-bin.tif']));
end

% pspx_bin = pspx > 0;

% Add a black border to enable automatic hole filling
pspx_bin = padarray(pspx_bin, [10, 10], 'both');
% pspx_bin = imfill(pspx_bin, 'holes'); % Don't fill holes because this
% removes real gaps. Actual 0s are very rare, but measuring real gaps is
% important. Obviously it would be better to get the transparency layer
% from the montage, but I can't figure out how to do that.

n_montage_px = numel(find(pspx_bin));

% Get connected components
cc = bwconncomp(pspx_bin, 8);
n_connections = cc.NumObjects;
max_n_montage_px = max(cellfun(@numel, cc.PixelIdxList));

end

