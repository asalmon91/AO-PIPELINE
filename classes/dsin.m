classdef dsin
    %dsin desinusoid object
    %   For correction of static distortion due to sinusoidal scanning
    
    properties
        filename char = [];
        h_filename char = [];
        v_filename char = [];
        fov {mustBePositive, mustBeFinite} = [];
        wavelength {mustBePositive, mustBeFinite} = 790; %nm
        lpmm {mustBePositive, mustBeFinite} = []; % lines/mm grid spacing
        me_f_mm {mustBePositive, mustBeFinite} = []; % model eye focal length (mm)
        ppd {mustBePositive, mustBeFinite} = []; % pixels/degree
        mat {mustBeNumeric} = [];
        fringe_px {mustBePositive, mustBeFinite} = [];
        processing logical = false;
        processed logical = false;
    end
    
    methods
        function obj = dsin(filename, fov, wavelength)
            %dsin Construct an instance of dsin
            
            if nargin == 1
                obj.fov = getFOV(filename);
                obj.wavelength = getWavelength(filename);
            end
            if nargin >=1
                obj.filename = filename;
            end
            if nargin >= 2
                obj.fov = fov;
            end
            if nargin >= 3
                obj.wavelength = wavelength;
            end
        end
        
        function obj = construct_dsin_mat(obj, in_path)
            % Check that the object has all the necessary data
            has_horz = ~isempty(obj.h_filename);
            has_vert = ~isempty(obj.v_filename);
            has_fov  = ~isempty(obj.fov);
            has_wl   = ~isempty(obj.wavelength);
            has_lpmm = ~isempty(obj.lpmm);
            if any(~[has_horz, has_vert, has_fov, has_wl, has_lpmm])
                error('Not enough data to construct desinusoid matrix');
            end
            
            %% Start processing
            %% Add basic information for processing
            % Create a temporary structure to work with old version of PIPE
            % for now
            dsin_data.horizontal_fringes_path       = in_path;
            dsin_data.vertical_fringes_path         = in_path;
            dsin_data.horizontal_fringes_filename   = obj.h_filename;
            dsin_data.vertical_fringes_filename     = obj.v_filename;
            dsin_data.fov                           = obj.fov;
            dsin_data.wl_nm                         = obj.wavelength;
            dsin_data.lpmm                          = obj.lpmm;

            %% Process horizontal and vertical grids
            dsin_data = process_grids(fullfile(in_path, obj.h_filename), 'h', dsin_data);
            dsin_data = process_grids(fullfile(in_path, obj.v_filename), 'v', dsin_data);

            %% Create desinusoid matrix
            [dsin_data, dsin_mat_fname] = create_dsin_mat(dsin_data);
            fprintf('%s created.\n', dsin_mat_fname);
            obj.filename = dsin_mat_fname;
            obj.mat = dsin_data.vertical_fringes_desinusoid_matrix;
            obj.fringe_px = dsin_data.horizontal_fringes_fringes_period;
            obj.processed = true;
            obj.processing = false;
        end
        
        %% Setters
        function obj = set.lpmm(obj, lpmm)
            % Lines per mm, grid spacing
            obj.lpmm = lpmm;
        end
        
        function obj = set.me_f_mm(obj, me_f_mm)
            % Model Eye Focal Length (mm)
            obj.me_f_mm = me_f_mm;
        end
        
        function obj = set.ppd(obj, ppd)
            % Pixels per degree
            obj.ppd = ppd;
        end
        
        %% Getters
        function lpmm = get.lpmm(obj)
            % Lines per mm, grid spacing
            lpmm = obj.lpmm;
        end
        
        function me_f_mm = get.me_f_mm(obj)
            % Model Eye Focal Length (mm)
            me_f_mm = obj.me_f_mm;
        end
        
        %% Scaling
        function obj = updatePPD(obj)
            if ~obj.processed || isempty(obj.lpmm) || isempty(obj.me_f_mm)
                warning('Must be processed and have lpmm and me_f_mm');
                return;
            end
            
            me_f_um = obj.me_f_mm*1000; % convert to microns
            obj.ppd = 1/(((1000/obj.lpmm)/obj.fringe_px/me_f_um)*(180/pi));
        end
    end
end

