function [acc] = getACC(img)
%getACC Get autocorrelation, NCC of the image to itself
%   Originally written by Dr. Alf Dubra
%   Adapted for this project by Alex Salmon

% roundoff threshold
threshold = 1e-6;

[nRows, nCols] = size(img);

% pad both images
pad1 = zeros(2*nRows-1, 2*nCols-1, class(img));
pad2 = pad1;

pad1(1:nRows, 1:nCols)     = img;
pad2(nRows:end, nCols:end) = img;

% Using the correlation theorem to calculate the cross-correlation
crossCorr = real(ifft2(conj(fft2(pad1)).*fft2(pad2)));

% normalization
pupilImg1 = zeros(size(pad1), class(img));
pupilImg2 = pupilImg1;

pupilImg1(1:nRows, 1:nCols)     = 1;
pupilImg2(nRows:end, nCols:end) = 1;

normFactor1 = real(ifft2(conj(fft2(pad1.^2)).*fft2(pupilImg2)));
normFactor2 = real(ifft2(conj(fft2(pupilImg1)).*fft2(pad2.^2)));
    
% roundoff errors lead to negative values in the autocorrelation
% and thus the need to remove them manually
normFactor1 = normFactor1.*(normFactor1 >= 0);
normFactor2 = normFactor2.*(normFactor2 >= 0);
 
zeroCrossCorrMask = (normFactor1 > threshold) & (normFactor2 > threshold);

% including eps to avoid problems when denominator is null
acc = zeroCrossCorrMask.*crossCorr./sqrt(eps+normFactor1.*normFactor2);

end