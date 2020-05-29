function n_not_rejected = get_n_not_rejected(frames, exception_list)
%get_n_not_rejected returns the number of frames not rejected, with some
%exceptions allowed

%% Optional Inputs
if exist('exception_list', 'var') == 0 || isempty(exception_list)
    exception_list = {'rejectSmallGroups'; 'rejectSmallClusters'};
end

%% Find the total number not rejected
n_not_rejected = numel(find(~[frames.rej]));

%% Find exceptions
n_except = 0;
for ii=1:numel(exception_list)
    n_except = n_except + ...
        numel(find(strcmp({frames.rej_method}, exception_list{ii})));
end
% Add them to the total
n_not_rejected = n_not_rejected + n_except;




end

