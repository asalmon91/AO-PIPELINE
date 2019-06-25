function cs_img = contrast_stretch(img)
%contrast_stretch (mean goes to 128 and either the min goes to 0 or the 
%max goes to 255

cs_img = img - mean(img(1:end));
scaling_factor = max(...
    abs(min(cs_img(1:end))), ...
    abs(max(cs_img(1:end))));
cs_img = uint8(cs_img / scaling_factor * 127 + 128);

end

