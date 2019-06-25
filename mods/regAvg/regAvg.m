function [status, msg, tif_fnames] = regAvg(ini, root_path, raw_path, ...
    aviSet, dsins, ...
    mod_order, lambda_order, pcc_thrs, overwrite, refFrames)
%regAvg registers and averages 1 video set

%% Default outputs
status = false; % fail
msg = 'Low quality';
regAvg_out_fname = [aviSet.num, '_regAvg.mat'];

%% Load previous session if it exists
regAvg_done = exist(fullfile(raw_path, regAvg_out_fname), 'file') ~= 0;
if regAvg_done && ~overwrite
    load(fullfile(raw_path, regAvg_out_fname)); %#ok<*LOAD>
end

%% Determine if reference frames were input directly
ref_frames_direct = ~exist('refFrames', 'var') == 0;

%% Constants
% todo: make opt. input arguments
FAIL_HT     = 450;
FAIL_CROP   = 1;
FAIL_N      = 1;
MAX_FRAMES  = 50;
NCC_THR_INC = 0.05;
% Strip size increment function
% SS_FB_FX = @(x) 5e-3.*x.^2 + x + 2;
SS_FB_FX = @(x) 2.*x;
MAX_LPS = 200;
MFPC = 5; % min # frames per cluster
U_MODS = unique(mod_order);

%% Unpack ini
py2 = getIniPath(ini, 'Python 2.7');

%% Proceed in order of primary modalities/wavelengths
% Set status true on success and break loop
% Create structure to save record of parameters attempted
aviSet.reg(numel(mod_order)).mod = mod_order{end};
aviSet.reg(numel(mod_order)).wl = lambda_order(end);
for ii=1:numel(mod_order)
    if ~regAvg_done || overwrite
        aviSet.reg(ii).mod  = mod_order{ii};
        aviSet.reg(ii).wl   = lambda_order(ii);
        aviSet.reg(ii).mod_fail = false;
    else
        % Check if the modality has already failed
        if aviSet.reg(ii).mod_fail
            continue;
        end
    end
    
    %% Get current video
    fname_filt = ...
        strcmp(mod_order{ii}, aviSet.mods) & ...
        lambda_order(ii) == aviSet.wl;
    if numel(find(fname_filt)) == 1
        avi_fname = aviSet.fnames{...
            strcmp(mod_order{ii}, aviSet.mods) & ...
            lambda_order(ii) == aviSet.wl};
    else % No videos with this combo of mod and lambda
        continue;
    end
    
    %% Determine if ARFS and NEST data are already available
    arfs_mat_fname = strrep(avi_fname, '.avi', '_arfs.mat');
    arfs_done = exist(fullfile(raw_path, arfs_mat_fname), 'file') ~= 0;
    if arfs_done && ~overwrite && exist('refFrames', 'var') == 0
        load(fullfile(raw_path, arfs_mat_fname));
    end
    nest_mat_fname = strrep(avi_fname, '.avi', '_nest.mat');
    nest_done = exist(fullfile(raw_path, nest_mat_fname), 'file') ~= 0;
    if nest_done && ~overwrite
        load(fullfile(raw_path, nest_mat_fname));
    end
    % Still have to do all this even if arfs and nest are done
    % Should break this up into reading and desinusoiding steps becase
    % reading is time-intensive
    [vid, dsin] = readAndDsin(fullfile(raw_path, avi_fname), ...
        dsins, aviSet.fov, lambda_order(ii));
    raw_vid_size = [size(dsin.lut.dsin_mat), size(vid, 3)];
    % Secondary vid names
    second_fnames = strjoin(...
        aviSet.fnames(~contains(aviSet.fnames, avi_fname)), ...
        ', ');

    %% ARFS
    % Get pcc_thr for this mod
    if ~arfs_done || overwrite && exist('refFrames', 'var') == 0
        pcc_thr = pcc_thrs(strcmp(mod_order{ii}, U_MODS));
        working_dir = pwd;
        frames = arfs(vid, 'pcc_thr', pcc_thr, 'mfpc', MFPC);
        % todo: fix stupid bug in ARFS that changes path during clustering
        if ~strcmp(pwd, working_dir)
            cd(working_dir);
        end
        refFrames   = getRefFrames(frames);
%         n_frames    = get_n_frames(frames, refFrames);
%         n_frames = MAX_FRAMES.*ones(size(refFrames));
%         remove = n_frames < MFPC;
%         refFrames(remove)   = [];
%         n_frames(remove)    = [];
%         n_frames(n_frames > MAX_FRAMES) = MAX_FRAMES;
        % Save output
        save(fullfile(raw_path, arfs_mat_fname), ...
            'frames', 'refFrames', 'pcc_thr');
    end
    
    %% NEST
    if ~nest_done || overwrite || ref_frames_direct
        lps_list = zeros(size(refFrames));
        thr_list = zeros(size(refFrames));
        thr_next = cell(size(refFrames));
        for jj=1:numel(refFrames)
            [lps_list(jj), thr_list(jj), thr_next{jj}] = ...
                nest(vid(:, :, refFrames(jj)));
        end
        if ~ref_frames_direct
            save(fullfile(raw_path, nest_mat_fname), ...
                'lps_list', 'thr_list', 'thr_next');
        end
    end
    
    %% Demotion
    proc_path       = fullfile(root_path, 'Processed', 'SR_TIFs');
    success_dmbs    = cell(size(refFrames));
    failed_rfs      = true(size(refFrames));
    % Add information to registration parameter record
    if ~regAvg_done || overwrite || isempty(aviSet.reg(ii).ref) || ...
            ref_frames_direct
        if ~ref_frames_direct
            si = 1;
            ei = numel(refFrames);
        else
            nRefs = numel(aviSet.reg(ii).ref);
            aviSet.reg(ii).ref = horzcat(aviSet.reg(ii).ref, ...
                repmat(aviSet.reg(ii).ref(1), 1, numel(refFrames)));
            si = nRefs+1;
            ei = nRefs+numel(refFrames);
        end
        II = si:ei;
            
        for jj=1:numel(refFrames)
            aviSet.reg(ii).ref(II(jj)).frame    = refFrames(jj);
            aviSet.reg(ii).ref(II(jj)).used     = false;
            aviSet.reg(ii).ref(II(jj)).success  = false;
            aviSet.reg(ii).ref(II(jj)).lps      = lps_list(jj);
            aviSet.reg(ii).ref(II(jj)).ncc_thr  = thr_list(jj);
            aviSet.reg(ii).ref(II(jj)).manual   = ref_frames_direct;
        end
    end
    % Start processing each reference frame
    for jj=1:numel(refFrames)
        if regAvg_done && ~overwrite && ~ref_frames_direct
            if aviSet.reg(ii).ref(jj).used && ...
                    ~aviSet.reg(ii).ref(jj).success
                continue;
            end
        end
        
        % Begin registering and averaging until criteria are met
        aviSet.reg(ii).ref(II(jj)).used = true;
        reg_success = false;
        while ~reg_success
            %% Create .dmb
            [dmb_path, dmb_fname, dmb_fail, stdout] = deploy_createDmb(...
                py2, ...
                dsin.lut.path, dsin.lut.fname, ...
                raw_path, avi_fname, raw_vid_size, ...
                'ref_frame', refFrames(jj), 'lps', lps_list(jj), ...
                'ncc_thr', thr_list(jj), ...
                'ffrMaxFrames', MAX_FRAMES, 'srMaxFrames', MAX_FRAMES, ...
                'ffrMinFrames', 3, 'srMinFrames', 3, ...
                'ffrSaveSeq', false, 'srSaveSeq', false, ...
                'secondVidFnames', second_fnames);
            if dmb_fail
                disp(stdout);
                status = false;
                msg = stdout;
                return;
            end
            
            %% Send to demotion
            fprintf('Sending %s to DeMotion.\n', dmb_fname);
            [demotion_fail, stdout] = deploy_callDemotion(...
                py2, dmb_path, dmb_fname);
            if demotion_fail
                disp(stdout);
                status = false;
                msg = stdout;
                return;
            end

            %% Demotion feedback
            % todo: functionalize
            % Check for success
            [ht, ~, nFrames, nCrop, ~, tif_fname] = ...
                getOutputSizeAndN(proc_path, dmb_fname);
            tif_fnames = strrep(tif_fname, mod_order{ii}, aviSet.mods);
            
            if ht >= FAIL_HT && nCrop > FAIL_CROP && nFrames > FAIL_N
                % Success
                success_dmbs{jj} = dmb_fname;
                reg_success = true;
                failed_rfs(jj) = false;
                aviSet.reg(ii).ref(II(jj)).success = true;
            else % Failure
                %% Sequester failed files
                sequesterFails(raw_path, dmb_fname);
                sequesterFails(raw_path, ...
                    strrep(dmb_fname, '.dmb', '.dmp'));
                for kk=1:numel(tif_fnames)
                    sequesterFails(proc_path, tif_fnames{kk})
                end
                
                %% Adjust parameters
                if nFrames == 1
                    % NCC threshold estimate is probably too high
                    thr_next{jj}(2,:) = thr_next{jj}(2,:) - NCC_THR_INC;
                else
                    % Try new lines per strip
                    next_lps = round(SS_FB_FX(lps_list(jj)));

                    % If we over shoot the max, still try it
                    if lps_list(jj) < MAX_LPS && next_lps > MAX_LPS
                        next_lps = MAX_LPS;

                    % But if we tried max and failed, this ref frame is a total
                    % failure
                    elseif lps_list(jj) == MAX_LPS
                        failed_rfs(jj) = true;
                        break;
                    end
                    lps_list(jj) = next_lps;
                    aviSet.reg(ii).ref(II(jj)).lps = ...
                        [aviSet.reg(ii).ref(II(jj)).lps; next_lps];
                end
                % Get new threshold to match
                try
                    thr_list(jj) = thr_next{jj}(2, ...
                        thr_next{jj}(1, :) == lps_list(jj));
                    aviSet.reg(ii).ref(II(jj)).ncc_thr = ...
                        [aviSet.reg(ii).ref(II(jj)).ncc_thr; thr_list(jj)];
                catch
                    % Sometimes there won't be a threshold for the max
                    % strip size, just keep the threshold from the last
                    % iteration
                end
                % todo: compile list of failed outputs and delete them
            end
        end
        if reg_success %&& overwrite % uncomment once you figure out a good way to sort reference frames
            break; % Use the first good image
        end
    end
    success_dmbs(failed_rfs) = []; % Remove empty cells
    
    %% EMR
    % Will automatically skip if all failed (numel(success_dmbs)) == 0
    for jj=1:numel(success_dmbs) 
        [emr_fail, emr_msg] = ...
            deployEMR(py2, proc_path, dmb_path, success_dmbs{jj});
        % todo: this will break if more than one success dmb is allowed
        tif_fnames = strrep(tif_fnames, '.tif', '_repaired.tif');
        if emr_fail
            status = fail;
            msg = emr_msg;
            return;
        end
    end
    
    % Check if all reference frames have failed for this modality
    if ~all(failed_rfs)
        status = true;
        break;
    else
        aviSet.reg(ii).mod_fail = true;
        if ref_frames_direct
            msg = 'These frames failed to register';
            break;
        end
    end
end

%% Write output
% todo: add more information than just success/failure
save(fullfile(raw_path, regAvg_out_fname), 'aviSet', 'status', 'msg');

end

