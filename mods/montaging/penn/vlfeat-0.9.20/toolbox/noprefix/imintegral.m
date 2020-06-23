function varargout = imintegral(varargin)
% VL_IMINTEGRAL  Compute integral image
%   J = VL_IMINTEGRAL(I) calculates the integral image J of the image
%   I.  I must a matrix with DOUBLE, SINGLE, UINT32, or INT32 storage
%   class. J is given by
%
%    J(i,j) = sum(I(1:i,1:j)).
%
%   J has the same size as I and the same storage class.
%
%   Example::
%     The following identity holds:
%       VL_IMINTEGRAL(ONES(3)) = [ 1 2 3 ;
%                                  2 4 6 ;
%                                  3 6 9 ]
%
%   See also: VL_HELP().
[varargout{1:nargout}] = vl_imintegral(varargin{:});
