function data = getSharpness(imgs, data, sdx)
%getSharpness Computes the mean gradient magnitude of an image using a
%Sobel filter 

% global wb;

% waitbar(0, wb, 'Calculating sharpness...');
sharps = zeros(numel(data), 1);
if isa(imgs, 'gpuArray')
    sharps = gpuArray(sharps);
end
for ii=1:numel(data)
    if ~data(ii).rej
        sharps(ii) = mean(mean(sobelFilter(imgs(:,:,ii))));
    end
end
if isa(sharps, 'gpuArray')
    sharps = gather(sharps);
end

% Find outliers
sharps([data.rej]) = []; % Remove empty elements
sharps_norm = (sharps - mean(sharps))./std(sharps);
outliers = sharps_norm < -sdx;
% Get current list of kept frame ids
ids = [data(~[data.rej]).id];
data = rejectFrames(data, ids(outliers), mfilename);

end

