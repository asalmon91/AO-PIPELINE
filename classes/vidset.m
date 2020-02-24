classdef vidset
    %vidset is a set of simultaneously acquired AOSLO videos
    
    properties
        vidnum {mustBeNumeric, mustBeNonnegative, mustBeFinite, isscalar};
        fov {mustBeNumeric, mustBePositive, mustBeFinite, isscalar};
        vids aovid;
        processing logical  = false;
        processed logical   = false;
        hasCal logical      = false;
        hasAllMods logical  = false;
        % clock arrays for profiling
        t_proc_create double    = [];
        t_proc_start double     = [];
        t_proc_end double       = [];
        t_proc_read double      = [];
        t_proc_dsind double     = [];
        t_proc_arfs double      = [];
        t_proc_ra double        = [];
        t_proc_mon double       = [];
    end
    
    methods
        function obj = vidset(vidnum, fov)
            %vidset Construct an instance of this class
            obj.t_proc_create = clock;
            if nargin >= 1
                obj.vidnum = vidnum;
            end
            if nargin == 2
                obj.fov = fov;
            end
        end
        
        function vidNumStr = getVidNumStr(obj)
            %getVidNumStr Converts numeric video number to 0-padded string
            vidNumStr = pad(num2str(obj.vidnum), 4, 'left', '0');
        end
        
        function obj = addVids(obj, filenames)
            %addVids adds an aovid object array to the vidset
            if ~iscell(filenames) %todo: check if char as well
                filenames = {filenames};
            end
            aovids(numel(filenames)) = aovid;
            for ii=1:numel(filenames)
                aovids(ii) = aovid(filenames{ii});
            end
            obj.vids = aovids;
        end
        
        function obj = updateVideoNumber(obj)
            if ~isempty(obj.vids)
                % Use first file name to extract video number
                fname = obj.vids(1).filename;
                nameparts = strsplit(fname, '.');
                nameparts = strsplit(nameparts{1}, '_');
                vidNumStr = nameparts{end};
                obj.vidnum = str2double(vidNumStr);
            end
        end
        
        function fnames = getAllFnames(obj)
            % Returns a cell array of all filenames in the vids property
            fnames = cell(numel(obj.vids), 1);
            for ii=1:numel(fnames)
                fnames{ii} = obj.vids(ii).filename;
            end
        end
    end
end

