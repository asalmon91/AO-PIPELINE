function dsin_vid = desinusoidVideo(vid, dsin_mat)
%desinusoidVideo desinusoids a video
% todo: comment better

dsin_vid = zeros(size(vid,1), size(dsin_mat, 1), ...
        size(vid, 3), class(vid));    
for ii=1:size(vid, 3)
    dsin_vid(:,:,ii) = vid(:,:,ii) * dsin_mat';
end

end

