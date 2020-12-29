function [mon_scale_ppd, vn, N] = getMontageScale(mon_ffname, db)
%getMontageScale 

load(mon_ffname, 'inData', 'N');
inData = inData(1,:)'; % only need first modality

%% Get FOVs included in montage
fovs = zeros(size(inData));
vn = fovs;
for ii=1:numel(inData)
    for jj=1:numel(db.vid.vid_set)
        vid_fnames = db.vid.vid_set(jj).getAllFnames;
        % Remove extension
        vid_names = cellfun(@(x) x(1:strfind(x, '.avi')-1), ...
            vid_fnames, 'UniformOutput', false);
        
        if any(contains(inData{ii}, vid_names))
            fovs(ii) = db.vid.vid_set(jj).fov;
            vn(ii) = db.vid.vid_set(jj).vidnum;
            break;
        end
    end
end
min_fov = min(fovs);
vn = unique(vn);

%% Get PPD for this FOV
mon_scale_ppd = db.cal.dsin( [db.cal.dsin.fov] == min_fov).ppd;

end

