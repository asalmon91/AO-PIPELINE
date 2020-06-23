classdef vidset
    %vidset is a set of simultaneously acquired AOSLO videos
    
    properties
        vidnum {mustBeNumeric, mustBeNonnegative, mustBeFinite, isscalar};
        fov {mustBeNumeric, mustBePositive, mustBeFinite, isscalar};
        vids aovid;
        processing logical      = false;
        processed logical       = false;
        hasCal logical          = false;
        hasAllMods logical      = false;
        hasAllOutMods logical   = false;
        hasAnySuccess logical   = false;
        % PROFILING
        % If storage is a concern, all of the t_proc fields can be removed,
        % but keep the profiling field and set to false
        profiling logical       = true;
        t_proc_create double    = []; % When object is created
        t_full_mods double      = []; % When secondaries are created
        % R/A (registration and averaging)
        t_proc_start double     = []; % When r/a is started
        t_proc_read double      = []; % When video is read for r/a
        t_proc_dsind double     = []; % When video is desinusoided
        t_proc_arfs double      = []; % When reference frames are selected
        t_proc_ra double        = []; % When DeMotion is finished
        t_proc_emr double       = []; % When Eye-motion-repair is finished
        t_proc_end double       = []; % When r/a is finished
        % Montaging
        t_proc_mon double       = []; % When an image is placed in a montage
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
        
        function fnames = getVidFilenameFromChannel(obj, in_channel)
            % getVidFromChannel returns a Mx1 cell array of filenames that
            % match the input channels
            %   in_channel is a Mx2 cell array where the first column
            %   contains modality strings and the second column is
            %   wavelength (numeric)
            fnames = cell(size(in_channel, 1), 1);
            for ii=1:numel(fnames)
                this_fname = obj.vids(...
                    strcmp({obj.vids.modality}, in_channel{ii,1}) & ...
                    [obj.vids.wavelength] == in_channel{ii,2}).filename;
                if ~isempty(this_fname)
                    fnames{ii} = this_fname;
                else
                    % Warn? for now, just leave empty
                end
            end
        end
        
        function obj = makeSecondaries(obj, in_path)
            % Generate secondary modalities
            % todo: include options like the mapping between input channels
            % and output channels and the specific operations to get there
            % for now, just hard-code direct and reflect into split and avg
            
            % Construct formulas
            make_split  = @(x,y) (x-y +eps)./(x+y +eps);
            make_avg    = @(x,y) (x+y)./2;
            
            % Get all filenames currently in this vidset obj
            all_fnames = obj.getAllFnames;
            
            % Check to see if they already exist in the object
            skip_split  = false;
            skip_avg    = false;
            split_idx   = contains(all_fnames, 'split_det');
            avg_idx     = contains(all_fnames, 'avg');
            if any(split_idx)
                skip_split = exist(fullfile(in_path, ...
                    obj.vids(split_idx).filename), 'file') ~= 0;
            end
            if any(avg_idx)
                skip_avg = exist(fullfile(in_path, ...
                    obj.vids(avg_idx).filename), 'file') ~= 0;
            end
            if skip_split && skip_avg
                return;
            end
            
            % Get direct video
            direct_idx = contains(all_fnames, 'direct');
            reflect_idx = contains(all_fnames, 'reflect');
            % todo: include failsafe for more than one of each
            if ~any(direct_idx) || ~any(reflect_idx)
                if ~any(direct_idx)
                    missing_mod = 'direct';
                else
                    missing_mod = 'reflect';
                end 
                warning('video %i is missing %s', obj.vidnum, missing_mod);
                return;
            end
            
            % Check that these exist at the expected location
            direct_exists = exist(fullfile(in_path, all_fnames{direct_idx}), 'file') ~= 0;
            reflect_exists = exist(fullfile(in_path, all_fnames{reflect_idx}), 'file') ~= 0;
            if ~direct_exists || ~reflect_exists
                if ~direct_exists
                    missing_mod = 'direct';
                else
                    missing_mod = 'reflect';
                end 
                warning('%s #%i not found in %s', obj.vidnum, missing_mod, in_path);
                return;
            end
            direct_fname = all_fnames{direct_idx};
            reflect_fname = all_fnames{reflect_idx};
            
            % Read primaries
            vr_direct = VideoReader(fullfile(in_path, direct_fname));
            vr_reflect  = VideoReader(fullfile(in_path, reflect_fname));
            direct_dims = [vr_direct.Height, vr_direct.Width, vr_direct.NumFrames];
            reflect_dims = [vr_reflect.Height, vr_reflect.Width, vr_reflect.NumFrames];
            
            % Check that these are consistent
            if ~all(direct_dims == reflect_dims)
                warning('Video #%i direct and reflect dimensions are not consistent', obj.vidnum);
                return;
            end
            
            % Construct secondary video aovid objects and writers
            % Get wavelength
            wl = obj.vids(direct_idx).wavelength;
            if ~skip_split
                split_fname = strrep(direct_fname, 'direct', 'split_det');
                split_aovid = aovid(split_fname, 'split_det', wl);
                vw_split = VideoWriter(fullfile(in_path, split_fname), 'Grayscale AVI');
                set(vw_split, 'FrameRate', vr_reflect.FrameRate);
                open(vw_split);
            end
            if ~skip_avg
                avg_fname = strrep(direct_fname, 'direct', 'avg');
                avg_aovid = aovid(avg_fname, 'avg', wl);
                vw_avg = VideoWriter(fullfile(in_path, avg_fname), 'Grayscale AVI');
                set(vw_avg, 'FrameRate', vr_reflect.FrameRate);
                open(vw_avg);
            end
            
            % Read, transform, write
            try
                for ii=1:direct_dims(3)
                    % Read
                    direct_frame = single(gpuArray(readFrame(vr_direct)));
                    reflect_frame = single(gpuArray(readFrame(vr_reflect)));

                    % Normalize
                    direct_frame = direct_frame./mean(direct_frame(:));
                    reflect_frame = reflect_frame./mean(reflect_frame(:));

                    if ~skip_split
                        writeVideo(vw_split, gather(uint8(contrast_stretch(...
                            make_split(direct_frame, reflect_frame)))));
                    end
                    if ~skip_avg
                        writeVideo(vw_avg, gather(uint8(contrast_stretch(...
                            make_avg(direct_frame, reflect_frame)))));
                    end
                end
            catch me
                close(vw_split);
                close(vw_avg);
                rethrow(me);
            end
            % Close writers and update aovid array
            if ~skip_split
                close(vw_split);
                split_aovid.ready = true;
                split_aovid.t_create = clock;
                obj.vids = vertcat(obj.vids, split_aovid);
            end
            if ~skip_avg
                close(vw_avg);
                avg_aovid.ready = true;
                avg_aovid.t_create = clock;
                obj.vids = vertcat(obj.vids, avg_aovid);
            end
            
            % Update profiling and progress fields
            obj.t_full_mods = clock;
            obj.hasAllOutMods = true;
        end
        
        function obj = updateHasAnySuccess(obj)
            for ii=1:numel(obj.vids)
                for jj=1:numel(obj.vids(ii).fids)
                    for kk=1:numel(obj.vids(ii).fids(jj).cluster)
                        if isfield(obj.vids(ii).fids(jj).cluster(kk), 'success') && ...
                                vid_set.vids(jj).fids(kk).cluster(mm).success
                            obj.hasAnySuccess = true;
                            return;
                        end
                    end
                end
            end
        end
    end
end

