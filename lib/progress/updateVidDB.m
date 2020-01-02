function ld = updateVidDB(ld, paths)
%updateVidDB Updates the video database
%   Updates list of videos
%   Gathers video metadata

%% Constants
VID_EXT = '*.avi';
HEAD_EXT = '*.mat';

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
    %% Filter out videos that have already been added
    % Get a list of all filenames in the database
	all_vids = [ld.vid.vid_set.vids];
    all_vids = all_vids(:);
    all_fnames = {all_vids.filename}';
    
    % todo: could be more efficient by extracting video number here
    % (probably not necessary)
    new_files = false(size(vid_search));
    for ii=1:numel(vid_search)
        if ~any(contains(all_fnames, vid_search(ii).name))
            new_files(ii) = true;
        end
    end
    
    % Filter out old files
    vid_search = vid_search(new_files);
    if isempty(vid_search)
        return;
    end
end

%% Filter out videos that don't follow the expected naming convention
isAOVid = follows_AO_naming({vid_search.name});
vid_search(~isAOVid) = [];

%% Filter out videos that are currently being written/copied
written = isReadable(paths.raw, {vid_search.name});
vid_search(~written) = [];

%% Group videos by number
[vid_nums, num_idx] = determineAOSets({vid_search.name}');

%% Extract metadata and add these videos to the database
% todo: probably want to construct a function here and a custom class for
% a video set database
new_vid_set = repmat(vidset, numel(vid_nums), 1);
for ii=1:numel(vid_nums)
    % Filter by current video number and add to object
    current_set = vid_search(num_idx==ii);
    new_vid_set(ii).vidnum = str2double(vid_nums{ii});
    
    % Construct videos, determine FOV
    these_vids = repmat(aovid, numel(current_set), 1);
    fov_found = false;
    for jj=1:numel(current_set)
        these_vids(jj) = aovid(current_set(jj).name);
        
        % Try to determine fov from a video that has a header
        if ~fov_found
            head_fname = strrep(current_set(jj).name, ...
                VID_EXT(2:end), HEAD_EXT(2:end));
            if exist(fullfile(paths.raw, head_fname), 'file') ~= 0
                fov_found = true;
                new_vid_set(ii).fov = ...
                    getFOV(fullfile(paths.raw, head_fname));
            end
        end
    end
    new_vid_set(ii).vids = these_vids;
end

%% Add to live database
ld.vid.vid_set = vertcat(ld.vid.vid_set, new_vid_set);

%% Check if vidsets have a compatible calibration file












