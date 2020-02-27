function vid_set = process_vidset(vid_set, dsins, paths, opts)
%process_vidset performs several processing steps: secondary modality
%creation, registration and averaging, and statistical eye motion 
% correction

%% Constants
SUCCESS_CRIT    = 2/3; % Min img height
SHORT_CIRCUIT   = 1/3; % Max strip size
SS_FB_FX        = @(x) 2.*x; % Feedback function for iterating strip size
LBSS            = 6; % lines between strip start
SR_EXT          = fullfile('Processed', 'SR_TIFs');
EMR_EXT         = 'Repaired';
FAIL_CROP       = 1;
NCC_THR_INC     = 0.1; % Amount by which to reduce ncc_thr


%% Make output path
paths.out = fullfile(paths.pro, 'FULL');
if exist(paths.out, 'dir') == 0
    mkdir(paths.out);
end

%% Secondary modalities
vid_set = makeSecondaries(vid_set, paths.raw);

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
    
    %% Desinusoid
    vid = desinusoidVideo(vid, dsin.mat);
    
    %% Get new dimensions and success criteria
    dims = size(vid);
    FAIL_HT = round(SUCCESS_CRIT*dims(1));
    if isinf(opts.n_frames)
        opts.n_frames = dims(3);
    end
    
    %% ARFS
    frames = arfs(vid, 'pcc_thr', opts.pcc_thrs(ii), 'mfpc', 10);
    fids = get_best_n_frames_per_cluster(frames, 1);
    
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
            paths.imgs = fullfile(paths.tmp, '..', SR_EXT);
            
            %% NEST
            frame_idx = fids(jj).cluster(kk).fids(1);
            [lps, thr, candidate_ncc_thr_lut] = nest(gather(vid(:,:,frame_idx)));
            % downsample candidate_ncc_thr_lut to values that may actually be used
            lps_array = doublePreviousElement(lps, round(dims(1)*SHORT_CIRCUIT));
            [~,I] = max(lps_array == candidate_ncc_thr_lut(1,:), [], 2);
            candidate_ncc_thr_lut = single(candidate_ncc_thr_lut(:,I));
            % Add to cluster
            fids(jj).cluster(kk).lps = lps;
            fids(jj).cluster(kk).ncc_thr = thr;
            fids(jj).cluster(kk).lps_thr_lut = candidate_ncc_thr_lut;
            
            %% Demotion
            success = false;
            while ~success
                % Update parameters
                lps     = fids(jj).cluster(kk).lps;
                ncc_thr = fids(jj).cluster(kk).ncc_thr;
                
                % Create .dmb
                [~, dmb_fname, status, stdout] = deploy_createDmb(...
                    'C:\Python27\python.exe', ...
                    fullfile(paths.tmp, prime_fname), ...
                    'cal_full_fname', fullfile(paths.cal, dsin.filename), ...
                    'lps', lps, 'lbss', LBSS, 'ncc_thr', ncc_thr, ...
                    'secondVidFnames', sec_fname_str, ...
                    'ref_frame', frame_idx, ...
                    'srMaxFrames', dims(3), ... % Try all frames
                    'ffrMaxFrames', dims(3), ...
                    'ffrMinFrames', 3, ...
                    'srMinFrames', 3, ...
                    'ffrSaveSeq', false, ...
                    'srSaveSeq', true, ... % todo: set to false if speed is a concern
                    'appendText', append_text);
                dmp_fname = strrep(dmb_fname, '.dmb', '.dmp');
                if status
                    error(stdout);
                end
                
                % Call DeMotion
                [status, stdout] = deploy_callDemotion(...
                    'C:\Python27\python.exe', ...
                    paths.tmp, dmb_fname);
                if status
                    error(stdout);
                end
                
                %% DeMotion feedback
                % Get output parameters
                [ht, ~, nFrames, nCrop, ~, tif_fname] = ...
                    getOutputSizeAndN(paths.imgs, dmb_fname);
                tif_fnames = strrep(tif_fname, opts.mod_order{ii}, mods);
                
                % Check against criteria
                if ht >= FAIL_HT && nCrop > FAIL_CROP && nFrames > opts.n_frames
                    % Success!
                    success = true;
                    fids(jj).cluster(kk).success = true;
                    vid_set.hasAnySuccess = true;
                    fids(jj).cluster(kk).dmb_fname = dmb_fname;
                    fids(jj).cluster(kk).dmp_fname = dmp_fname;
                    out_fnames = [{tif_fname}; tif_fnames'];
                    
                    %% EMR
                    [emr_fail, emr_msg] = deployEMR(...
                        'C:\Python27\python.exe', ...
                        paths.imgs, paths.tmp, dmb_fname);
                    if emr_fail
                        error(emr_msg);
                    end
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
                    if nFrames == 1 || nCrop == 1
                        % typically when this happens, it's because the
                        % ncc_thr is too high, lower and try again
                        fids(jj).cluster(kk).ncc_thr = ncc_thr - NCC_THR_INC;
                        
                    else
                        % Something's probably working, lps is probably
                        % too small
                        this_idx = find(candidate_ncc_thr_lut(1,:) == lps);
                        if this_idx == size(candidate_ncc_thr_lut,2)
                            % Admit defeat
                            fids(jj).cluster(kk).success = false;
                            break;
                        else
                            % Update lps and ncc thr
                            lps = candidate_ncc_thr_lut(1, this_idx+1);
                            thr = candidate_ncc_thr_lut(2, this_idx+1);
                            fids(jj).cluster(kk).lps     = lps;
                            fids(jj).cluster(kk).ncc_thr = thr;
                        end
                    end
                end
            end % End of DeMotion feedback loop
            %% Remove the temporary folder
            rmdir(fullfile(paths.tmp, '..'), 's')
        end % End of this cluster (reference frame)
    end % End of this linked group of frames
    vid_set.vids(ii).fids = fids;
end % End of this modality







end

% my vision for the pipeline architecture is something like this, where a
% vid_set object is updated by each element of a module array, where these
% are function handles. All options would have to be passed to each one,
% for module = 1:numel(AOpipeline.modules)
%   vid_set = feval(@(x) module(vid_set))
% end
