function data = getContrast(imgs, data, sdx)
%getContrast 

% global wb;

% Waitbar
% waitbar(0, wb, 'Measuring image contrast');

con = zeros(size(data));
for ii=1:numel(data)
    if data(ii).rej
        continue;
    end
    
    img = double(imgs(:,:,ii));
    con(ii) = std(img(:))./mean(img(:));
    
%     waitbar(ii/numel(data), wb);
end
con([data.rej]) = [];
ids = [data(~[data.rej]).id];

con_norm = (con - mean(con))./std(con);
badFrames = ids(con_norm < -sdx);
if ~isempty(badFrames)
    data = rejectFrames(data, badFrames, mfilename);
end

end

