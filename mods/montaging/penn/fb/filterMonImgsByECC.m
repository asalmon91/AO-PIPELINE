function tif_fnames = filterMonImgsByECC(db, paths, opts, ecc)
%filterMonImgsByECC returns a list of images that are within a certain
%eccentricity

%% Optional inputs
if exist('ecc', 'var') == 0 || isempty(ecc)
    ecc = 3; % Degrees
end

%% Get images less than ecc from 0,0
loc_idx = pdist2([0,0], fixCoordsToMat(db.mon.loc_data.coords)) <= ecc;
vn = str2double(db.mon.loc_data.vidnums(loc_idx));

% Select channel based on subject
% todo: Select channel based on subject

% Get all the images with these video numbers
tif_fnames = getSelectedTifs(paths.mon_out, ...
    opts.mod_order{1}, opts.lambda_order(1));
remove = false(size(tif_fnames));
for ii=1:numel(tif_fnames)
    key = matchImgToVid(db.vid.vid_set, tif_fnames{ii});
    remove(ii) = ~ismember(db.vid.vid_set(key(1)).vidnum, vn);
end
tif_fnames(remove) = [];
% Could also crop them


end

