% David Cunefare
% 1/12/2016

function [Params] = get_SDAOSLO_Parameters()

% Parameters For finding Yellot's Ring
Params.FFTFilterParams.MinFrequency = .025;
Params.FFTFilterParams.MaxDefault = .1;
Params.FFTFilterParams.MaxCenterFrequency = .16;
Params.FFTFilterParams.MinCenterFrequency = .04;
Params.FFTFilterParams.SmoothingfilterWidth = 5;
Params.FFTFilterParams.AveragingAngles = -20:5:20;
Params.FFTFilterParams.MinPeakDistance = .02;
Params.FFTFilterParams.MinPeakProminence = .05;
Params.FFTFilterParams.MinPeakInverseProminence = .01;
Params.FFTFilterParams.FilterWidth = .04;

% Parameters for detectinf cones
Params.Detection.FilterOuter = [];
Params.Detection.FilterInner = [];
Params.MaxDistance = [];
Params.Detection.IntensityThreshold = [];
Params.Detection.IntensityThresholdLightAlone = [];
Params.Detection.LightThreshold = 0;
Params.Detection.PointMatchVerticalUpscale = 2;

end