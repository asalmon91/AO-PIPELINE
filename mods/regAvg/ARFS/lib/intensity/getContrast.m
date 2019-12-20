function data = getContrast(imgs, data, sdx)
%getContrast 

ids = [data(~[data.rej]).id];
imgs = imgs(:,:,ids);
imgs = reshape(imgs, [size(imgs,1) * size(imgs,2), size(imgs,3)]);
con = std(imgs,[],1)./mean(imgs,1);


% con = zeros(size(data));
% for ii=1:numel(data)
%     if data(ii).rej
%         continue;
%     end
%     
% %     img = double(imgs(:,:,ii));
%     con(ii) = std(img(:))./mean(img(:));
%     
% %     waitbar(ii/numel(data), wb);
% end
% con([data.rej]) = [];
% ids = [data(~[data.rej]).id];

con_norm = (con - mean(con))./std(con);
badFrames = ids(con_norm < -sdx);
if ~isempty(badFrames)
    data = rejectFrames(data, badFrames, mfilename);
end

end

