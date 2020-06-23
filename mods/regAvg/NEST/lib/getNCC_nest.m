function [nccs] = getNCC_nest(img1, img2, cropCols, cropRows)
%getNCC This NCC is meant for strip registration
%   Originally written by Dr. Alf Dubra
%   Adapted for this project by Alex Salmon
%   Modified for batch mode, where img1 is an mxn array, img2 is an mxnxk
%   array
%   Outputs ONLY max(ncc(:)), not whole matrix
%   More general version avaiable: getNCC.m

%% Constants
% roundoff threshold
threshold = 1e-6;
if isempty(cropCols)
    cropCols = floor(size(img1, 2)/4);
end
if isempty(cropRows)
    cropRows = floor(size(img1, 1)/2);
end

[nRows1, nCols1, ~] = size(img1);
[nRows2, nCols2, nStrips] = size(img2);

% pad image 1
pad1 = zeros(nRows1+nRows2-1, nCols1+nCols2-1);
pad2 = zeros(nRows1+nRows2-1, nCols1+nCols2-1);
pad1(1:nRows1, 1:nCols1) = img1;

% normalization
pupilImg1 = zeros(size(pad1));
pupilImg2 = pupilImg1;
pupilImg1(1:nRows1, 1:nCols1)     = 1;
pupilImg2(nRows1:end, nCols1:end) = 1;

normFactor1 = real(ifft2(conj(fft2(pad1.^2)).*fft2(pupilImg2)));
normFactor1 = normFactor1.*(normFactor1 >= 0);

% Max NCC coefficients
nccs = zeros(nStrips, 1);
for ii=1:nStrips
    pad2(nRows1:end, nCols1:end) = img2(:,:,ii);

    % Using the correlation theorem to calculate the cross-correlation
    crossCorr = real(ifft2(conj(fft2(pad1)).*fft2(pad2)));
    
    % roundoff errors lead to negative values in the autocorrelation
    % and thus the need to remove them manually
    normFactor2 = real(ifft2(conj(fft2(pupilImg1)).*fft2(pad2.^2)));
    normFactor2 = normFactor2.*(normFactor2 >= 0);

    zeroCrossCorrMask = (normFactor1 > threshold) & (normFactor2 > threshold);

    % including eps to avoid problems when denominator is null
    ncc = zeroCrossCorrMask.*crossCorr./sqrt(eps+normFactor1.*normFactor2);
    
    % Cropping
    ncc = ncc(cropRows:end-cropRows, cropCols:end-cropCols);
    nccs(ii) = max(ncc(:));
end

end