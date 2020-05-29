classdef aoslo_image < image_set
    %UNTITLED18 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        modality char; 
        wavelength_nm numeric;
        input_ffname char;
        output_ffname char;
        clusterAddress; % indexing array to find this image in the vid db
    end
    
    methods
        function obj = untitled18(inputArg1,inputArg2)
            %UNTITLED18 Construct an instance of this class
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

