%% First import a table with manual montage information
% Name: man_mon, first col: full file nanme of montage, second col: scale
% in pixels per degree
% uigetfile()
% load()

%% Data root
src_root = 'C:\pipe-test';
data_root = '\\burns.rcc.mcw.edu\aoip\2-Purgatory\AO-PIPE-test\retro';

%% Constants
FOLDER_EXPR = '\d-*';
DSET_EXPR = 'auto-*';
AUTO_MON_FNAME = 'AOMontageSave.mat';
COND_KEY = {
    '1-ctrl',   'Control';
    '2-achm',   'ACHM';
    '3-alb',    'Albinism';
    '4-tlgs',   '13-LGS'};

%% Get data dirs in src
src_dir = dir(src_root);
% Filter by expected format
src_names = {src_dir.name}';
src_filt = ~cell2mat(cellfun(@isempty, ...
    (regexp(src_names, FOLDER_EXPR)), ...
    'UniformOutput', false));
src_dir = src_dir(src_filt);

%% Launch photoshop to analyze montages
addpath(genpath('C:\Program Files\Adobe\Adobe Photoshop CS6 (64 Bit)\Matlab-PS-CS6-integration\MATLAB_Win64\Required'))
pslaunch;

%% Copy these to trg
% t_proc_time_hr_all = cell(size(src_dir));
% n_missing_imgs = t_proc_time_hr_all;
n_mon_deg2_all  = cell(size(src_dir));
n_pieces_all    = n_mon_deg2_all;
dset_names      = n_mon_deg2_all;
for ii=4:numel(src_dir)
    dset_dir = dir(fullfile(src_root, src_dir(ii).name, DSET_EXPR));
    
%     t_proc_time_cond = nan(size(dset_dir));
%     n_vids_cond         = t_proc_time_cond;
%     n_missing_imgs_dset = t_proc_time_cond;
    n_mon_dset          = nan(size(dset_dir));
    n_pieces_dset       = n_mon_dset;
    for jj=1:numel(dset_dir)
%         % Make a duplicate copy of the folder in trg
%         out_dir = fullfile(trg_root, src_dir(ii).name, dset_dir(jj).name);
%         if ~exist(out_dir, 'dir')
%             mkdir(out_dir);
%         end
        
%         % Copy and rename the AO_PIPE_FULL file
%         db_ffname = fullfile(src_root, src_dir(ii).name, dset_dir(jj).name, DB_FNAME);
%         db_out_ffname = strrep(db_ffname, src_root, trg_root);
%         name_parts = strsplit(dset_dir(jj).name, '-');
%         db_out_ffname = strrep(db_out_ffname, DB_FNAME, [name_parts{2}, '-', DB_FNAME]);
%         if ~exist(db_out_ffname, 'file')
%             if exist(db_ffname, 'file')
%                 fprintf('Database file found!\n%s\n', db_ffname);
%                 
%                 [success, msg] = copyfile(db_ffname, db_out_ffname);
%                 if ~success
%                     warning(msg);
%                 end
%             else
%                 warning('Failed to find %s', db_ffname);
%             end
%         end
        
        %% Find the montage file
        % Get all montages here
        src_psd = subdir(fullfile(src_root, src_dir(ii).name, ...
            dset_dir(jj).name, '*.psd'));
        if isempty(src_psd)
            error('No .psd found in %s', ...
                fullfile(src_root, src_dir(ii).name, dset_dir(jj).name));
        end
        % Figure out which one comes from the list of manual montages
        psd_found = false;
        for kk=1:numel(src_psd)
            [~, psd_name, psd_ext] = fileparts(src_psd(kk).name);
            man_mon_filt = contains(...
                cellstr(man_mon.ffname), [psd_name, psd_ext]);
            if any(man_mon_filt)
                psd_found = true;
                psd_ffname = src_psd(kk).name;
                fprintf('Montage found!\n%s\n',psd_ffname);
                break;
            end
        end
        if ~psd_found
            error('No matching manual montage found at %s', ...
                fullfile(src_root, src_dir(ii).name, dset_dir(jj).name));
        end
        % Get the scale of this montage
        mon_scale = man_mon.scale(man_mon_filt);
        
        [~, n_pieces, max_mon_px] = ...
            getMontageAreaAndUnits(psd_ffname, true);
        n_mon_dset(jj) = max_mon_px * (1/mon_scale^2);
        n_pieces_dset(jj)  = n_pieces;
        
%         automon_ffname = fullfile(...
%             src_root, src_dir(ii).name, dset_dir(jj).name, AUTO_MON_FNAME);
%         if exist(automon_ffname, 'file')
%             % Get number of images input to the automontager
%             load(fullfile(mon_dir.folder, mon_dir.name), 'N')
%             n_mon_imgs_dset(jj) = N;
%         else
%             error('Automontager output file not found'
    end
    n_mon_deg2_all{ii}      = n_mon_dset;
    n_pieces_all{ii}        = n_pieces_dset;
    dset_names{ii}          = {dset_dir.name}';
end

a_mon_deg2 = cell2mat(n_mon_deg2_all);
n_pieces = cell2mat(n_pieces_all);
dsets    = vertcat(dset_names{:});

man_table = table(dsets, a_mon_deg2, n_pieces, 'VariableNames', ...
    {'Dataset', 'Area_deg2', 'N_Connected'});

out_path = uigetdir(src_root, 'Select output directory');
save(fullfile(out_path, 'man_mon_table.mat'), 'man_table');


