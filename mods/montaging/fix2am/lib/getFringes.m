function fringes = getFringes(dsin_path, dsin_fnames)
%getFringes Extracts the fringes from desinusoid files

FOV_C = 1;
FRINGE_C = 2;
fringes = zeros(numel(dsin_fnames), 2);
for ii=1:numel(dsin_fnames)
    dsin = load(fullfile(dsin_path, dsin_fnames{ii}));
    % Determine FOV from H&V video headers
    
    % todo: check if this file has these fields
    h_head = strrep(dsin.horizontal_fringes_filename, '.avi', '.mat');
    v_head = strrep(dsin.vertical_fringes_filename, '.avi', '.mat');
    if exist(fullfile(dsin_path, h_head), 'file') == 0 || ...
            exist(fullfile(dsin_path, v_head), 'file') == 0
        % Then the videos are not in the same location as the desinusoid
        % file and we need to try the less robust method of extracting it
        % from the filename
        warning('Videos for %s not found, guessing FOV from file name', ...
            dsin_fnames{ii});
        % Guess from file name
        % todo: add fail-safes
        nameparts = strsplit(dsin_fnames{ii}, '_');
        fovstr = nameparts{find(contains(nameparts, 'deg')) - 1};
        fov = str2double(strrep(fovstr, 'p', '.'));
        fringe = dsin.horizontal_fringes_fringes_period;
    else
        % Load video headers
        h_head_data = load(fullfile(dsin_path, h_head));
        v_head_data = load(fullfile(dsin_path, v_head));
        
        % todo: check to see if these files have the expected fields
        if h_head_data.optical_scanners_settings. ...
                raster_scanner_amplitude_in_deg == ...
                v_head_data.optical_scanners_settings. ...
                raster_scanner_amplitude_in_deg
            fov = h_head_data.optical_scanners_settings. ...
                raster_scanner_amplitude_in_deg;
            fringe = dsin.horizontal_fringes_fringes_period;
        else
            % Videos used to make this desinusoid file don't have the same
            % FOV. Warn and skip
            warning('%s made with a %1.2f and %1.2f FOV, skipping', ...
                dsin_fnames{ii}, ...
                h_head_data.optical_scanners_settings. ...
                raster_scanner_amplitude_in_deg, ...
                v_head_data.optical_scanners_settings. ...
                raster_scanner_amplitude_in_deg)
            fov = NaN;
            fringe = NaN;
        end
    end
    
    fringes(ii, FOV_C) = fov;
    fringes(ii, FRINGE_C) = fringe;
end



end

