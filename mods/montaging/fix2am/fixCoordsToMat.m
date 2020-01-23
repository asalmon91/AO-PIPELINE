function xy_out = fixCoordsToMat(xy_coord_char_mat)
%fixCoordsToMat converts the output of fixation GUI coordinates from char
%matrix to double matrix

xy_out = zeros(size(xy_coord_char_mat, 1), 2);
for ii=1:size(xy_out, 1)
    xy_out(ii,:) = ...
        cellfun(@str2double, strsplit(xy_coord_char_mat(ii,:), ','));
end




end

