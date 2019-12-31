function ld = updateVidDB(ld, paths)
%updateVidDB Updates the video database
%   Updates list of videos
%   Gathers video metadata

%% Constants
VID_EXT = '*.avi';

%% Check video folder
vid_search = dir(fullfile(paths.raw, VID_EXT));
if isempty(vid_search)
    return;
end

%% Update database
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
    % Initialize empty video set
    ld.vid.vid_set = [];
else
    % Filter out videos that have already been added
    
%     [vid_search.datenum]
end

%% Extract metadata and add these videos to the database









