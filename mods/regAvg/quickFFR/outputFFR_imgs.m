function out_fnames = outputFFR_imgs(ffr_imgs, fids, ...
    out_path,in_fname)
%outputFFR_imgs Appends the filename with ARFS info and writes a .tif

% Get name parts for appending arfs info
[~,name,~] = fileparts(in_fname);
out_fnames = cell(size(ffr_imgs));
img_idx = 0;
for ii=1:numel(fids)
    for jj=1:numel(fids(ii).cluster)
        img_idx = img_idx +1;
        
        out_img = gather(uint8(ffr_imgs{img_idx}));
        
        out_fnames{img_idx} = sprintf('%s_ref_%i_L%iC%iN%i.tif', name, ...
            fids(ii).cluster(jj).fids(1), ...
            fids(ii).lid, fids(ii).cluster(jj).cid, ...
            numel(fids(ii).cluster(jj).fids));
        imwrite(out_img, fullfile(out_path, out_fnames{img_idx}), ...
            'compression', 'none');
        fprintf('Writing %s\n', out_fnames{img_idx});
    end
end







end

