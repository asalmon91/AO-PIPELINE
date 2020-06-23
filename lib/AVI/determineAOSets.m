function [u_vid_nums, num_index] = getAOVidSets(in_fnames)
%getAOVidSets Determines which ao videos belong in a set

%% Constants
% Any number of leading characters (of any type), underscore, 4 digits, 
% ends with .avi
N_PAD = 4;
% Exclude leading characters
VID_NUM_EXP = sprintf('%s%s%s', ...
    '[_]', repmat('\d', 1, N_PAD), '[.]avi');

%% Extract the video number
vid_num_start = regexp(in_fnames, VID_NUM_EXP); 
% Extract video number from each file name
vid_nums = cellfun(@(x,y) (x( y+1 : y + N_PAD)), ...
    in_fnames, vid_num_start, 'uniformoutput', false);
% Find unique entries
[u_vid_nums, ~, num_index] = unique(vid_nums);

end

