function vid_set = getAviSets(in_path)
%getAviGroups Collects simultaneously acquired .avi's

%% Constants
% Any number of leading characters (of any type)
% Underscore
% Four digits (0-9)
% ends with .avi
N_PAD = 4;
AOSLO_VID_EXPR = sprintf('%s%s%s', ...
    '[\w]+[_]', repmat('\d', 1, N_PAD), '[.]avi');
% Exclude leading characters
VID_NUM_EXP = sprintf('%s%s%s', ...
    '[_]', repmat('\d', 1, N_PAD), '[.]avi');

% Find all .avi files, filter by video number search expression
% todo: decide if this step is necessary
avi_dir = dir(fullfile(in_path, '*.avi'));
if isempty(avi_dir)
    vid_set = [];
    return;
end

% Don't include videos that are still being written
remove = false(size(avi_dir));
for ii=1:numel(avi_dir)
    try
        fid = fopen(fullfile(in_path, avi_dir(ii).name), 'r');
        fclose(fid);
    catch
        remove(ii) = true;
    end
end
avi_dir(remove) = [];

% Set up regular expression search
search_results = regexp({avi_dir.name}', AOSLO_VID_EXPR);
avi_dir(cellfun(@isempty, search_results)) = [];

% Get the char index of the video number
avi_fnames = {avi_dir.name}';
vid_num_start = regexp(avi_fnames, VID_NUM_EXP); 
% Extract video number from each file name
vid_nums = cellfun(@(x,y) (x( y+1 : y + N_PAD)), ...
    avi_fnames, vid_num_start, 'uniformoutput', false);
% Find unique entries
u_vid_nums = unique(vid_nums);

% Preallocate a structure containing number and file names
vid_set(numel(u_vid_nums)).num = u_vid_nums{end};
for ii=1:numel(u_vid_nums)
    vid_set(ii).num = u_vid_nums{ii};
    vid_set(ii).fnames = avi_fnames(contains(avi_fnames, ...
        [u_vid_nums{ii}, '.avi']));
end





end

