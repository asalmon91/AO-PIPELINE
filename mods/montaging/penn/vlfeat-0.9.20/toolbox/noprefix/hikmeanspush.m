function varargout = hikmeanspush(varargin)
% VL_HIKMEANSPUSH   Push data down an integer K-means tree
%   PATH = VL_HIKMEANSPUSH(TREE,X) quanizes the data X with the
%   hierachical integer K-means tree TREE. This is obtained by
%   calculating the path of each datum from the root of TREE down to a
%   leaf. Here X has a datum for each column and each column of PATH
%   represents the corresponding root-to-leaf path.
%
%   Example::
%     PATH(:,1) = [2 1 4] means that the first datum follows
%     the branches number 2, 1 and 4 starting from the root of the
%     HIKM tree ending to a leaf.
%
%   See also: VL_HIKMEANS(), VL_HELP().
[varargout{1:nargout}] = vl_hikmeanspush(varargin{:});
