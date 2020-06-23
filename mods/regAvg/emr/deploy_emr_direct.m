function [status, stdout] = deploy_emr_direct(dmp_ffnames, img_path, current_modality)
%emr_loop Runs EMR without using a command line argument to call the script
% todo: The only thing that "needs" python is reading the .dmp; that should
% be made its own function. Otherwise, all the math here can be done in
% matlab

%% Allow single file, but convert to cell to enable batch
if ~iscell(dmp_ffnames)
    dmp_ffnames = {dmp_ffnames};
end

%% Get python environment
pe = pyenv;
if str2double(pe.Version) >= 3
    try
        pyenv('Version', 2.7)
    catch me
        error('Python 2.7 is required... I think')
    end
end

%% Start EMR loop
for ii=1:numel(dmp_ffnames)
    % Check input
    [~, dmp_name, dmp_ext] = fileparts(dmp_ffnames{ii});
    if ~strcmpi(dmp_ext, '.dmp')
        warning('File must be ".dmp", instead, is %s', dmp_ext);
        continue;
    end
    % Reconstruct file name
    dmp_fname = [dmp_name, dmp_ext];
    
    %% Find applicable images
    % Find all the images in this directory that match the filename with
    % its modality switched
    if ~contains(dmp_fname, current_modality)
        warning('%s does not contain %s', dmp_fname, current_modality);
        continue;
    end
    search_name = strrep(dmp_fname, current_modality, '*');
    search_name = strrep(search_name, '.dmp', '*.tif');
    search_results = dir(fullfile(img_path, search_name));
    if isempty(search_results)
        warning('No images found in %s matching %s', img_path, search_name);
        continue;
    end
    img_fnames = {search_results.name}';
    
    %% Load dmp
    fid = py.open(dmp_ffnames{ii}, 'r');
    pick = py.pickle.load(fid);
    fid.close();
    
    %% Get shifts
    ff_translation_info_rowshift = int16(pick{'full_frame_ncc'}{'row_shifts'});
    ff_translation_info_colshift = int16(pick{'full_frame_ncc'}{'column_shifts'});
    strip_translation_info = cell(pick{'sequence_interval_data_list'});

    %% Working off images, so no need to worry about desinusoiding
%     static_distortion = [];
%     firsttime = true;
    
    %% Determine boundaries
%     minmaxpix = [];
%     for jj=1:numel(strip_translation_info)
% %     for frame in strip_translation_info
%         frame = cell(strip_translation_info{jj});
%         for kk=1:numel(frame)
%             ref_pixels = uint16(frame{kk}{'slow_axis_pixels_in_current_frame_interpolated'});            
%             minmaxpix = vertcat(minmaxpix, [ref_pixels(1), ref_pixels(end)]); %#ok<AGROW>
%         end
%     end
%     topmostrow      = max(minmaxpix(:, 1));
%     bottommostrow   = min(minmaxpix(:, 2));
    
    %% Get shifts
    shift_array = zeros(numel(strip_translation_info)*3, 1000);
    shift_ind = 0;
    for jj=1:numel(strip_translation_info)    
        frame = cell(strip_translation_info{jj});
        if isempty(frame)
            continue;
        end
        
        % Don't forget they use 0-based indexing
        this_frame = frame{1};
        frame_ind = this_frame{'frame_index'}+1;
            
        % Make arrays for shifts
        slow_axis_pixels    = py.numpy.zeros(1);
        all_col_shifts      = py.numpy.zeros(1);
        all_row_shifts      = py.numpy.zeros(1);
        for kk=1:numel(frame)
            slow_axis_pixels = py.numpy.append(slow_axis_pixels, ...
                frame{kk}{'slow_axis_pixels_in_reference_frame'});

            ff_row_shift = ff_translation_info_rowshift(frame_ind);
            ff_col_shift = ff_translation_info_colshift(frame_ind);

            % First set the relative shifts
            row_shift = (py.numpy.subtract( ...
                frame{kk}{'slow_axis_pixels_in_reference_frame'}, ...
                frame{kk}{'slow_axis_pixels_in_current_frame_interpolated'}));
            col_shift = frame{kk}{'fast_axis_pixels_in_reference_frame_interpolated'};

            % These will contain all of the motion, not the relative 
            % motion between the aligned frames-
            % So then subtract the full frame row shift
            row_shift = py.numpy.add(row_shift, ff_row_shift);
            col_shift = py.numpy.add(col_shift, ff_col_shift);
            all_col_shifts = py.numpy.append(all_col_shifts, col_shift);
            all_row_shifts = py.numpy.append(all_row_shifts, row_shift);
        end
            
        % Convert and ignore that first element
        slow_axis_pixels = uint16(slow_axis_pixels);
        slow_axis_pixels = slow_axis_pixels(2:end);
        all_col_shifts = single(all_col_shifts);
        all_col_shifts = all_col_shifts(2:end);
        all_row_shifts = single(all_row_shifts);
        all_row_shifts = all_row_shifts(2:end);

        % Add to shift array
        shift_array(shift_ind*3+1, 1:numel(slow_axis_pixels))   = slow_axis_pixels;
        shift_array(shift_ind*3+2, 1:numel(all_col_shifts))     = all_col_shifts;
        shift_array(shift_ind*3+3, 1:numel(all_row_shifts))     = all_row_shifts;
            
        % Increment shift index
        shift_ind = shift_ind+1;
    end
    
    rois = uint16(py.numpy.array(pick{'strip_cropping_ROI_2'}{1}));
    rois = num2cell(rois);
    
    shift_array = single(py.numpy.array(shift_array));
    
    %% Repair these images
    for jj=1:numel(img_fnames)
        Eye_Motion_Distortion_Repair(img_path, img_fnames{jj}, ...
            rois, shift_array, []);
    end
end

end

