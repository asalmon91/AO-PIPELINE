classdef montage
    %montage Describes a container for a set of sequentially acquired
    %image_set objects
    
    properties
        scale_ppd {mustBePositive, mustBeFinite, mustBeReal};
        eye_side = 'OX'; % Could be OD, OS, OX (OX if simulation)
        dims = imref2d(); % Global spatial referencing object
        image_sets image_set;
    end
    
    methods
        function obj = untitled16(inputArg1,inputArg2)
            %UNTITLED16 Construct an instance of this class
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

