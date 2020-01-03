classdef dsin
    %dsin desinusoid object
    %   For correction of static distortion due to sinusoidal scanning
    
    properties
        filename char = [];
        h_filename char = [];
        v_filename char = [];
        fov {mustBePositive, mustBeFinite} = [];
        wavelength {mustBePositive, mustBeFinite} = 790; %nm
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
            if any(~[has_horz, has_vert, has_fov, has_wl])
                error('Not enough data to construct desinusoid matrix');
            end
            
            % Check that the grid videos are valid
            h_exists = exist(fullfile(in_path, obj.h_filename), 'file') ~= 0;
            v_exists = exist(fullfile(in_path, obj.v_filename), 'file') ~= 0;
            if any(~[h_exists, v_exists])
                error('Failed to find grid videos');
            end
            
            % Math goes here
            
        end
    end
end

