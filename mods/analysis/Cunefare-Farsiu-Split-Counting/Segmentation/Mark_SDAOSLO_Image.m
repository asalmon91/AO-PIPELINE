% David Cunefare
% 1/12/2016

function   [ConePositions]=Mark_SDAOSLO_Image(Image)

% Load Parameters
Params = get_SDAOSLO_Parameters();

% Normalize Image
Image = normalizeValues(double(Image),0,255);

% Get Filter cutoffs
[Params.Detection.FilterInner, Params.Detection.FilterOuter]=FindFFTFilterParams(Image,Params.FFTFilterParams);

% Set the max distance between matches based on found frequency
FilterCenter = Params.Detection.FilterOuter - Params.FFTFilterParams.FilterWidth;
Params.Detection.MaxDistance  = 1/(FilterCenter) *1.5;

% Choose threshold based on found frequency
if(FilterCenter<.065)
    Params.Detection.IntensityThreshold = .875;
    Params.Detection.IntensityThresholdLightAlone = 2.1;
elseif(FilterCenter>=.065&&FilterCenter<.075)
    Params.Detection.IntensityThreshold = .7;
    Params.Detection.IntensityThresholdLightAlone = 1.75;
else
    Params.Detection.IntensityThreshold = .525;
    Params.Detection.IntensityThresholdLightAlone = 1.4;
end

[CentPos, ~, MaxOnlyPos] = FindSplitCones(Image,Params.Detection);

% Include the matched and light only positions together
ConePositions = [CentPos;MaxOnlyPos];


end