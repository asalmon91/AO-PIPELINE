function out_img = trim_transparent(img)
%trim_transparent removes the transparent pixels on the edges of the image


% I think it's safe to only do horizontal cropping
    % If there are a lot of 0's on the top or bottom rows, this gets much 
    % more complicated
    
    alpha_layer = ~isnan(img);
    
    crop_done = false;
    lb = 1;
    rb = size(img, 2);
    while ~crop_done
        if ~all(alpha_layer(:, lb))
            lb = lb+1;
        end
        if ~all(alpha_layer(:, rb))
            rb = rb - 1;
        end
        
        % Check to see if you're dumb
        if lb > size(img, 2) / 2 || rb < size(img, 2) / 2
            error('Revise cropping method');
        end
        
        % Success
        if all(alpha_layer(:, lb)) && all(alpha_layer(:, rb))
            out_img = img(:, lb:rb, 1);
            crop_done = true;
        end
    end
end

