function [entropyVector, ub] = stripEntropy(img, strip_size)
%stripEntropy Measures the local entropy of each strip in an image

% Rolling entropy measurement
% Entropy is defined as -sum(p.*log2(p)), where p contains the normalized histogram counts returned from imhist.

% h = histogram(img, 'normalization', 'probability');
% Create temporary image with odd dimensions
% tmp_img = img;
% if mod(size(tmp_img,1), 2) == 0
%     tmp_img = tmp_img(1:end-1, :);
% end
% if mod(size(tmp_img,2), 2) == 0
%     tmp_img = tmp_img(:, 1:end-1);
% end

% Set up strip boundaries
lb = strip_size:size(img,1);
ub = lb-strip_size+1;
entropyVector = zeros(size(lb));

% figure;
% tic
for ii=1:numel(ub)

    entropyVector(ii) = entropy(img(ub(ii):lb(ii), :));
    
% %     Display
%     subplot(1,2,1);
%     imshow(img);
%     hold on;
%     plot([1, size(img,2), size(img,2), 1], ...
%         [ub(ii), ub(ii), lb(ii), lb(ii)], '-c');
%     hold off
%     
%     subplot(1,2,2);
%     plot(entropyVector, ub, '-k');
%     set(gca,'ydir','reverse');
%     xlabel('Entropy');
%     ylabel('Row (px)');
%     drawnow;
end
% toc

end

