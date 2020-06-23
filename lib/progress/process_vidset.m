function vid_set = process_vidset(vid_set, dsins, paths, opts, ~)
%process_vidset performs several processing steps: secondary modality
%creation, registration and averaging, and statistical eye motion 
% correction

%% Constants
SUCCESS_CRIT    = 2/3; % Min img height
SHORT_CIRCUIT   = 1/3; % Max strip size
LPS_0           = 6; % Starting lines per strip
NCC_THR_0       = 0.1; % Starting NCC threshold (gets adjusted before application)
SS_FB_FX        = @(x) 2.*x; % Feedback function for iterating strip size
LBSS            = 6; % lines between strip start
SR_EXT          = fullfile('Processed', 'SR_TIFs');
EMR_EXT         = 'Repaired';
FAIL_CROP       = 1; % Crop 1 always indicates failure
NCC_THR_INC     = 0.01; % Amount by which to incease ncc_thr after a crop error

%% Make output path
paths.out = fullfile(paths.pro, 'FULL');
if exist(paths.out, 'dir') == 0
    mkdir(paths.out);
end

%% Start the clock
if vid_set.profiling
    vid_set.t_proc_start = clock;
end

%% Secondary modalities
vid_set = makeSecondaries(vid_set, paths.raw);
% send(q, vid_set);
if vid_set.profiling
    vid_set.t_full_mods = clock;
end

%% Get Calibration File
dsin = dsins(vid_set.fov == [dsins.fov]);

%% Start Registration and Averaging Loop
for ii=1:numel(opts.mod_order)
    %% Quit early if a previous modality produced a successful image
    if ii>1 && vid_set.hasAnySuccess
        break;
    end
    
    %% Get filenames
    % Primary
    mods = opts.mod_order;
    wls  = opts.lambda_order;
    prime_fname = getVidFilenameFromChannel(vid_set, {mods{ii}, wls(ii)});
    prime_fname = prime_fname{1};
    % Secondaries
    mods(ii) = [];
    wls(ii) = [];
    sec_fnames = getVidFilenameFromChannel(vid_set, [mods', num2cell(wls)']);
    sec_fname_str = strjoin(sec_fnames, ', ');
    
    %% Read
    try
        if check_gpu_space()
            % Possibly sufficient space
            vid = gpuArray(fn_read_AVI(fullfile(paths.raw, prime_fname)));
        else
            % Just use CPU
            vid = fn_read_AVI(fullfile(paths.raw, prime_fname));
        end
        vid = single(vid);
    catch me
        % If not enough GPU memory, read as usual
        if strcmp(me.identifier, 'parallel:gpu:array:OOM')
            vid = single(fn_read_AVI(fullfile(paths.raw, prime_fname)));
        end
    end
    orig_dims = size(vid);
    if vid_set.profiling
        vid_set.t_proc_read = clock;
    end
    
    %% Desinusoid
	try
		vid = desinusoidVideo(vid, dsin.mat);
	catch me
		if strcmp(me.identifier, 'parallel:gpu:array:OOM')
            vid = desinusoidVideo(gather(vid), dsin.mat);
		end
	end
    if vid_set.profiling
        vid_set.t_proc_dsind = clock;
    end

    %% Get new dimensions and success criteria
    dims = size(vid);
    FAIL_HT = round(SUCCESS_CRIT*dims(1));
    if isinf(opts.n_frames)
        opts.n_frames = dims(3);
    end
    
    %% ARFS
	frames = arfs(vid, 'pcc_thr', opts.pcc_thrs(ii), 'mfpc', opts.n_frames);
	vid_set.vids(ii).frames = frames;
	if ~isfield(frames, 'TRACK_MOTION_FAILED')
		% Pick the best frame from each cluster
		fids = get_best_n_frames_per_cluster(frames, 1);
	else
		% If motion tracking failed, just pick the one frame with the best PCC
		fids = get_best_n_frames_overall(frames, 1);
	end
% 	try
% 		frames = arfs(vid, 'pcc_thr', opts.pcc_thrs(ii), 'mfpc', 10);
% 	catch me
% 		if strcmp(me.identifier, 'parallel:gpu:array:OOM')
%             frames = arfs(gather(vid), 'pcc_thr', opts.pcc_thrs(ii), 'mfpc', 10);
% 		end
% 	end
    
%     n_frames = get_n_not_rejected(frames, ...
%         {'rejectSmallGroups'; 'rejectSmallClusters'; 'firstFrame'});
%     n_frames = get_n_not_rejected(frames, {'firstFrame'});
%     if n_frames < opts.n_frames
%         n_frames = opts.n_frames;
%     end
%     if n_frames > 50
%         n_frames = 50;
%     end
    % Include frames rejected by motion tracking (not the most robust)
	
    if vid_set.profiling
        vid_set.t_proc_arfs = clock;
    end
%     send(q, vid_set);
    
    %% Generate an acceptable image from each reference frame
    for jj=1:numel(fids)
        for kk=1:numel(fids(jj).cluster)
            %% Make temporary folder to organize these results
            append_text = sprintf('%i_L%iC%i', vid_set.vidnum, ...
                fids(jj).lid, fids(jj).cluster(kk).cid);
            paths.tmp = fullfile(paths.out, append_text, 'tmp');
            mkdir(paths.tmp);
            % Copy all videos to this folder
            all_fnames = [{prime_fname}; sec_fnames];
			for mm=1:numel(all_fnames)
                copyfile(fullfile(paths.raw, all_fnames{mm}), paths.tmp)
			end
			
            %% Binary video for analytics
            bin_fname = strrep(prime_fname, opts.mod_order{ii}, 'bin');
            new_sec_fname_str = [sec_fname_str, ', ',bin_fname];
            fn_write_AVI(fullfile(paths.tmp, bin_fname), ...
                ones(orig_dims, 'uint8').*255);
            % Record path to strip-registered images
            paths.imgs = fullfile(paths.tmp, '..', SR_EXT);
            
            %% NEST
            frame_idx = fids(jj).cluster(kk).fids(1);
%             [~, ~, candidate_ncc_thr_lut] = nest(gather(vid(:,:,frame_idx)));
            % downsample candidate_ncc_thr_lut to values that may actually be used
            % Don't use the suggested lps or thr, that's a shortcut
%             lps_array = doublePreviousElement(6, round(dims(1)*SHORT_CIRCUIT));
%             [~,I] = max(lps_array == candidate_ncc_thr_lut(1,:), [], 2);
%             candidate_ncc_thr_lut = single(candidate_ncc_thr_lut(:,I));
%             lps = candidate_ncc_thr_lut(1,1);
%             thr = candidate_ncc_thr_lut(2,1);
%             lps = lps_array(1);
            % Add to cluster
            % Starting conditions
            fids(jj).cluster(kk).lps        = LPS_0;
            fids(jj).cluster(kk).ncc_thr    = NCC_THR_0;
%             fids(jj).cluster(kk).lps_thr_lut = candidate_ncc_thr_lut;
            
			%% Get number of frames to register and average
			if ~isfield(frames, 'TRACK_MOTION_FAILED')
				n_frames = get_n_frames(frames, fids(jj).cluster(kk).fids(1));
				if n_frames < opts.n_frames
					n_frames = opts.n_frames;
				elseif n_frames > 50
					n_frames = 50;
				end
			else
				n_frames = opts.n_frames;
			end
			
            %% Demotion
            success = false;
            dmi = 0;
            while ~success
                % Update parameters
                lps     = fids(jj).cluster(kk).lps;
                ncc_thr = fids(jj).cluster(kk).ncc_thr;
                
                % Create .dmb
                [~, dmb_fname, status, stdout] = deploy_createDmb(...
                    paths, ...
                    fullfile(paths.tmp, prime_fname), ...
                    'cal_full_fname', fullfile(paths.cal, dsin.filename), ...
                    'lps', lps, 'lbss', LBSS, 'ncc_thr', ncc_thr, ...
                    'secondVidFnames', new_sec_fname_str, ...
                    'ref_frame', frame_idx, ...
                    'srMaxFrames', n_frames, ...
                    'ffrMaxFrames', 3, ...
                    'ffrMinFrames', 3, ...
                    'srMinFrames',  3, ...
                    'ffrSaveSeq', false, ...
                    'srSaveSeq', true, ...
                    'appendText', append_text);
				% todo: don't bother with secondaries until after success is achieved
                if status
                    error(stdout);
                end
                
                %% Call DeMotion Motion Estimation
                [status, stdout] = deploy_callDemotion(...
                    paths, ...
                    paths.tmp, dmb_fname, false);
                if status
                    error(stdout);
                end
                dmp_fname = strrep(dmb_fname, '.dmb', '.dmp');
                
                %% Measure NCC distribution and calculate threshold
                ncc_thr = getNewStripThreshold(...
                    fullfile(paths.tmp, dmp_fname), false, ncc_thr);
                fids(jj).cluster(kk).ncc_thr = ncc_thr;
                % Keep adjusting ncc_thr until there are no crop errors
                cropErr = true;
                while cropErr
                    % todo: this seems stupid. Should probably make a
                    % separate function for analyzing crop errors and the
                    % pixel cdf
                    dmi = dmi+1;
                    fprintf('Current iteration: %i\n', dmi);
                    fprintf('DeMotion parameters for %s:\n', prime_fname);
                	fprintf('LPS: %i, NCC threshold: %1.2f\n', lps, ncc_thr);
                    % Apply the threshold and compute the registered
                    % average
                    [status, stdout] = deploy_reprocess(...
                        fullfile(paths.tmp, dmp_fname), ncc_thr, paths);
                    if status ~= 1
                        % Error handling will be managed below
                        break;
                    end
                    [~,~,~,~,~,~,~,cropErr] = ...
                        getOutputSizeAndN(paths.imgs, dmb_fname, opts.mod_order{ii});
                    
                    if cropErr
                        ncc_thr = ncc_thr + NCC_THR_INC;
                        % Eventually it will either get rid of the crop
                        % error or fail completely, at which point raising
                        % the strip size is the right move
                    end
                end
                
                %% DeMotion feedback
                % Get output parameters
                if status == 1
                    [ht, ~, nFrames, nCrop, ~, tif_fname, ~] = ...
                        getOutputSizeAndN(paths.imgs, dmb_fname, ...
                        opts.mod_order{ii}, opts.n_frames);
                    tif_fnames = strrep(tif_fname, opts.mod_order{ii}, mods);
                    % todo: manage success criteria better
                else
                    warning(stdout);
                    ht = 0; nCrop = 0; nFrames = 0;
                end
                
                % Check against criteria
                if ht >= FAIL_HT && nCrop > FAIL_CROP && ...
                        nFrames >= opts.n_frames %&& contiguous
                    if vid_set.profiling
                        vid_set.t_proc_ra = clock;
                    end
                    % todo: reprocess with secondary sequences at this
                    % point
                    
                    % Success!
                    success = true;
                    fids(jj).cluster(kk).success = true;
                    vid_set.hasAnySuccess = true;
                    fids(jj).cluster(kk).dmb_fname = dmb_fname;
                    fids(jj).cluster(kk).dmp_fname = dmp_fname;
                    out_fnames = [{tif_fname}; tif_fnames'];
                    
                    %% EMR
                    deploy_emr_direct(fullfile(paths.tmp, dmp_fname), ...
                        paths.imgs, opts.mod_order{ii});
                    % todo: catch errors
%                     [emr_fail, emr_msg] = deployEMR(...
%                         'C:\Python27\python.exe', ...
%                         paths.imgs, paths.tmp, dmb_fname);
%                     if emr_fail
%                         error(emr_msg);
%                     end
                    
                    out_fnames = strrep(out_fnames, '.tif', '_repaired.tif');
                    paths.emr = fullfile(paths.imgs, EMR_EXT);
                    fids(jj).cluster(kk).out_fnames = out_fnames;
                    
                    %% Copy all successful files to full root
                    for mm=1:numel(out_fnames)
                        copyfile(fullfile(paths.emr, out_fnames{mm}), ...
                            paths.out);
                    end
                    for mm={dmb_fname, dmp_fname}
                        copyfile(fullfile(paths.tmp, mm{1}), ...
                            paths.out);
                    end
                    
                else % Failure
                    % 2x strip size and try again
                    lps = SS_FB_FX(lps);
                    thr = 0.1;
                    % Unless this strip size is too big
                    if lps > round(dims(1)*SHORT_CIRCUIT)
                        % Admit defeat
                        fids(jj).cluster(kk).success = false;
                        break;
                    else
                        % Update lps and ncc thr
                        fids(jj).cluster(kk).lps     = lps;
                        fids(jj).cluster(kk).ncc_thr = thr;
                    end
                end
            end % End of DeMotion feedback loop
            %% Remove the temporary folder
%             rmdir(fullfile(paths.tmp, '..'), 's')
        end % End of this cluster (reference frame)
    end % End of this linked group of frames
    vid_set.vids(ii).fids = fids;
end % End of this modality

if vid_set.profiling
    vid_set.t_proc_end = clock;
end

end

% my vision for the pipeline architecture is something like this, where a
% vid_set object is updated by each element of a module array, where these
% are function handles. All options would have to be passed to each one,
% for module = 1:numel(AOpipeline.modules)
%   vid_set = feval(@(x) module(vid_set))
% end
