function matches_expr = follows_AO_naming(in_fnames, ao_vid_expr)
%follows_AO_naming checks whether the list of fnames matches the naming
%convention. in_fnames must be a cell array and ao_vid_expr must be a 1D
%char array used in conjunction with regexp, but this input is optional

% todo: could also include mandatory components like wavelength and eye,
% but for now, we just want to make sure the video number is the last token
% before an avi extension
% todo: offer support for non-avi files

%% Regular expression matching for AOSLO videos
if exist('ao_vid_expr', 'var') == 0 || isempty(ao_vid_expr)
    n_pad = 4;
    ao_vid_expr = sprintf('%s%s%s', ...
        '[\w]+[_]', repmat('\d', 1, n_pad), '[.]avi');
end

%% If a match is found, then it is probably matches the convention
matches_expr = false(size(in_fnames));
for ii=1:numel(in_fnames)
    matches_expr(ii) = ~isempty(regexp(in_fnames{ii}, ao_vid_expr, 'once'));
end



end

