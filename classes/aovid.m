classdef aovid
    %aovid is an AOSLO video that belongs to a set
    
    properties
        filename char = '';
        
        % e.g., confocal, direct, reflect
        modality char = ''; 
        
        % e.g., 790 [nm]
        wavelength double {mustBePositive, mustBeFinite} = 790;
        
    end
    
    methods
        function obj = aovid(filename, modality, wavelength)
            %aovid Construct an instance of this class
            if nargin >= 1
                obj.filename = filename;
            end
            if nargin >= 2
                obj.modality = modality;
            end
            if nargin == 3
                obj.wavelength = wavelength;
            end
            if nargin == 1
                obj = obj.updateModality();
                obj = obj.updateWavelength();
            end
        end
        
        function obj = updateModality(obj)
            %updateModality extracts modality from filename
            if ~isempty(obj.filename)
                nameparts = strsplit(obj.filename, '_');
                modality_str = nameparts{end-1};
                if strcmpi(modality_str, 'det')
                    modality_str = 'split_det';
                end
                obj.modality = modality_str;
            end
            
        end
        function obj = updateWavelength(obj)
            %updateWavelength extracts wavelength from filename
            if ~isempty(obj.filename)
                % Search for an underscore surrounded set of digits followed by nm
                expr_start = '[_][\d]+nm[_]';
                expr_end = 'nm[_]';
                wl_start = regexp(obj.filename, expr_start);
                wl_end   = regexp(obj.filename, expr_end);
                wl_string = obj.filename(wl_start+1:wl_end-1);
                obj.wavelength = str2double(wl_string);
            end
        end
    end
end

