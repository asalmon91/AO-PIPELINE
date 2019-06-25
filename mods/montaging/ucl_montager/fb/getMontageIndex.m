function montage_idx = getMontageIndex(vid_nums, montages)
%getMontageIndex returns the index of the montage to which each video
%belongs

montage_idx = zeros(size(vid_nums));
for ii=1:numel(vid_nums)
    for jj=1:numel(montages)
        if any(contains({montages(jj).images.num}, vid_nums{ii}))
            montage_idx(ii) = jj;
        end
    end
end

end

