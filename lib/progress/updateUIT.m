function uit = updateUIT(uit, data_struct, raw_path)
%updateUIT Updates the UI tables in the progress window according to the
%handle uit

labels = get(uit, 'columnname');
uit_data = get(uit, 'Data');
% Make sure there are enough rows in the table
if numel(data_struct) > size(uit_data,1)
    uit_data = vertcat(uit_data, cell(...
        numel(data_struct) - size(uit_data,1), numel(labels)));
end

switch get(uit, 'tag')
    case 'dsin_uit'
        
        % Shortcuts
        fov_col = strcmpi(labels, 'fov');
        fringe_col = strcmpi(labels, 'fringe');
        fname_col = strcmpi(labels, 'file name');
        for ii=1:numel(data_struct)
            uit_data{ii, fov_col} = data_struct(ii).lut.fov;
            uit_data{ii, fringe_col} = data_struct(ii).lut.fringe;
            uit_data{ii, fname_col} = data_struct(ii).lut.fname;
        end
        
    
    case 'vid_uit'
        
        % Shortcuts
        % todo: find a dynamic way to do this for a more modular pipeline
        num_col = strcmpi(labels, 'video #');
        sec_col = strcmpi(labels, 'secondaries');
        arfs_col = strcmpi(labels, 'arfs');
        nest_col = strcmpi(labels, 'nest');
        demotion_col = strcmpi(labels, 'demotion');
        emr_col = strcmpi(labels, 'emr');
%         trim_col = strcmpi(labels, 'trim');
        montage_col = strcmpi(labels, 'montage');
        analysis_col = strcmpi(labels, 'analysis');
        
        % Get other paths based on raw
        % todo: determine a better way to do this
        fi = strfind(flip(raw_path), filesep);
        root_path = raw_path(1:end-fi(1));
        emr_path = fullfile(root_path, 'Processed', 'SR_TIFs', 'Repaired');
%         trim_path = fullfile(emr_path, 'trim');
        
        for ii=1:numel(data_struct)
            % Update number
            vid_num = data_struct(ii).num;
            if isempty(uit_data{ii, num_col})
                uit_data{ii, num_col} = vid_num;
            end
            
            % Update secondaries
            % todo: what if we don't want secondaries...
            % should include mod_order as an input and loop through to make
            % sure each mod/wavelength combo are included
            if isempty(uit_data{ii, sec_col}) || ~uit_data{ii, sec_col}
                if isfield(data_struct(ii), 'mods') && ...
                        contains('split_det', data_struct(ii).mods) && ...
                        contains('avg', data_struct(ii).mods)
                    uit_data{ii, sec_col} = true;
                else
                    uit_data{ii, sec_col} = false;
                end
            end
            
            % Update ARFS
            if isempty(uit_data{ii, arfs_col}) || ...
                    islogical(uit_data{ii, arfs_col}) && ...
                    ~uit_data{ii, arfs_col}
                
                arfs_dir = dir(fullfile(raw_path, ...
                    sprintf('*_%s_arfs.mat', vid_num)));
                arfs_failed = false(size(arfs_dir));
                for jj=1:numel(arfs_dir)
                    load(fullfile(raw_path, arfs_dir(jj).name), ...
                        'frames');
                    if isfield(frames(1), 'TRACK_MOTION_FAILED') && ...
                            frames(1).TRACK_MOTION_FAILED
                        arfs_failed(jj) = true;
                    end
                end
                if isempty(arfs_dir)
                    uit_data{ii, arfs_col} = false;
                elseif all(arfs_failed)
                    uit_data{ii, arfs_col} = 'FAIL';
                    uit_data = fillFail(uit_data, ii, find(arfs_col));
                    continue;
                else
                    uit_data{ii, arfs_col} = true;
                end
            end
            
            % Update NEST
            if isempty(uit_data{ii, nest_col}) || ~uit_data{ii, nest_col}
                nest_dir = dir(fullfile(raw_path, ...
                    sprintf('*_%s_nest.mat', vid_num)));
                uit_data{ii, nest_col} = ~isempty(nest_dir);
            end
            
            % Update DeMotion
            if isempty(uit_data{ii, demotion_col}) || ...
                    islogical(uit_data{ii, demotion_col}) && ...
                    ~uit_data{ii, demotion_col}
                
                dm_dir = dir(fullfile(raw_path, ...
                    sprintf('%s_regAvg.mat', vid_num)));
                for jj=1:numel(dm_dir) % Should only ever be 0 or 1
                    dm_success = load(fullfile(raw_path, dm_dir(jj).name), ...
                        'status');
                end
                if isempty(dm_dir)
                    uit_data{ii, demotion_col} = false;
                elseif ~dm_success.status
                    uit_data{ii, demotion_col} = 'FAIL';
                    uit_data = fillFail(uit_data, ii, find(demotion_col));
                    continue;
                else
                    uit_data{ii, demotion_col} = true;
                end
            end
            
            % Update EMR
            if isempty(uit_data{ii, emr_col}) || ~uit_data{ii, emr_col}
                if exist(emr_path, 'dir') ~= 0
                    emr_search = dir(fullfile(emr_path, ...
                        sprintf('*_%s_*_Repaired.tif', vid_num)));
                    uit_data{ii, emr_col} = ~isempty(emr_search);
                else
                    uit_data{ii, emr_col} = false;
                end
            end
            
            % Update trim
%             if isempty(uit_data{ii, trim_col}) || ~ uit_data{ii, trim_col}
%                 if exist(trim_path, 'dir') ~= 0
%                     trim_search = dir(fullfile(trim_path, ...
%                         sprintf('*_%s_*_Repaired.tif', vid_num)));
%                     uit_data{ii, trim_col} = ~isempty(trim_search);
%                 else
%                     uit_data{ii, trim_col} = false;
%                 end
%             end
            
            % Update montage
            if isempty(uit_data{ii, montage_col}) || ...
                    ~uit_data{ii, montage_col}
                if isfield(data_struct(ii), 'montaged')
                    uit_data{ii, montage_col} = data_struct(ii).montaged;
                else
                    uit_data{ii, montage_col} = false;
                end
            end
            
            % Update analysis
            if isempty(uit_data{ii, analysis_col}) || ...
                    ~uit_data{ii, analysis_col}
                if isfield(data_struct(ii), 'analyzed')
                    uit_data{ii, analysis_col} = data_struct(ii).analyzed;
                else
                    uit_data{ii, analysis_col} = false;
                end
            end
        end
end

% Update table
set(uit, 'Data', uit_data);

end

function data_table = fillFail(data_table, row_idx, col_idx)
n_cols = size(data_table,2);
if col_idx+1 > n_cols
    return;
end
data_table(row_idx, col_idx+1:n_cols) = ...
    num2cell(false(1, numel(col_idx+1:n_cols)));

end





