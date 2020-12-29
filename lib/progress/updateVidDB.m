function ld = updateVidDB(ld, paths, opts)
%updateVidDB Updates the video database
%   Updates list of videos
%   Gathers video metadata

%% Constants
VID_EXT = '*.avi';
HEAD_EXT = '*.mat';

%% Extract subject ID
if (~isfield(ld, 'id') || isempty(ld.id)) && ...
        ~isempty(ld.vid) && isfield(ld.vid, 'vid_set') && ...
        ~isempty(ld.vid.vid_set) && ~isempty(ld.vid.vid_set(1).vids) && ...
        ~isempty(ld.vid.vid_set(1).vids(1).filename)
    ld.id = getID(ld.vid.vid_set(1).vids(1).filename);
end

%% Check if vidsets have a compatible calibration file
if ~isempty(ld.vid) && isfield(ld.vid, 'vid_set') && ~isempty(ld.vid.vid_set) && ...
        ~isempty(ld.cal) && isfield(ld.cal, 'dsin') && ~isempty(ld.cal.dsin)
    for ii=1:numel(ld.vid.vid_set)
        if ~ld.vid.vid_set(ii).hasCal && ~isempty(ld.vid.vid_set(ii).fov)
            ld.vid.vid_set(ii).hasCal = any( ...
                ld.vid.vid_set(ii).fov == [ld.cal.dsin.fov]' & ...
                [ld.cal.dsin.processed]');
        end
    end
end

%% Update properties of existing vid_sets
if ~isempty(ld.vid) && isfield(ld.vid, 'vid_set') && ...
        ~isempty(ld.vid.vid_set)
    for ii=1:numel(ld.vid.vid_set)
        % Has all mods?
        if ~ld.vid.vid_set(ii).hasAllMods
            
            mods = {ld.vid.vid_set(ii).vids.modality}';
            wls  = [ld.vid.vid_set(ii).vids.wavelength]';
            
            if numel(mods) < numel(opts.mod_order)
                continue;
            end
            
            % Check that at least the expected modalities exist
            match_found = false(size(opts.mod_order));
            for jj=1:numel(opts.mod_order)
                mod_wl_check = strcmp(mods, opts.mod_order{jj}) & ...
                    wls == opts.lambda_order(jj);
                if any(mod_wl_check) && numel(find(mod_wl_check)) == 1
                    match_found(jj) = true;
                end
            end
            if all(match_found)
                ld.vid.vid_set(ii).hasAllMods = true;
            end
        end
        
        % FOV? % TODO: DRY VIOLATION, should have a vid_set method
        % dedicated to extracting FOV from all its vids
        if isempty(ld.vid.vid_set(ii).fov)
            for jj=1:numel(ld.vid.vid_set(ii).vids)
                head_fname = strrep(...
                    ld.vid.vid_set(ii).vids(jj).filename, ...
                    VID_EXT(2:end), HEAD_EXT(2:end));
                if exist(fullfile(paths.raw, head_fname), 'file') ~= 0
                    ld.vid.vid_set(ii).fov = ...
                        getFOV(fullfile(paths.raw, head_fname));
                    break;
                end
            end
        end
        
        % Vids ready?
        for jj=1:numel(ld.vid.vid_set(ii).vids)
            if ~ld.vid.vid_set(ii).vids(jj).ready
                ld.vid.vid_set(ii).vids(jj) = updateReady(...
                    ld.vid.vid_set(ii).vids(jj), paths.raw);
            end
        end
    end
end

%% Update ready
% todo

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
	nvids = 0;
    for ii=1:numel(ld.vid.vid_set)
        nvids = nvids + numel(ld.vid.vid_set(ii).vids);
    end
    all_fnames = cell(nvids, 1);
    k=1;
    for ii=1:numel(ld.vid.vid_set)
        all_fnames(k:k-1+numel(ld.vid.vid_set(ii).vids)) = ...
            ld.vid.vid_set(ii).getAllFnames();
        k=k+numel(ld.vid.vid_set(ii).vids);
    end
    
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
% written = isReadable(paths.raw, {vid_search.name});
% vid_search(~written) = [];

%% Group videos by number
[vid_nums, num_idx] = determineAOSets({vid_search.name}');

%% Figure out if any of these video numbers already exist in the database
% and one particular video just barely missed the cutoff for being included
%todo
remove = false(size(vid_search));
if ~isempty(ld.vid) && isfield(ld.vid, 'vid_set') && ~isempty(ld.vid.vid_set)
    existing_vid_nums = [ld.vid.vid_set.vidnum]';
    new_vid_nums = str2double(vid_nums);
    for ii=1:numel(new_vid_nums)
        if ismember(new_vid_nums(ii), existing_vid_nums)
            remove(num_idx==ii) = true;
            
            % Add this video to that vid set
            current_set = vid_search(num_idx==ii);
            these_vids = repmat(aovid, numel(current_set), 1);
            current_vs_idx = find(new_vid_nums(ii) == existing_vid_nums);
            % TODO: DRY VIOLATION
            fov_found = ~isempty(ld.vid.vid_set(current_vs_idx).fov);
            for jj=1:numel(current_set)
                these_vids(jj) = aovid(current_set(jj).name);
                these_vids(jj) = updateReady(these_vids(jj), paths.raw);

                % Try to determine fov from a video that has a header
                if ~fov_found
                    head_fname = strrep(current_set(jj).name, ...
                        VID_EXT(2:end), HEAD_EXT(2:end));
                    if exist(fullfile(paths.raw, head_fname), 'file') ~= 0
                        fov_found = true;
                        ld.vid.vid_set(current_vs_idx).fov = ...
                            getFOV(fullfile(paths.raw, head_fname));
                    end
                end
            end
            ld.vid.vid_set(current_vs_idx).vids = ...
                vertcat(ld.vid.vid_set(current_vs_idx).vids, these_vids);
        end
    end
end
vid_search(remove) = [];

% Recalculate sets after filtering
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
        these_vids(jj) = updateReady(these_vids(jj), paths.raw);
        
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



end








