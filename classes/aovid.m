classdef aovid
    %aovid is an AOSLO video that belongs to a set
    
    properties
        filename char = '';
        % e.g., confocal, direct, reflect
        modality char = ''; 
        % e.g., 790 [nm]
        wavelength double {mustBePositive, mustBeFinite} = 790;
        ready logical = [];
        frames = []; % arfs structure, todo: make this a class
        fids = []; % arfs structure, includes link ids, cluster ids, frame ids, and output image names
        t_create double = []; % clock vectors for profiling
    end
    
    methods
        function obj = aovid(filename, modality, wavelength)
            %aovid Construct an instance of this class
            obj.t_create = clock;
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
                obj = updateModality(obj);
                obj = updateWavelength(obj);
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
        
        function obj = updateReady(obj, in_path)
            %updateReady checks if this video is available for processing
            obj.ready = isReadable(in_path, obj.filename);
        end
        
        function dmb_list = getAllDMBs(obj)
            % Determine # for pre-allocation
            n_dmbs = 0;
            for ii=1:numel(obj.fids)
                for jj=1:numel(obj.fids(ii).cluster)
                    if isfield(obj.fids(ii).cluster(jj), 'success') && ...
                            obj.fids(ii).cluster(jj).success
                        n_dmbs = n_dmbs+1;
                    end
                end
            end
            
            % Pre-allocate and populate
            dmb_list = cell(n_dmbs, 1);
            k=0;
            for ii=1:numel(obj.fids)
                for jj=1:numel(obj.fids(ii).cluster)
                    if isfield(obj.fids(ii).cluster(jj), 'success') && ...
                            obj.fids(ii).cluster(jj).success
                        k=k+1;
                        dmb_list{k} = obj.fids(ii).cluster(jj).dmb_fname;
                    end
                end
            end
        end
    end
end

