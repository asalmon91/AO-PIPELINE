function ld = updateMontageDB(ld, paths)
%updateMontageDB Updates the montage database
%   Updates the position file info
%   Checks for images to be montaged

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
        ld.mon.loc_file.datenum = file_info.datenum;
    end
end
if read_loc_file
    [loc_path, loc_name, loc_ext] = fileparts(ld.mon.loc_file.name);
    % Try to read the position file
    try
        ld.mon.loc_data = processLocFile(loc_path, [loc_name, loc_ext]);
        
        % Update a Penn Automontager-compatible position file
        % todo: eventually we'd like to strip the automontager down to its
        % fundamental functions and be able to pass data entirely through
        % this program. This part should be removed in a later version
        try
            if isfield(ld.cal, 'dsin') && ~isempty(ld.cal.dsin) && ...
                    isfield(ld, 'id') && isfield(ld, 'date') && ...
                    isfield(ld, 'eye')
                [out_ffname, ~, ok] = fx_fix2am(ld.mon.loc_file.name, ...
                    'human', 'penn', ld.cal.dsin, [], ...
                    ld.id, ld.date, ld.eye, paths.mon);
                ld.mon.am_file = dir(out_ffname{1});
                if ~ok
                    warning('Failed to update %s', out_ffname{1});
                else
                    fprintf('Successfully updated\n%s\n', out_ffname{1});
                end
            end
        catch MException
            if strcmp(MException.message, ...
                    'Position file failed to process')
                % Hopefully this is just because it's locked for editing at
                % the moment. 
                warning('Failed to update position file');
                disp( getReport( MException, 'extended', 'hyperlinks', 'on' ) )
            else
                rethrow(MException);
            end
        end
        
    catch MException
        % Sometimes we catch it while it's writing, just wait until the
        % next iteration and try again
        if strcmp(MException.identifier, ...
                'MATLAB:xlsread:WorksheetNotActivated')
            warning('Failed to update position file');
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
        if ~isempty(dsin_idx)
            fringes(ii) = ld.cal.dsin(dsin_idx).fringe_px;
        end
    end
    ld.mon.loc_data.fringes = fringes;
end

%% Check...
% % Check if the live processed folder has been updated
% tif_dir = dir(fullfile(paths.out, '*.tif'));
% most_recent_datenum = max([tif_dir.datenum]);
% if ~isfield(ld.mon, 'img_datenum') || isempty(ld.mon.img_datenum) || ...
%         most_recent_datenum > ld.mon.img_datenum
%     ld.mon.img_datenum = most_recent_datenum;
% else
%     return;
% end






end

