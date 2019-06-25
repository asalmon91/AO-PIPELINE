function [status, err] = fn_create_split_avg(in_path, direct_fname)
%create_split_avg finds corresponding reflect and creates the split and avg
%videos

% Default, false = failure
status = false;
err = [];

% Guess reflect fname
direct_ffname = fullfile(in_path, direct_fname);
[~, direct_name, ext] = fileparts(direct_ffname);
reflect_fname = [strrep(direct_name, '_direct_', '_reflect_'), ext];
reflect_ffname = fullfile(in_path, reflect_fname);

% Check to see if file name successfully changed
if strcmp(direct_ffname, reflect_ffname)
    err = sprintf('_direct_ not found in %s', direct_fname);
    return;
end

% Check file info
direct_finfo    = dir(direct_ffname);
reflect_finfo   = dir(reflect_ffname);
if direct_finfo.bytes == 0 || reflect_finfo.bytes == 0
    err = sprintf('%s or %s empty', direct_fname, reflect_fname);
    return;    
end

% Split and avg file names
avg_fname   = strrep(direct_fname, '_direct_', '_avg_');
split_fname  = strrep(direct_fname, '_direct_', '_split_det_');
if strcmp(direct_fname, avg_fname) || strcmp(reflect_fname, split_fname)
    err = sprintf('_direct_ not found in %s', direct_fname);
    return;
end
avg_ffname      = fullfile(in_path, avg_fname);
split_ffname    = fullfile(in_path, split_fname);

% Don't overwrite
if exist(avg_ffname, 'file') ~= 0 && exist(split_ffname, 'file') ~= 0
    warning('%s & %s already exist, not overwriting', ...
        avg_fname, split_fname);
    status = true;
    return;
end

%% Creating video reader objects
% Running into "Failed to initialize internal resources" errors when used
% in a parfor. For now, just do nothing
try
    vr_reflect    = VideoReader(reflect_ffname);
    vr_direct     = VideoReader(direct_ffname);
catch MException
    err = MException.message;
%     warning(err);
    fprintf('Failed to read %s or %s.\n', direct_fname, reflect_fname);
    return;
end
nFrames       = round(vr_reflect.Duration*vr_reflect.FrameRate);

% Creating and opening movie objects (uncompressed)
vw_split = VideoWriter(split_ffname, 'Grayscale AVI');
vw_avg = VideoWriter(avg_ffname, 'Grayscale AVI');
set(vw_split, 'FrameRate', vr_reflect.FrameRate);
set(vw_avg, 'FrameRate', vr_reflect.FrameRate);
open(vw_split);
open(vw_avg);
try    
    for ii=1:nFrames
        
        % Load current frame
        current_image_direct      = double(readFrame(vr_direct));
        current_image_reflect     = double(readFrame(vr_reflect));
        
        % Normalize the images using the MEAN and not the MAXIMUM
        current_image_direct 	= current_image_direct  / mean(current_image_direct(:));
        current_image_reflect	= current_image_reflect / mean(current_image_reflect(:));
        
        % Calculating split-detection image
        current_image_split_det   = (current_image_direct - current_image_reflect + eps) ./ ...
            (current_image_direct + current_image_reflect + eps);
        
        % Calculating average image
        current_image_avg     = (current_image_direct + current_image_reflect)/2;
            
        % Contrast stretching
        current_image_split_det = contrast_stretch(current_image_split_det);
        current_image_avg = contrast_stretch(current_image_avg);
        
        % Write
        writeVideo(vw_split, uint8(current_image_split_det));
        writeVideo(vw_avg, uint8(current_image_avg));
    end
    %% Closing movies
    close(vw_split);
    close(vw_avg);
    
catch
    err = sprintf('%s failed', direct_fname);
    if exist('vw_split', 'var')
        close(vw_split);
    end
    if exist('vw_avg', 'var')
        close(vw_avg);
    end
    
    % Delete files as well to avoid the pipeline thinking they exist
    if exist(split_ffname, 'file') ~= 0
        fprintf('Failed to write %s, removing.\n', split_fname);
        delete(split_ffname);
    end
    if exist(avg_ffname, 'file') ~= 0
        fprintf('Failed to write %s, removing.\n', avg_fname);
        delete(avg_ffname);
    end
    
    return;
end

% If this line executes, everything worked... or I missed something.
fprintf('%s and %s written.\n', split_fname, avg_fname);
status = true;

end

