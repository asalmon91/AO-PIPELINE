function [ld, montage_app] = updateMontageDB(ld, paths, gui, montage_app)
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
        file_info = dir(ld.mon.loc_file.name);
    end
else
    % Check for updates
    file_info = dir(ld.mon.loc_file.name);
    if file_info.datenum > ld.mon.loc_file.datenum || isempty(montage_app)
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
        ld, ld.mon.montages, ld.mon.loc_data, ld.mon.opts);
    fprintf('Consider acquiring new images at the following locations:\n');
    disp(suggested_locs);
elseif numel(ld.mon.montages) == 1
    ld.mon.breaks = []; % Reset this so we don't keep trying
end

%% Display updated montage
% todo: Figure out a better method of plotting disjoints (more like Penn)
montage_app.live_data = ld;
montage_app.updateDisplay();
% montage_app = displayMontage(ld, montage_app, gui);

% Indicate that the database has been updated
ld.mon.needs_update = false;

%% Check image directory and update a time stamp to prevent re-running
srch = dir(fullfile(paths.out, '*.tif'));
ld.mon.img_datenum = max([srch.datenum]);


end

