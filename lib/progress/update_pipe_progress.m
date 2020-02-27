function update_pipe_progress(live_data, paths, module, gui, in_obj)
%update_pipe_progress Updates a module of a pipe_progress_App object

%% Check for input from full pipeline
if exist('in_obj', 'var') ~= 0 && ~isempty(in_obj)
    if isa(in_obj, 'dsin')
        module = 'cal';
        % Find and replace the existing dsin with the input object
        dsin_found = false;
        for ii=1:numel(live_data.cal.dsin)
            if strcmp(live_data.cal.dsin(ii).filename, in_obj.filename)
                dsin_found = true;
                live_data.cal.dsin(ii) = in_obj;
                break;
            end
        end
        if ~dsin_found
            live_data.cal.dsin = vertcat(live_data.cal.dsin, in_obj);
        end
        
    elseif isa(in_obj, 'vidset')
        module = 'vid';
        vidset_found = false;
        for ii=1:numel(live_data.vid.vid_set)
            if in_obj.vidnum == live_data.vid.vid_set(ii).vidnum
                vidset_found = true;
                live_data.vid.vid_set(ii) = in_obj;
                break;
            end
        end
        if ~vidset_found
            live_data.vid.vid_set = vertcat(live_data.vid.vid_set, in_obj);
        end
        
    else % Montage (todo: make a montage object for pete's sake)
        
        
        
    end
end

%% Input from full and live pipeline
switch module
    case 'cal'
        % Update path text
        gui.cal_path_txt.Text = ['Calibration path: ', paths.cal];
        
        % Update data table
        c_names = gui.dsin_uit.ColumnName;
        % Shortcuts
        name_idx    = strcmpi(c_names, 'grid vid name');
        orient_idx  = strcmpi(c_names, 'H/V');
        fov_idx     = strcmpi(c_names, 'fov (°)');
        wl_nm_idx   = contains(c_names, '(nm)');
        match_idx   = strcmpi(c_names, 'matched vid name');
        cal_idx     = strcmpi(c_names, 'calibration file');
        
        % Until this is added to live_data, need to do a bit of redundant
        % processing
        cal_avi = dir(fullfile(paths.cal, '*.avi'));
        if isempty(cal_avi)
            return;
        end
        out_data = cell(numel(cal_avi), numel(c_names));
        for ii=1:numel(cal_avi)
            out_data{ii, name_idx} = cal_avi(ii).name;
            
            % Determine if this video is in a dsin object
            for jj=1:numel(live_data.cal.dsin)
                if strcmp(cal_avi(ii).name, ...
                        live_data.cal.dsin(jj).h_filename)
                    out_data{ii, orient_idx} = 'H';
                    out_data{ii, match_idx} = ...
                        live_data.cal.dsin(jj).v_filename;
                elseif strcmp(cal_avi(ii).name, ...
                        live_data.cal.dsin(jj).v_filename)
                    out_data{ii, orient_idx} = 'V';
                    out_data{ii, match_idx} = ...
                        live_data.cal.dsin(jj).h_filename;
                else
                    continue;
                end
                out_data{ii, fov_idx} = sprintf('%1.2f', ...
                    live_data.cal.dsin(jj).fov);
                out_data{ii, wl_nm_idx} = sprintf('%1.1f', ...
                    live_data.cal.dsin(jj).wavelength);
                out_data{ii, cal_idx} = live_data.cal.dsin(jj).filename;
            end
        end
        gui.dsin_uit.Data = out_data;
        % Color cells with missing data
        [rr, cc] = find(cellfun(@isempty, out_data));
        if isvector(out_data)
            rr = rr';
            cc = cc';
        end
        if ~isempty(rr)
            addStyle(gui.dsin_uit, uistyle('backgroundcolor', [1,0,0]), ...
                'cell', [rr,cc]);
        end
        % Fix cells without missing data
        [rr,cc] = find(~cellfun(@isempty, out_data));
        if isvector(out_data)
            rr = rr';
            cc = cc';
        end
        if ~isempty(rr)
            addStyle(gui.dsin_uit, uistyle('backgroundcolor', [1,1,1]), ...
                'cell', [rr,cc]);
        end
        
    case 'vid'
        gui.raw_path_txt.Text = ['Video path: ', paths.raw];
        if ~isfield(live_data, 'vid') || isempty(live_data.vid) || ...
                ~isfield(live_data.vid, 'vid_set') || isempty(live_data.vid.vid_set)
            return;
        end
        
        % Create style to track progress
        done_style = uistyle('backgroundcolor', [0,0.6902,0.3137]);
        
        c_names = gui.vid_uit.ColumnName;
        % Shortcuts
        num_idx = strcmpi(c_names, 'video #');
        mod_idx = strcmpi(c_names, 'modalities');
        ra_idx  = strcmpi(c_names, 'r/a');
        mon_idx = strcmpi(c_names, 'montage');
        an_idx  = strcmpi(c_names, 'analysis');
        
        % Construct table
        out_data = cell(numel(live_data.vid.vid_set), numel(c_names));
        done_cells = false(size(out_data));
        for ii=1:numel(live_data.vid.vid_set)
            out_data{ii, num_idx} = sprintf('%i', ...
                live_data.vid.vid_set(ii).vidnum);
            
            if live_data.vid.vid_set(ii).hasAllOutMods
                done_cells(ii, mod_idx) = true;
            end
            
            % todo: will need to modify once the full-loop is done
            if live_data.vid.vid_set(ii).processed
                done_cells(ii, ra_idx)  = true;
                % Determine if this video produced an image that is included in
                % the montage
                found_in_montage = false;
                for jj=1:numel(live_data.vid.vid_set(ii).vids)
                    for kk=1:numel(live_data.vid.vid_set(ii).vids(jj).fids)
                        for mm=1:numel(live_data.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                            key = findImageInMonDB(live_data, ...
                                live_data.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames(1));
                            if ~all(key == 0)
                                found_in_montage = true;
                                break;
                            end
                        end
                        if found_in_montage
                            break;
                        end
                    end
                    if found_in_montage
                        break;
                    end
                end
                if found_in_montage
                    done_cells(ii, mon_idx) = true;
                end
            end
        end
        gui.vid_uit.Data = out_data;
        if ~any(done_cells)
            return;
        end
        [rr, cc] = find(done_cells);
        if isvector(done_cells)
            rr = rr';
            cc = cc';
        end
        if ~isempty(rr)
            addStyle(gui.vid_uit, done_style, 'cell', [rr, cc]);
        end
        
    case 'mon'
        if ~isfield(live_data.vid, 'vid_set') || isempty(live_data.vid.vid_set) || ...
                ~isfield(live_data.mon, 'montages') || isempty(live_data.mon.montages)
            return;
        end
        gui.mon_path_txt.Text = ['Montage path: ', paths.mon];
        if isfield(live_data.mon, 'loc_file') && ~isempty(live_data.mon.loc_file)
            gui.loc_file_txt.Text = ['Location file: ', live_data.mon.loc_file.name];
        end
        
        % Get table column names
        c_names = gui.mon_uit.ColumnName;
        % Shortcuts
        num_idx = strcmpi(c_names, 'video #');
        fix_idx = strcmpi(c_names, 'expected location (°)');
        loc_idx = strcmpi(c_names, 'placed location (°)');
        mon_idx = strcmpi(c_names, 'group #');
        ign_idx = strcmpi(c_names, 'not placed');
        
        % Preallocate table
        % todo: have a counter of the number of images in ld.mon
        n_imgs = 0;
        for ii=1:numel(live_data.vid.vid_set)
            for jj=1:numel(live_data.vid.vid_set(ii).vids)
                for kk=1:numel(live_data.vid.vid_set(ii).vids(jj).fids)
                    for mm=1:numel(live_data.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                        n_imgs = n_imgs+1;
                    end
                end
            end
        end
        
        out_data = cell(n_imgs, numel(c_names));
        k=0;
        vn = cell2mat(cellfun(@str2double, ...
                live_data.mon.loc_data.vidnums, ...
                'uniformoutput', false));
        for ii=1:numel(live_data.vid.vid_set)
            this_vidnum = sprintf('%i', live_data.vid.vid_set(ii).vidnum);
            % Determine expected location
            li = vn == live_data.vid.vid_set(ii).vidnum;
            if ~any(li)
                continue;
            end
            this_ex_loc = live_data.mon.loc_data.coords(li, :);
            
            if live_data.vid.vid_set(ii).processed
                % Determine if this video produced an image that is included in
                % the montage
                for jj=1:numel(live_data.vid.vid_set(ii).vids)
                    for kk=1:numel(live_data.vid.vid_set(ii).vids(jj).fids)
                        for mm=1:numel(live_data.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                            k=k+1;
                            out_data{k, num_idx} = this_vidnum;
                            out_data{k, fix_idx} = this_ex_loc;
            
                            key = findImageInMonDB(live_data, ...
                                live_data.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames(1));
                            if ~all(key==0)
                                placed_loc = cell2mat(live_data.mon.montages(key(1)).txfms{key(2)}(2:3));
                                out_data{k, loc_idx} = sprintf('%1.2f, %1.2f', ...
                                    placed_loc(1), -placed_loc(2)); % -Y to go from image- to Euclid-indexing
                                out_data{k, mon_idx} = key(1);
                            else
                                out_data{k, ign_idx} = true;
                            end
                        end
                    end
                end
            end
        end
        gui.mon_uit.Data = out_data;
end

end

