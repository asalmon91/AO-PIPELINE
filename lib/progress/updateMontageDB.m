function [ld, fh] = updateMontageDB(ld, paths, fh)
%updateMontageDB Updates the montage database
%   Updates the position file info
%   Checks for images to be montaged

%% Initialize montages
if ~isfield(ld.mon, 'montages') || isempty(ld.mon.montages)
    % For keeping track of how many disjointed montages we have
    ld.mon.montages = [];
    ld.mon.needs_update = false;
end

%% Handle position file
read_loc_file = false;
if isempty(ld.mon) || ~isfield(ld.mon, 'loc_file') || isempty(ld.mon.loc_file)
    % Find if not already loaded
    ld.mon.loc_file = find_AO_location_file(paths.root);
    if ~isempty(ld.mon.loc_file)
        read_loc_file = true;
    end
else
    % Check for updates
    file_info = dir(ld.mon.loc_file.name);
    if file_info.datenum > ld.mon.loc_file.datenum
        % File has been updated
        read_loc_file = true;
        
    end
end
if read_loc_file
    [loc_path, loc_name, loc_ext] = fileparts(ld.mon.loc_file.name);
    % Try to read the position file
    try
        ld.mon.loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
        
        % Update a UCL Automontager-compatible position file
        % todo: eventually we'd like to strip the automontager down to its
        % fundamental functions and be able to pass data entirely through
        % this program. This part should be removed in a later version
        try
            if isfield(ld.cal, 'dsin') && ~isempty(ld.cal.dsin) && ...
                    isfield(ld, 'id') && isfield(ld, 'date') && ...
                    isfield(ld, 'eye')
                [out_ffname, ~, ok] = fx_fix2am(ld.mon.loc_file.name, ...
                    'human', 'ucl', ld.cal.dsin, [], ...
                    ld.id, ld.date, ld.eye, paths.mon);
                ld.mon.am_file = dir(out_ffname{1});
                
                if ~ok
%                     warning('Failed to update %s', out_ffname{1});
                else
                    % Update the time stamp of the fixation GUI file only if we
                    % successfully update the automontager fixation file
                    ld.mon.loc_file.datenum = file_info.datenum;
%                     fprintf('Successfully updated\n%s\n', out_ffname{1});
                end
            end
        catch MException
            if strcmp(MException.message, ...
                    'Position file failed to process')
                % Hopefully this is just because it's locked for editing at
                % the moment. 
%                 warning('Failed to update position file');
%                 disp( getReport( MException, 'extended', 'hyperlinks', 'on' ) )
            else
                rethrow(MException);
            end
        end
        
    catch MException
        % Sometimes we catch it while it's writing, just wait until the
        % next iteration and try again
        if strcmp(MException.identifier, ...
                'MATLAB:xlsread:WorksheetNotActivated')
%             warning('Failed to update position file');
        else
            rethrow(MException);
        end
    end
end

%% Add fringe information to location data
if isfield(ld.mon, 'loc_data') && ~isempty(ld.mon.loc_data) && ...
        isfield(ld.cal, 'dsin') && ~isempty(ld.cal.dsin)
    fringes = NaN(size(ld.mon.loc_data.fovs));
    for ii=1:numel(fringes)
        dsin_idx = find(ld.mon.loc_data.fovs(ii) == [ld.cal.dsin.fov]);
        if ~isempty(dsin_idx) && ld.cal.dsin(dsin_idx).processed
            fringes(ii) = ld.cal.dsin(dsin_idx).fringe_px;
        end
    end
    ld.mon.loc_data.fringes = fringes;
end

%% Find processed images, add to database
% Initialize
% if ~isfield(ld.mon, 'imgs') || isempty(ld.mon.imgs) || ...
%         ~isfield(ld.mon.imgs, 'fnames')
%     ld.mon.imgs = [];
%     all_img_fnames = [];
% else
%     all_img_fnames = vertcat(ld.mon.imgs.fnames);
% end
% 
% % Analyze video database
% if ~isempty(ld.vid) && isfield(ld.vid, 'vid_set') && ~isempty(ld.vid.vid_set) && ...
%         isfield(ld.mon, 'loc_data') && ~isempty(ld.mon.loc_data)
%     % For all sets of videos
%     for ii=1:numel(ld.vid.vid_set)
%         if ~ld.vid.vid_set(ii).processed % Can ignore the unprocessed
%             continue;
%         end
%         % Do we know the expected location for this video?
%         this_num = ld.vid.vid_set(ii).vidnum;
%         % vid_idx is the index of this video within the location data
%         % structure
%         vid_idx = find(this_num == ...
%             cellfun(@str2double, ld.mon.loc_data.vidnums));
%         if isempty(vid_idx)
%             continue;
%         end
%         
%         % For all videos within a set
%         for jj=1:numel(ld.vid.vid_set(ii).vids)
%             % For each set of frames ARFS was able to connect
%             for kk=1:numel(ld.vid.vid_set(ii).vids(jj).fids)
%                 % For each cluster within that set of frames
%                 for mm=1:numel(ld.vid.vid_set(ii).vids(jj).fids(kk).cluster)
%                     these_fnames = ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames;
%                     if ~ismember(these_fnames{1}, all_img_fnames)
%                         % Organize location data into a structure 
%                         these_imgs.fnames = these_fnames;
%                         
%                         % Parse expected location
%                         coords = cellfun(@str2double, ...
%                             strsplit(...
%                             ld.mon.loc_data.coords(vid_idx, :), ','));
%                         these_imgs.ex_loc = coords;
%                         % Get FOV for determining expected overlap
%                         these_imgs.fov = ld.mon.loc_data.fovs(vid_idx);
%                         
%                         % Add fields to track whether it was successfully
%                         % matched to another image
%                         these_imgs.matches = [];
%                         
%                         % Add to database in an inefficient way
%                         ld.mon.imgs = vertcat(ld.mon.imgs, these_imgs);
%                     end
%                 end
%             end
%         end
%     end
% end

%% Everything after this point requires montages
if isempty(ld.mon.montages) || ~ld.mon.needs_update
    return;
end

%% Combine montages if possible
ld.mon.montages = absorbMontages(ld.mon.montages);

%% Remove redundancies
for ii=1:numel(ld.mon.montages)
    img_ffnames = cellfun(@(x) x{1}, ld.mon.montages(ii).txfms, 'uniformoutput', false)';
    remove = getRedundantStrings(img_ffnames);
    ld.mon.montages(ii).txfms(remove) = [];
end

%% Find a sufficient montage
if numel(ld.mon.montages) > 1
    ld.mon.montages = findSufficientMontage(...
        ld.mon.montages, ld.mon.loc_data);
end

%% Identify unexpected breaks
if numel(ld.mon.montages) > 1
    [suggested_locs, ld.mon.breaks] = findBreaks(...
        ld.mon.montages, ld.mon.loc_data, ld.mon.opts);
    fprintf('Consider acquiring new images at the following locations:\n');
    disp(suggested_locs);
elseif numel(ld.mon.montages) == 1
    ld.mon.breaks = []; % Reset this so we don't keep trying
end

%% Display updated montage
% todo: this ought to be a GUI, not just a figure, which allows switching
% modalities, switching between showing only one disjoint at a time.
% Sorted by size
% for now, I think we need to limit it to updating a figure that uses the
% math from the Penn AM to place everything on one canvas
% close all;
if ~isfield(ld, 'gui_handles') || isempty(ld.gui_handles)
    ld.gui_handles = [];
end
ld.gui_handles = displayMontage(ld, ld.gui_handles);

% Indicate that the database has been updated
ld.mon.needs_update = false;

%% Check image directory and update a time stamp to prevent re-running
srch = dir(fullfile(paths.out, '*.tif'));
ld.mon.img_datenum = max([srch.datenum]);


end

