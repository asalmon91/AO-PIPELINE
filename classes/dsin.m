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
    end
end

