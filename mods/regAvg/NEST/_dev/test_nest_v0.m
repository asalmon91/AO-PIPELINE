%% Test NEST

%% Import
restoredefaultpath;
addpath(genpath('E:\Code\AO\gl\ARFS'));
addpath('E:\Code\AO\AO-PIPE\lib\AVI');
addpath('E:\Code\AO\ARFS\fx'); % ARFS:Demotion functions
addpath('E:\Code\AO\AO-PIPE\mods\callDemotion');
addpath('E:\Code\AO\AO-PIPE\mods\getPrimary');
addpath('.\lib');

%% Allow resuming a canceled session
re = questdlg('Load previous session?', 'Load?', ...
    'Yes', 'New session', 'Yes');
if isempty(re)
    return;
elseif strcmp(re, 'Yes')
    new_session = false;
    [fname_results, path_results] = uigetfile('*-nest.mat', ...
        'Select previous session data', '.\results', ...
        'multiselect', 'off');
    fprintf('Loading %s...', fname_results);
    load(fullfile(path_results, fname_results));
else
    clear all; %#ok<CLALL>
    new_session = true;
end

%% Analysis Constants
CONDS = {'1-ctrl', '2-achm_w_nyst', '3-achm_wo_nyst'};
N_SUBS = 10; % Set to 100 if you want all
MODS = {'confocal', 'split_det', 'avg'};
% pcc thresholds match indexing of MODS
PCC_THR = [0.010291307, 0.018341416, 0.025451048]; % todo: read from arfs results
LAMBDA = '790nm';
% RET_LOC = {'1T'};
% STRIP_SZ = 40;
% PCC_THR = 0.0103;
TRACK_MOTION = true; % Conduct 2nd pass of motion tracking
MFPC = 5; % Minimum frame per cluster threshold
% OVERLAP_THR = 50; % (percent) Frames must overlap by this much
HT_REQ = 400; % Images must be this tall to be considered successful
N_REQ = 2; % Must register at least this many frames to be successful

%% Set up output
if new_session
    ts = datestr(now,'yyyymmddHHMMss');
    fname_results = [ts, '-nest.mat'];
    path_results = fullfile(pwd, 'results');
    if exist(path_results, 'dir') == 0
        mkdir(path_results);
    end
end

%% Get datsets
if new_session
    root_path = uigetdir('.','Select dataset root directory');
    if isnumeric(root_path)
        return;
    end
    % Construct local paths
    lps = cell(numel(CONDS), 1);
    for ii=1:numel(CONDS)
        lps{ii} = fullfile(root_path, CONDS{ii});
    end
else
    lps = {cond.localpath}';
end


%% Preallocate condition structure
cond(numel(CONDS)).localpath = lps{end};
for ii=1:numel(CONDS)
    % Add local path
    cond(ii).localpath = lps{ii};
    cond(ii).condition = CONDS{ii};
    % Get subjects at local path
    subs = getAbsDirs(cond(ii).localpath);
    % Determine number to include
    n_subs_to_include = N_SUBS;
    if N_SUBS > numel(subs)
        warning('Only %i subjects found in %s', numel(subs), lps{ii});
        n_subs_to_include = numel(subs);
    end
    cond(ii).sub(n_subs_to_include).id = subs{end};

    %% Process subjects
    for jj=1:n_subs_to_include
        % Add local path
        cond(ii).sub(jj).id = subs{jj};
        cond(ii).sub(jj).lp = fullfile(lps{ii}, subs{jj});
        lp = cond(ii).sub(jj).lp;
        cond(ii).sub(jj).rp = readPathTxt(lp);
        rp = cond(ii).sub(jj).rp;
        if exist(rp, 'dir') == 0
            msg = sprintf('Subject folder not found: %s', rp);
            msgbox(msg, 'Error','error');
            continue;
        end
        
        %% Create output folders on local drive for efficient processing
        out_raw = fullfile(path_results, ...
            CONDS{ii}, cond(ii).sub(jj).id, 'Raw');
        out_proc = strrep(out_raw, 'Raw', 'Processed');
        out_cal = strrep(out_raw, 'Raw', 'Calibration');
        if exist(out_raw, 'dir') == 0
            mkdir(out_raw);
        end
        if exist(out_proc, 'dir') == 0
            mkdir(out_proc);
        end
        if exist(out_cal, 'dir') == 0
            mkdir(out_cal);
        end
        % Add paths to structure
        cond(ii).sub(jj).out_raw = out_raw;
        cond(ii).sub(jj).out_cal = out_cal;
        cond(ii).sub(jj).out_proc = out_proc;
        
        % Find and read position file
        posfile = findPosFile(lp);
        cond(ii).sub(jj).vidInputXlsx_fname = posfile;
        [head, body] = readPosFile(lp, posfile);
        numcol = strcmpi(head, 'num');
        loccol = strcmpi(head, 'loc');
        fovcol = strcmpi(head, 'fov');
        cond(ii).sub(jj).vidInputHead = head;
        cond(ii).sub(jj).vidInputBody = body;
        nums = cell2mat(body(:, numcol));
        fovs = cell2mat(body(:, fovcol));
        locs = body(:, loccol);
        
        % Find path to videos and calibration files
        raw_path = guessPath(rp, 'Raw');
        cal_path = guessPath(rp, 'Calibration');
        cond(ii).sub(jj).raw_path = raw_path;
        cond(ii).sub(jj).cal_path = cal_path;
        
        % Use ARFS:Demotion's desinusoid file finder
        tmp = struct('path', cal_path);
        des_lut = getDesinusoids(tmp, []);
        if isempty(des_lut)
            warning('Couldn''t find desinusoids in %s', cal_path)
            continue;
        end
        % Filter by wavelength, but this isn't always included
        des_lut_tmp = des_lut(contains(des_lut(:,2),LAMBDA), :);
        if ~isempty(des_lut_tmp)
            des_lut = des_lut_tmp;
        end
        
        % Find AVIs, sort by mod and num later
        avis = findVids(raw_path, LAMBDA, MODS, nums);
        
        %% Process videos
        cond(ii).sub(jj).loc(numel(locs)).loc = locs{end};
        for kk=1:numel(locs)
            cond(ii).sub(jj).loc(kk).loc = locs{kk};
            % Find videos at the desired retinal locations
            vidnum = nums(kk);
            cond(ii).sub(jj).loc(kk).num = vidnum;
            
            %% Get FOV and desinusoid matrix
            current_fov = fovs(kk);
            % Find matching desinusoid matrix
            des_matrix = des_lut{...
                cell2mat(des_lut(:,1))==current_fov, 3};
            if isempty(des_matrix)
                warning('Failed to find correct desinusoid matrix');
                continue;
            end
            des_fname = des_lut{...
                cell2mat(des_lut(:,1))==current_fov, 2};
            
            %% Process modalities
            cond(ii).sub(jj).loc(kk).mod(numel(MODS)).mod = MODS{end};
            
            %% Check if any mods already analyzed
            mods_done = false(size(MODS));
            for mm=1:numel(MODS)
                % Check if final field entered
                mods_done(mm)= isfield(...
                    cond(ii).sub(jj).loc(kk).mod(mm), 'tif_fname');
            end
            
            %% Determine primary just for information, still process both
            vid_collection = cell(size(MODS));
            if ~all(mods_done)
                for mm=1:numel(MODS)
                    cond(ii).sub(jj).loc(kk).mod(mm).mod = MODS{mm};
                    cond(ii).sub(jj).loc(kk).mod(mm).pcc_thr = PCC_THR(mm);
                    % Filter avi's by number and modality
                    vid_fnames = avis(...
                        contains(avis, MODS{mm}) & ...
                        contains(avis, pad(num2str(vidnum),4,'left','0')));
                    vidname = vid_fnames{1};
                    cond(ii).sub(jj).loc(kk).mod(mm).vid_fname = vidname;

                    %% Read and desinusoid, convert to 3D matrix
                    % Read video
                    vid_collection{mm} = cellTo3D(readAndDesinusoid(...
                        raw_path, vidname, des_matrix));
                    
                    %% Copy video to local drive
                    try % Occasional network errors
                        if exist(fullfile(out_raw, vidname), 'file') == 0
                            fprintf('Copying %s\n', vidname);
                            copyfile(...
                                fullfile(raw_path, vidname), ...
                                fullfile(out_raw, vidname));
                        end
                        matname = strrep(vidname, '.avi', '.mat');
                        if exist(fullfile(out_raw, matname), 'file') == 0 && ...
                                exist(fullfile(raw_path, matname), 'file') ~= 0
                            fprintf('Copying %s\n', matname);
                            copyfile(...
                                fullfile(raw_path, matname), ...
                                fullfile(out_raw, matname));
                        end
                        if exist(fullfile(out_cal, des_fname), 'file') == 0
                            fprintf('Copying %s\n', des_fname);
                            copyfile(...
                                fullfile(cal_path, des_fname), ...
                                fullfile(out_cal, des_fname));
                        end
                    catch MException
                        cond(ii).sub(jj).loc(kk).mod(mm).err = MException;
                        continue;
                    end
                end

                %% Determine video with highest SNR
                primary_index = getPrimary(vid_collection, MODS);
                cond(ii).sub(jj).loc(kk).primary = MODS{primary_index};
                fprintf('Primary: %s\n', MODS{primary_index});
            end
            
            for mm=1:numel(MODS)
                if mods_done(mm)
                    continue;
                end
                vidname = cond(ii).sub(jj).loc(kk).mod(mm).vid_fname;
                raw_vid_size = [flip(size(des_matrix)), ...
                        size(vid_collection{mm}, 3)];
                cond(ii).sub(jj).loc(kk).mod(mm).vid_size = raw_vid_size;
                
                % Check if arfs already ran
                if ~isfield(cond(ii).sub(jj).loc(kk).mod(mm), 'arfs') || ...
                    isempty(cond(ii).sub(jj).loc(kk).mod(mm).arfs)
                    
                    %% Run ARFS
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    frames = arfs(vid_collection{mm}, ...
                        'trackmotion', TRACK_MOTION, ...
                        'mfpc', MFPC, 'pcc_thr', PCC_THR(mm));
                    cond(ii).sub(jj).loc(kk).mod(mm).arfs = frames;
                    if isfield(frames(1), 'TRACK_MOTION_FAILED') && ...
                            frames(1).TRACK_MOTION_FAILED || ...
                            numel(find(~[frames.rej])) < MFPC
                        warning('Motion tracking failed in %s', ...
                            cond(ii).sub(jj).loc(kk).mod(mm).vid_fname);
                        continue;
                    end

                    %% Find largest cluster
                    % todo: functionalize
                    link_ids = sortLink_id_bySize(frames);
                    all_cluster_szs = cell(size(link_ids));
                    all_cluster_ids = cell(size(link_ids));
                    for nn=1:numel(link_ids)
                        [all_cluster_ids{nn}, all_cluster_szs{nn}] = ...
                            sortClusterBySize(frames, link_ids(nn));
                    end
                    % Find location of largest cluster
                    [~, LI] = max(...
                        cellfun(@max, all_cluster_szs));
                    largest_link_id = link_ids(LI(1));
                    [~, CI] = max(all_cluster_szs{LI(1)});
                    largest_cluster_id = all_cluster_ids{LI(1)}(CI(1));
                    % Find frames in this cluster
                    frame_ids = [frames(...
                        [frames.link_id] == largest_link_id & ...
                        [frames.cluster] == largest_cluster_id...
                        ).id];
                    % Warn about motion tracking failure
                    if numel(frame_ids) < MFPC
                        msg = sprintf('No cluster larger than %i in %s', ...
                            MFPC, ...
                            cond(ii).sub(jj).loc(kk).mod(mm).vid_fname);
                        msgbox(msg, 'Error','error');
                        continue;
                    end
                    
                    %% Choose reference frame
                    pccs = [frames(frame_ids).pcc];
                    [~, I] = max(pccs);
                    ref_frame = frame_ids(I(1));
                    nFramesReg = numel(frame_ids);
                    cond(ii).sub(jj).loc(kk).mod(mm).rf = ref_frame;
                    cond(ii).sub(jj).loc(kk).mod(mm).nFrames = ...
                        nFramesReg;
                    
                elseif isfield(cond(ii).sub(jj).loc(kk).mod(mm).arfs(1), ...
                        'TRACK_MOTION_FAILED') && ...
                        cond(ii).sub(jj).loc(kk).mod(mm).arfs(1).TRACK_MOTION_FAILED || ...
                        numel(find(~[cond(ii).sub(jj).loc(kk).mod(mm).arfs.rej])) < MFPC
                    continue;
                else % load from previous session
                    ref_frame = cond(ii).sub(jj).loc(kk).mod(mm).rf;
                    nFramesReg = cond(ii).sub(jj).loc(kk).mod(mm).nFrames;
                end
                
                %% Estimate LPS and NCC threshold
                % Check if already analyzed
                if isfield(cond(ii).sub(jj).loc(kk).mod(mm), 'lps') && ...
                    ~isempty(cond(ii).sub(jj).loc(kk).mod(mm).lps)
                    continue;
                end
                [lines_per_strip, ncc_thr] = nest(...
                    vid_collection{mm}(:,:,ref_frame));
                cond(ii).sub(jj).loc(kk).mod(mm).lps = lines_per_strip;
                cond(ii).sub(jj).loc(kk).mod(mm).ncc_thr = ncc_thr;

                %% Save results
                save(fullfile(path_results, fname_results), 'cond');
                
                %% Create batch file (.dmb) with processing parameters
                % Get secondary sequence file names
                other_mods = MODS;
                other_mods(contains(other_mods, MODS{mm})) = [];
                other_mod_string = cell(size(other_mods));
                for nn=1:numel(other_mods)
                    other_mod_string{nn} = ...
                        strrep(vidname, MODS{mm}, other_mods{nn});
                end
                other_mod_string = strjoin(other_mod_string, ', ');
                
                % Get absolute path to cal and raw
                [dmb_path, dmb_fname] = deploy_createDmb(...
                    out_cal, des_fname, out_raw, vidname, raw_vid_size, ...
                    'ref_frame', ref_frame, ...
                    'lps', lines_per_strip, 'lbss', 6, ...
                    'srMinFrames', 2, 'ffrMinFrames', 2, ...
                    'srMaxFrames', nFramesReg, ...
                    'ffrMaxFrames', nFramesReg, ...
                    'ncc_thr', ncc_thr, ...
                    'secondVidFnames', other_mod_string, ...
                    'srSaveSeq', true, 'ffrSaveSeq', true);

                %% Send batch file to demotion
                fprintf('Sending %s to DeMotion\n', dmb_fname);
                deploy_callDemotion(dmb_path, dmb_fname);

                %% Assess processed image
                [...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_ht, ...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_wd, ...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_n, ...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_crop, ...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_path, ...
                    cond(ii).sub(jj).loc(kk).mod(mm).tif_fname] = ...
                    getOutputSizeAndN(out_proc, dmb_fname);
            end
        end
    end
end

%% Analyze results
% Find out how many failed overall
% Find out, of the ones that failed, was it selected as the primary?
n_failed            = 0;
n_primary_failed    = 0;
n_secondary_success = 0;
n_total             = 0;
for ii=1:numel(cond)
    for jj=1:numel(cond(ii).sub)
        for kk=1:numel(cond(ii).sub(jj).loc)
            for mm=1:numel(cond(ii).sub(jj).loc(kk).mod)
                n_total = n_total + 1;
                failed = false;
                try
                    isprimary = strcmp(...
                        cond(ii).sub(jj).loc(kk).primary, MODS{mm});
                catch
                    isprimary = false;
                    failed = true;
                end
                
                if ...
                        isfield(cond(ii).sub(jj).loc(kk).mod(mm), ...
                        'tif_fname') && ...
                        ~isempty(...
                        cond(ii).sub(jj).loc(kk).mod(mm).tif_fname)
                    ht = cond(ii).sub(jj).loc(kk).mod(mm).tif_ht;
                    n_frames = cond(ii).sub(jj).loc(kk).mod(mm).tif_n;
                    n_crop = cond(ii).sub(jj).loc(kk).mod(mm).tif_crop;
                    
                    if ht < HT_REQ || n_frames < N_REQ || n_crop < N_REQ
                        failed = true;
                    end
                else
                    failed = true;
                end
                if failed
                    n_failed = n_failed + 1;
                    if isprimary
                        fprintf('%s\n%s\n', ...
                            cond(ii).sub(jj).out_raw, ...
                            cond(ii).sub(jj).loc(kk).mod(mm).vid_fname);
                        n_primary_failed = n_primary_failed + 1;
                        
                        % Check if 2° succeeded in this case
                        secondary_succeeded = false(size(MODS));
                        for nn=1:numel(MODS)
                            if ~isfield(cond(ii).sub(jj).loc(kk).mod(nn), ...
                                    'tif_ht')
                                continue
                            end
                            
                            ht = cond(ii).sub(jj).loc(kk).mod(nn).tif_ht;
                            n_frames = cond(ii).sub(jj).loc(kk).mod(nn).tif_n;
                            n_crop = cond(ii).sub(jj).loc(kk).mod(nn).tif_crop;
                            if any(isempty([ht, n_frames, n_crop]))
                                continue;
                            end
                            if ht >= HT_REQ && n_frames >= N_REQ && n_crop >= N_REQ
                                secondary_succeeded(nn) = true;
                            end
                        end
                        if any(secondary_succeeded)
                            n_secondary_success = n_secondary_success + 1;
                        end
                    end
                end
            end
        end
    end
end
fprintf('%i/%i (%1.2f%s) failed overall\n', n_failed, n_total, ...
    n_failed/n_total*100, '%');
fprintf('%i/%i (%1.2f%s) primary sequences failed\n', n_primary_failed, ...
    n_total, n_primary_failed/n_total*100, '%');
fprintf('%i/%i (%1.2f%s) picked wrong primary\n', n_secondary_success, ...
    n_primary_failed, n_secondary_success/n_primary_failed*100, '%');


% 
% % Create a table with
% % cond | sub | loc | mod | pre_n | pre_ncc | post_n | post_ncc |
% head = {'Cond', 'Sub', 'Loc', 'Mod', 'Pre_N', 'Pre_NCC', 'Post_N', 'Post_NCC'};
% body = cell(0, numel(head));
% for ii=1:numel(cond)
%     for jj=1:numel(cond(ii).sub)
%         for kk=1:numel(cond(ii).sub(jj).loc)
%             for mm=1:numel(cond(ii).sub(jj).loc(kk).mod)
%                 for nn=1:numel(cond(ii).sub(jj).loc(kk).mod(mm).pre_n)
%                     body = [body; ...
%                         {CONDS{ii}, ...
%                         cond(ii).sub(jj).id, ...
%                         cond(ii).sub(jj).loc(kk).loc, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).mod, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).pre_n(nn), ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).pre_ncc(nn), ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).post_n(nn), ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).post_ncc(nn)}]; %#ok<AGROW>
%                 end
%             end
%         end
%     end
% end
% 
% full_table = [head; body];
% xlswrite(fullfile(path_results, 'nseries_results.xlsx'), full_table);
% 
% % By input method
% head = {'Cond', 'Sub', 'Loc', 'Mod', 'Reg', 'Pre', 'Post'};
% body = cell(0, numel(head));
% for ii=1:numel(cond)
%     for jj=1:numel(cond(ii).sub)
%         for kk=1:numel(cond(ii).sub(jj).loc)
%             for mm=1:numel(cond(ii).sub(jj).loc(kk).mod)
%                 for nn=1:numel(cond(ii).sub(jj).loc(kk).mod(mm).reg)
%                     body = [body; ...
%                         {CONDS{ii}, ...
%                         cond(ii).sub(jj).id, ...
%                         cond(ii).sub(jj).loc(kk).loc, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).mod, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).reg(nn).reg_type, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).reg(nn).pre, ...
%                         cond(ii).sub(jj).loc(kk).mod(mm).reg(nn).post}]; %#ok<AGROW>
%                 end
%             end
%         end
%     end
% end
% 
% full_table = [head; body];
% xlswrite(fullfile(path_results, 'regtype_results.xlsx'), full_table);
% % 
% 
% %% Stats
% % Determine if differences exist for post NCC between input methods and
% % between conditions
% [p,tbl,stats] = anovan(...
%     cell2mat(body(:,strcmpi(head, 'Post'))), ...
%     {body(:,strcmpi(head, 'Reg')), body(:,strcmpi(head,'Cond'))}, ...
%     'model','full','varnames',{'Input Method', 'Phenotype'});
% figure;
% results = multcompare(stats);
% 
% save(fullfile(path_results, 'stat_results.mat'), ...
%     'p', 'tbl', 'stats', 'results');
% 
% % Attempt at repeated measures ANOVA:
% % Conditions = body(:,1);
% % Subjects = body(:,2);
% % InputMethod = body(:,5);
% % PreNCC = cell2mat(body(:,6));
% % PostNCC = cell2mat(body(:,7));
% % t = table(Conditions, Subjects, InputMethod, PreNCC, PostNCC);
% % rm = fitrm(t, 'PreNCC-PostNCC~InputMethod', ...
% %     'WithinDesign', table([1;2], 'variablenames', {'Dewarp'}))
% % 
% % ranovatbl = ranova(rm)
% % multcompare(rm)
% 
% %% Analyze linear relationship of nseries
% ps = zeros(size(CONDS));
% for ii=1:numel(CONDS)
%     tmp_body = body(strcmpi(body(:,1), CONDS{ii}), :);
%     r_indx = find(...
%         cell2mat(tmp_body(:, 7)) >= 5 & ...
%         cell2mat(tmp_body(:, 7)) <= 10);
%     n = cell2mat(tmp_body(r_indx, 7));
%     post_pre = cell2mat(tmp_body(r_indx, 8)) ./ ...
%         cell2mat(tmp_body(r_indx, 6));
%     
%     mdl = fitlm(n, post_pre);
%     ps(ii) = mdl.Coefficients.pValue(2);
% end





