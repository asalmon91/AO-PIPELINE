classdef image_set < montage
    %image_set Describes the container for a set of simultaneously acquired
    %aoslo_image objects
    
    properties
        vidnum {mustBeNumeric, mustBeNonnegative, mustBeFinite, isscalar};
        fov {mustBeNumeric, mustBePositive, mustBeFinite, isscalar};
        imgs aoslo_image;
        tform = affine2d(eye(3));
        tform_type char = '';
        nom_loc_deg = [0,0];
    end
    
    methods
        function obj = image_set(inputArg1,inputArg2)
            %UNTITLED17 Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

