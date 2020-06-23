function data = getContrast(imgs, data, sdx)
%getContrast 

ids = [data(~[data.rej]).id];
imgs = imgs(:,:,ids);
% imgs = reshape(imgs, [size(imgs,1) * size(imgs,2), size(imgs,3)]);
% con = std(imgs,[],1)./mean(imgs,1);

con = zeros(size(imgs,3), 1, class(imgs));
for ii=1:numel(con)
    con(ii) = std(imgs(:,:,ii), [], 'all')./mean(imgs(:,:,ii), 'all');
end
if isa(con, 'gpuArray')
	con = gather(con);
end

con_norm = (con - mean(con))./std(con);
badFrames = ids(con_norm < -sdx);
if ~isempty(badFrames)
    data = rejectFrames(data, badFrames, mfilename);
end

end

