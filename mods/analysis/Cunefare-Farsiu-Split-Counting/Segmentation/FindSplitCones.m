% David Cunefare
% 2/20/2015

function   [CenteredPositions, LightPositions, MaxOnlyPositions]=FindSplitCones(Image,Params)
% Function for Finding position of cones in a split detector image
%%%%%%
% Outputs :
%
% CenteredPositions: 2 column matrix containing [X,Y] positions centered
%       b/w light and dark spots
%
% LightPositions: 2 column matrix containing [X,Y] positions located on
%       light spots
%
% MaxOnlyPositions :2 column matrix containing [X,Y] positions located on
%       light spots with no crreponding dark spots
%
%
%
%%%%%%
% Inputs:
% Image: 2-D matrix containg split detector cone image
%
% Params: Paramater matrix




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%% Filter The image in Fourier Space  %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Take the Fourier transform of the Image
ImageFFT = fftshift(fft2(Image));

% Create the filter 
FFTfilter = zeros(size(ImageFFT));

% Find pixel frequencies
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

% FX = .5 * linspace(-1,1,size(FFTfilter,2));
% FY = .5 * linspace(-1,1,size(FFTfilter,1));

[XCart, YCart] = meshgrid(FX,FY);




% Create a bandpass filter around the cone frequency
for a =1:size(FFTfilter,1)
    for b =1:size(FFTfilter,2)
        RadialDist = sqrt(XCart(a,b)^2 + YCart(a,b)^2);
        if((RadialDist<=Params.FilterOuter)&&(RadialDist>=Params.FilterInner))
            FFTfilter(a,b)=1;
        end
    end
end




% Filter the image in fourier space
FilteredFFT = ImageFFT.*FFTfilter;

% FilteredFFT = FilteredFFT./(max(abs(FilteredFFT(:))));

% Convert back to spatial position
FilteredImage = ifft2(ifftshift(FilteredFFT));
FilteredImage = sign(real(FilteredImage)).*abs(FilteredImage);


% RemovedInfo = Image-sign(real(FilteredImage)).*abs(FilteredImage);
% figure;histogram(RemovedInfo(:))
% RemovedInfoSTtd= std(RemovedInfo(:))



% Get the Max of the filtered Image to set thresholds;
% FilteredImageMax = max(FilteredImage(:));

% Find the local min's and max's of the filtered image
MaxLocations = imregionalmax(FilteredImage);
MinLocations =  imregionalmin(FilteredImage);




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%% Match Light and Dark points %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[Imax,Jmax] = find(MaxLocations==1);
[Imin,Jmin] = find(MinLocations==1);

% Upscale the vertical direction to prioritize horizontal matching
LightPos = [Params.PointMatchVerticalUpscale.*Imax Jmax];
DarkPos = [Params.PointMatchVerticalUpscale.*Imin Jmin];

CorrespondingIndices = zeros(size(Imax));
CorrespondingDistances = zeros(size(Imax));
for iLight = 1:length(Imax)
    CurrentLight = LightPos(iLight,:);
    % Only look for dark points to the left of the light point
    PossibleDark = DarkPos;
    [InvalidIndices, ~] = find(PossibleDark(:,2)>=CurrentLight(:,2));
    PossibleDark(InvalidIndices,:)=nan;
    
    [k,d] = dsearchn(PossibleDark,CurrentLight);
    CorrespondingIndices(iLight) = k;
    CorrespondingDistances(iLight) =d; 
end
% If Nan distance set the correpondance to nan as well
CorrespondingIndices(isnan(CorrespondingDistances)) = nan;
% If distance greater than the maximum distance set the correpondance to nan 
CorrespondingIndices(CorrespondingDistances>Params.MaxDistance) = nan;

% Make sure there is a 1 to 1 correspondance between points
for iDark = 1:length(Imin)
    OverlappingMatchIndices = find(CorrespondingIndices == iDark);
    [~, iMinDis] = min(CorrespondingDistances(OverlappingMatchIndices));
    
    CorrespondingIndices(OverlappingMatchIndices) = nan;
    CorrespondingIndices(OverlappingMatchIndices(iMinDis)) = iDark;
end

ImaxCorresponding = Imax(~isnan(CorrespondingIndices));
JmaxCorresponding = Jmax(~isnan(CorrespondingIndices));

IminCorresponding = Imin(CorrespondingIndices(~isnan(CorrespondingIndices)));
JminCorresponding = Jmin(CorrespondingIndices(~isnan(CorrespondingIndices)));


% Find the average absolute intensity of the pairs
LightIntensity = zeros(size(ImaxCorresponding));
DarkIntensity = zeros(size(ImaxCorresponding));


for iPair = 1:length(ImaxCorresponding)
   LightIntensity(iPair) =  FilteredImage(ImaxCorresponding(iPair),JmaxCorresponding(iPair));
   DarkIntensity(iPair) =  FilteredImage(IminCorresponding(iPair),JminCorresponding(iPair));
end
AverageIntensity = (LightIntensity - (DarkIntensity))/2;


% Use Standard deviation to set threshold
 ImageSTD = std(FilteredImage(:));
 
% Save points that pass the thresholds
ValidIndices = (logical(AverageIntensity>Params.IntensityThreshold.*ImageSTD)&logical(LightIntensity>Params.LightThreshold));


CenteredPositions = [(JmaxCorresponding(ValidIndices)+JminCorresponding(ValidIndices))./2  (ImaxCorresponding(ValidIndices)+ IminCorresponding(ValidIndices))./2];
LightPositions = [JmaxCorresponding(ValidIndices) ImaxCorresponding(ValidIndices)];


% Also save the Maxes with no match found using higher threshold
IMaxAlone = Imax(isnan(CorrespondingIndices));
JMaxAlone = Jmax(isnan(CorrespondingIndices));

LightIntesityAlone = zeros(size(IMaxAlone));

for iAlone = 1:length(IMaxAlone)
   LightIntesityAlone(iAlone) =  FilteredImage(IMaxAlone(iAlone),JMaxAlone(iAlone));
end


ValidIndiceAlone = (logical(LightIntesityAlone>Params.IntensityThresholdLightAlone.*ImageSTD));
MaxOnlyPositions = [JMaxAlone(ValidIndiceAlone) IMaxAlone(ValidIndiceAlone)];


end


