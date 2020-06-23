function img_idx = findImgInPennAM(inData, mon_img_fname)
%findImgInPennAM determines the index of the montaged image within its
%structure.
% todo: this will be deprecated once a common montage object is developed
% inData should be the inData field saved to the automontage file
% mon_img_fname should be the file name of an image that has been output by
% the Penn automontager

img_idx = 0;
for ii=1:size(inData,2)
    for jj=1:size(inData,1)
        [~,img_name] = fileparts(inData{jj,ii});
        if contains(mon_img_fname, img_name)
            img_idx = ii;
            break;
        end
    end
end

end

