function new_thr = getNewStripThreshold(dmp_ffname, display_on, old_thr)
%getNewStripThreshold Measures the distribution of NCC maxima after strip
%registration and sets a threshold to remove poorly correlated strips

% Test dmb
% dmp_ffname = 'C:\Users\DevLab_811\workspace\pipe_test\BL_12063\AO_2_3_SLO\2019_07_11_OS\Processed\FULL\1_L1C1\tmp\BL_12063_775nm_OS_confocal_0001_1_L1C1_ref_117_lps_6_lbss_6.dmp';

%% Constants
THR_DEF = 1; % standard deviations away from the mean
% AES - 2020.06.17 - set to 0 when dealing with ACHM
% THR_DEF = -1; % standard deviations away from the mean


%% Get current python environment
pe = pyenv;
if strcmp(pe.Version, '') || str2double(pe.Version) >= 3
    try
        pyenv('Version', '2.7')
    catch me
        error('Python 2.7 is required... I think')
    end
end

%% Load dmp
fid = py.open(dmp_ffname, 'r');
pick = py.pickle.load(fid);
fid.close();

%% Get distribution of all SR max NCCs
n_frames = uint16(pick{'n_frames'});
ref_frame = uint16(pick{'reference_frame'})+1; %+1 for 0-based indexing
% n_strips_used = uint16(py.len(pick{'strip_ncc'}{'ncc_max_values'}{1}));
ht = uint16(pick{'n_rows_desinusoided'});
all_strip_nccs = nan(n_frames, ht, 'single');
for ii=1:n_frames
    if ii==ref_frame
        continue;
    end
    strip_nccs = single(pick{'strip_ncc'}{'ncc_max_values'}{ii});
    all_strip_nccs(ii, 1:numel(strip_nccs)) = strip_nccs;
end
all_strip_nccs(ref_frame, :) = [];
all_strip_nccs = all_strip_nccs(~isnan(all_strip_nccs));

% norm_all_strip_nccs = (all_strip_nccs - mean(all_strip_nccs(:)))./std(all_strip_nccs(:));
new_thr = mean(all_strip_nccs(:)) + THR_DEF*std(all_strip_nccs(:));

if display_on
    figure;
    histogram(all_strip_nccs)
    xlabel('SR max(NCC)');
    ylabel('# Strips');
    hold on;
    yl = get(gca,'ylim');
    plot([old_thr,old_thr],yl,'-r');
    plot([new_thr,new_thr],yl,'-b');
    hold off;
    legend({'Counts', 'Old threshold', 'New threshold'},'location','northwest')
end
% %% Check that this is on the python search path
% if count(py.sys.path,'') == 0
%     insert(py.sys.path,int32(0),'');
% end

end

