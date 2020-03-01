function primary_index = getPrimary(vid_cell, mods)
%getPrimary determines which video has the highest average SNR
%   vid_cell is a 1xX cell array of MxNxK video matrices
%   mods is a 1xX cell array of modalities, confocal will be log
%   transformed

if numel(vid_cell) <= 1
    error('vid cell must include more than 1 MxNxK videos');
end

nFrames = cellfun(@(x) size(x, 3), vid_cell);
if var(nFrames) ~= 0
    error('Videos must have the same number of frames');
end

snrs = zeros(nFrames(1), numel(vid_cell));
% img_heq = cell(size(vid_cell));
% for ii=1:nFrames(1)
%     % Get mod 1
%     img_heq{1} = double(vid_cell{1}(:,:,ii));
%     % Constrast stretch
%     if range(img_heq{1}(:)) ~= 255
%         img_heq{1} = img_heq{1}-min(img_heq{1}(:));
%         img_heq{1} = img_heq{1}./max(img_heq{1}(:)).*255;
%     end
%     % Get the histogram
%     [counts, ~] = hist(img_heq{1}(:), 0:255);
%     % Histogram equalize other modalities
%     for jj=2:numel(mods)
%         img_heq{jj} = double(histeq(vid_cell{jj}(:,:,ii), counts));
%     end
%     
%     for jj=1:numel(mods)
%         snrs(ii, jj) = mean(mean(sobelFilter(img_heq{jj})));
%         
% %         snrs(ii, jj) = 10*log10(mean(img_heq{jj}(:))/std(img_heq{jj}(:)));
%     end
%     
% end


% For each video
for ii=1:numel(vid_cell)
    
    
    
    avi = double(vid_cell{ii});
    if strcmpi(mods{ii}, 'confocal')
        avi = log10(avi+1);
    end
    % Contrast stretch all
    avi = avi - min(avi(:));
    avi = avi./max(avi(:)).*255;
%     avi = uint8(avi./max(avi(:)).*255);
    
    % Measure SNR in each frame
    for jj=1:size(avi,3)
        img = avi(:,:,jj);
        snrs(jj, ii) = 10*log10(mean(img(:))/std(img(:)));
        
%         snrs(jj, ii) = entropy(img);
    end
end

% Find highest median SNR
[~, primary_index] = max(median(snrs, 1));


% %% Display
% figure;
% % create concatenated 1st frame
% canvas = zeros(size(avi,1), size(avi,2)*numel(vid_cell));
% % img = vid_cell{1}(:,:,1);
% for ii=1:numel(vid_cell)
%     img = double(vid_cell{ii}(:,:,1));
%     if strcmpi(mods{ii}, 'confocal')
%         img = log10(img+1);
%     end
%     img = img-min(img(:));
%     img = img./max(img(:));
%     canvas(:, (ii-1)*size(avi,2) +1: ii*size(avi,2)) = img;
% %     img = horzcat(img, vid_cell{ii}(:,:,1)); %#ok<AGROW>
% end
% subplot(4,1,1:3);
% % imshow(img);
% imshow(canvas);
% title(strrep(strjoin(mods, ' v '), '_', ' '));
% 
% subplot(4,1,4)
% hold on;
% hist_edges = linspace(min(snrs(:)), max(snrs(:)), size(avi,3));
% for ii=1:numel(vid_cell)
%     histogram(snrs(:,ii), hist_edges);
% end
% for ii=1:numel(vid_cell)
%     plot(repmat(median(snrs(:, ii)), 1,2), get(gca,'ylim'), '-k');
% end
% hold off;
% set(gca, 'tickdir', 'out');
% axis tight
% legend(cellfun(@(x) strrep(x, '_', ' '), mods, 'uniformoutput', false), ...
%     'location','northeastoutside');
% xlabel('SNR (dB)');
% ylabel('# Frames');


end

