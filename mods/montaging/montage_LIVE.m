function [ld, pff, paths] = montage_LIVE(ld, paths, opts, pff, pool_id)
%montage_LIVE Handles parallelization for montaging

%% Return if empty
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
    return;
end

% Todo: figure out a way to allocate as many workers to montaging as
% possible. If desinusoiding and registration and averaging are all done,
% it would be good to put as much effort into this step as possible

%% Montage images if there's an open slot
if strcmp(pff.State, 'unavailable')
    % TODO: figure out how to call specific python functions without having
    % to use the command line architecture. If we could pass data directly
    % to python, this module would be a lot smoother. This may actually be
    % necessary to achieve the intended purpose of the LIVE pipeline, but
    % this will suffice as a prototype for now
    % TODO: implement our own fast matlab-based automontager...
    
    % Try mini-montages of adjacent images. Accept any successful
    % connections. The goal here is not a perfect montage, just to
    % identify poor connections
%     all_img_fnames = vertcat(ld.mon.imgs.fnames);
    all_img_fnames = getNextMontage(ld);
    if isempty(all_img_fnames)
        return;
    end
    
    paths.tmp_mon = prepMiniMontage(paths.out, all_img_fnames);
    
    % Call the UCL automontager on this folder, unfortunately this still
    % means continually updating an excel file.
%     [fail, stdout] = deployUCL_AM('C:\Python37\python.exe', paths.tmp_mon, ...
%         fullfile(ld.mon.am_file.folder, ld.mon.am_file.name), ld.eye, ...
%         paths.tmp_mon)
    
    % TODO: Make another function which includes the mini-montage setup,
    % parsing the JSX, and updating the montage database. All that stuff is
    % cluttering up this function which is supposed to mirror the
    % calibrate_LIVE and ra_LIVE functions
    if numel(loc_data.vidnums) >= 2
            pff = parfeval(pool_id, @deployUCL_AM, 2, ...
                'C:\Python37\python.exe', paths.tmp_mon, ...
                fullfile(ld.mon.am_file.folder, ld.mon.am_file.name), ...
                ld.eye, paths.tmp_mon);
    end
end

%% Check for completed process
if strcmp(pff.State, 'finished') && isempty(pff.Error)
    [fail, stdout] = fetchOutputs(pff);
    if ~fail % Success
        % Find the .jsx
        srch = dir(fullfile(paths.tmp_mon, ...
            'create_recent_montage_*_fov.jsx'));
        if numel(srch) ~= 1
            % This shouldn't happen
            error('jsx not found');
        end
        
        %% Parse the montage file
        jsx_data = parseJSX(fullfile(paths.tmp_mon, srch.name));
        
        %% Convert units to degrees
        % Find the minimum FOV used in this montage
        min_fov = inf;
        for ii=1:numel(jsx_data)
            for jj=1:numel(jsx_data(ii).txfms)
                img_ffname = jsx_data(ii).txfms{jj}{1};
                [~,img_name, img_ext] = fileparts(img_ffname);
                kv = findImageInVidDB(ld, [img_name, img_ext]);
                this_fov = ld.vid.vid_set(kv(1)).fov;
                if this_fov < min_fov
                    min_fov = this_fov;
                end
            end
        end
        % Get the pixels per degree that was used for this montage
        this_ppd = ld.cal.dsin([ld.cal.dsin.fov] == min_fov).ppd;
        
        % Overwrite the pixel units in jsx_data with degree values
        for ii=1:numel(jsx_data)
            for jj=1:numel(jsx_data(ii).txfms)
                for kk=2:5
                    jsx_data(ii).txfms{jj}{kk} = ...
                        jsx_data(ii).txfms{jj}{kk}./this_ppd;
                end
            end
        end
        ld.mon.montages = vertcat(ld.mon.montages, jsx_data');
        
        % Finally, delete the mini-montage
        [success, msg] = rmdir(paths.tmp_mon, 's');
        if ~success
            warning('Failed to remove %s', paths.tmp_mon)
            warning(msg);
        end
        
    else % Need to check for errors within stdout
        error(stdout);
    end
    
    % Reset future object
    pff = parallel.FevalFuture();
    
elseif ~isempty(pff.Error)
    % TODO: handle some error types
    rethrow(pff.Error)
end









end

