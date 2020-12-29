%% Get acquisition timestamps
src_root = '\\burns.rcc.mcw.edu\aoip\2-Purgatory\AO-PIPE-test\retro';

%% Constants
FOLDER_EXPR = '\d-*';
DSET_EXPR = 'auto-*';
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

%% Get timestamps for all raw videos
for ii=1:numel(src_dir)
    src_dir(ii).dsets = dir(...
        fullfile(src_root, src_dir(ii).name, DSET_EXPR));
    
    med_lag = zeros(size(src_dir(ii).dsets));
    sd_lag = mu_lag;
    for jj=1:numel(src_dir(ii).dsets)
        dset_root = fullfile(...
            src_root, src_dir(ii).name, src_dir(ii).dsets(jj).name);
        paths = initPaths(dset_root);
        vid_dir = dir(fullfile(paths.raw, '*_confocal_*.avi'));
        % Get difference between subsequent videos in seconds
        dn = diff(sort([vid_dir.datenum]))' .* (3600*24);
        warning off;
        if adtest(dn) % Remove outliers
            if ~strcmp(msg, ...
                'P is less than the smallest tabulated value, returning 0.0005.')
                warning(msg);
            end
            outlier_filt = ...
                dn < median(dn) - 3*std(dn) | dn > median(dn) + 3*std(dn);
            dn(outlier_filt) = [];
        end
        msg = lastwarn;

        med_lag(jj) = median(dn);
        sd_lag(jj) = std(dn);
    end
    src_dir(ii).med_lag = med_lag;
    src_dir(ii).sd_lag = sd_lag;
end

%% Construct a useful table
tbls = cell(size(src_dir));
for ii=1:numel(tbls)
    this_cond = COND_KEY{strcmp(COND_KEY(:, 1), src_dir(ii).name), 2};
    cond = cellstr(repmat(this_cond, size(dsets)));
    dsets = {src_dir(ii).dsets.name}';
    tbls{ii} = table(cond, dsets, src_dir(ii).med_lag, src_dir(ii).sd_lag, ...
        'VariableNames', {'Condition', 'Dataset', 'MedLag_s', 'SD_Lag_s'});
end
full_table = vertcat(tbls{:});

uisave('full_table')










