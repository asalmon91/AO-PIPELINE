function [ffr_imgs, fids] = quickFFR(vid, fids)
%quickFFR performs an NCC-based full-frame registration

% Create NCC mask to mitigate edge-artefacts
ncc_mask = false(size(vid(:,:,1))*2-1);
if isa(vid, 'gpuArray')
    ncc_mask = gpuArray(ncc_mask);
end
ncc_mask(...
    round(size(vid,1)/4:end-size(vid,1)/4+1), ...
    round(size(vid,2)/4:end-size(vid,2)/4+1)) = true;

% Determine total number of images
nn = 0;
for ii=1:numel(fids)
    nn = nn + numel(fids(ii).cluster);
end
ffr_imgs = cell(nn, 1);

img_idx = 0;
for ii=1:numel(fids)
    for jj=1:numel(fids(ii).cluster)
        img_idx = img_idx+1;
        % Get frame id's
        ids = fids(ii).cluster(jj).fids;
        txfms = zeros(numel(ids), 2);
        for kk=2:numel(ids)
            ncc = getNCC(vid(:,:,ids(1)), vid(:,:,ids(kk)));
            ncc = ncc.*ncc_mask;
            [yy, xx] = find(ncc == max(ncc(:)));
            if isa(ncc, 'gpuArray')
                yy = gather(yy);
                xx = gather(xx);
            end
            dy = size(vid, 1) - yy;
            dx = size(vid, 2) - xx;
            fprintf('Frame %i to %i, Dx: %i; Dy: %i\n', ...
                ids(kk), ids(1), dx, dy);
            
            txfms(kk, :) = [dx, dy];
        end
        fids(ii).cluster(jj).txfms = txfms;
        
        % Apply txfms and crop
        crop = true;
        regSeq = getRegSeq(vid(:,:,ids), txfms, crop);
%         cropX = max(abs(txfms(:,1)))+1;
%         cropY = max(abs(txfms(:,2)))+1;
%         regSeq = regSeq(cropY:end-cropY, cropX:end-cropX, :);
        ffr_imgs{img_idx} = mean(regSeq, 3);
    end
end

end

