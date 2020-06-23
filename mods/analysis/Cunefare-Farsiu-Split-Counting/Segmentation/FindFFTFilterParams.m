% David Cunefare
% 3/24/2015

function   [FFTFilterMin, FFTFilterMax]=FindFFTFilterParams(Image,Params)


% Take the Fourier transform of the Image
ImageFFT = fftshift(fft2(Image));

% Get the frequencies in invers pixels
if(mod(size(ImageFFT,2),2)==0)
dfX = 1/size(ImageFFT,2); 
FX =  linspace(-0.5,0.5-dfX,size(ImageFFT,2));
else
FX =  linspace(-0.5,0.5,size(ImageFFT,2));    
end
if(mod(size(ImageFFT,1),2)==0)
dfY = 1/size(ImageFFT,1);
FY =  linspace(-0.5,0.5-dfY,size(ImageFFT,1));
else
FY =  linspace(-0.5,0.5,size(ImageFFT,1));    
end

% Log 10 and smooth the image
ImageFFT10 = log10(abs(ImageFFT));
ImageFFT10 = imfilter(ImageFFT10,ones(Params.SmoothingfilterWidth,Params.SmoothingfilterWidth)./(Params.SmoothingfilterWidth.^2));


% Find the cone frequencies in the positive half of the FT
FFTCenterX = floor(size(Image,2)/2)+1;
FFTCenterY = floor(size(Image,1)/2)+1;

PositiveFX = FX(FFTCenterX:end);


% Get the average from multiple angles
Angle = Params.AveragingAngles;
PositiveFFTS = zeros(length(Angle),length(PositiveFX));
for iAngle = 1:length(Angle)
    RotatedFFT = imrotate(ImageFFT10,Angle(iAngle));
    FFTCenterX = floor(size(RotatedFFT,2)/2)+1;
    FFTCenterY = floor(size(RotatedFFT,1)/2)+1;
    
    PositiveFFTS(iAngle,:) = RotatedFFT(FFTCenterY,FFTCenterX:FFTCenterX+length(PositiveFX)-1);
end
PositiveFFT = mean(PositiveFFTS);



% Fit exponential to curve
% f = fit(PositiveFX(PositiveFX>.11)',PositiveFFT(PositiveFX>.11)','exp1');
 f = fit(PositiveFX',PositiveFFT','exp2');


% Subtract the exp curve
 PositiveFFT = PositiveFFT-f(PositiveFX)';
 



 % Find the peaks of the distribution
[Peaks, PeakLocs] = findpeaks(PositiveFFT,PositiveFX,'MinPeakDistance',Params.MinPeakDistance,'MinPeakProminence',Params.MinPeakProminence,'WidthReference','halfprom');

% Find the minimum peaks as well
[minPeaks, minPeakLocs] = findpeaks(-1.*PositiveFFT,PositiveFX,'MinPeakDistance',Params.MinPeakDistance,'MinPeakProminence',Params.MinPeakInverseProminence,'WidthReference','halfprom');

% Find the First Peak in the valid rang
PeakIndex = find((Params.MinCenterFrequency<PeakLocs)&(Params.MaxCenterFrequency>PeakLocs),1,'first');

% If no peak set to default values
if(isempty(PeakIndex))
    FFTFilterMin = Params.MinFrequency;
    FFTFilterMax = Params.MaxDefault;
    return;
end



% Determine which min to use
LeftMinIndex = find(minPeakLocs<PeakLocs(PeakIndex),1,'last');
RightMinIndex = find(minPeakLocs>PeakLocs(PeakIndex),1,'first');
if(~isempty(LeftMinIndex))
PeakMinHeight = -1*min(minPeaks(LeftMinIndex),minPeaks(RightMinIndex));
else
PeakMinHeight = -1*minPeaks(RightMinIndex);
end


%%%% Find the center of mass for the 1/4 peak tip
% Shift the peak so that its half starts at 0 height
PositiveFFT = PositiveFFT - PeakMinHeight  - (Peaks(PeakIndex)-PeakMinHeight)*3/4;


% Find the zero crossing to the left
LeftZeroIndex = find(((PositiveFFT<=0)&(PositiveFX<PeakLocs(PeakIndex))),1,'last')+1;
% Find the zero crossing to the right
RightZeroIndex = find(((PositiveFFT<=0)&(PositiveFX>PeakLocs(PeakIndex))),1,'first')-1;

% PeakFullWidth = PositiveFX(RightZeroIndex) - PositiveFX(LeftZeroIndex);
% PeakSTd = sqrt(sum((PositiveFX(LeftZeroIndex:RightZeroIndex)-PeakCOM).^2 .* PositiveFFT(LeftZeroIndex:RightZeroIndex)))./sum(PositiveFFT(LeftZeroIndex:RightZeroIndex));

PeakCOM = sum(PositiveFFT(LeftZeroIndex:RightZeroIndex).*PositiveFX(LeftZeroIndex:RightZeroIndex))./sum(PositiveFFT(LeftZeroIndex:RightZeroIndex));

% If the peak COM is invalid set to default values
if((PeakCOM>Params.MaxCenterFrequency)||(PeakCOM<Params.MinCenterFrequency))
    FFTFilterMin = Params.MinFrequency;
    FFTFilterMax = Params.MaxDefault;
    return;
end



% Get the filter sizes
FFTFilterMin = PeakCOM - Params.FilterWidth;
if(FFTFilterMin<Params.MinFrequency)
    FFTFilterMin = Params.MinFrequency;
end
FFTFilterMax = PeakCOM + Params.FilterWidth;

end