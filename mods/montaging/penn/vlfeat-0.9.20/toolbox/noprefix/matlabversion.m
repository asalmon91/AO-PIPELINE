function varargout = matlabversion(varargin)
% VL_MATLABVERSION  Return MATLAB version as an integer
%   V = VL_MATLABVERSION() returns MATLAB version encoded as an
%   ingeger value. MATLAB version string has the format
%
%     MAJOR.MINOR.SERVICEPACK
%
%   The integer V has the value
%
%     V = MAJOR * 10000 + MINOR * 100 + SERVICEPACK.
%
%   For example, in MATLAB 7.10.0 (R2010a), V equals 70100.
%
%   See also: VL_HELP().
[varargout{1:nargout}] = vl_matlabversion(varargin{:});
