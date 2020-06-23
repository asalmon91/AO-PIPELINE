function coords_xy = fx_cone_counting(img, counting_algorithm, loc_deg)
%fx_cone_counting attempts to identify the center of all cones in img
% img: the image to be analyzed, must be MxNx1 uint8
% todo: there might be optional inputs and outputs for the different
% algorithms. Should setup a varargin and varargout architecture.

coords_xy = feval(counting_algorithm, img);

% switch counting_algorithm
%     case 'Li-Roorda-Confocal'
%         coords_xy = li_roorda_count_cones(img);
%     case 'Cunefare-Farsiu-Split'
%         error('Not yet implemented');
%     case 'Cunefare-Farsiu-RAC-CNN'
%         error('Not yet implemented');
%     otherwise
%         coords_xy = li_roorda_count_cones(img);
% end

% % DEV/DB
% figure;
% imshow(img);
% hold on;
% plot(coords_xy(:,1), coords_xy(:,2), '.r');
% hold off;
% if exist('loc_deg', 'var') && ~isempty(loc_deg)
%     title(sprintf('%i, %i', loc_deg(1), loc_deg(2)));
% end
% % END DEV/DB

end

