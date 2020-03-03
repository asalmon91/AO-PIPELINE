function img = readAndForce2D(img_ffname)
%readAndForce2D reads the image and ensures that it is 2D
        
img = imread(img_ffname);

if size(img,3) >1
    img = img(:,:,1);
end

end

