function [outputArg1,outputArg2] = readDMP(dmp_ffname)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% Test dmb
dmp_ffname = 'C:\Users\DevLab_811\workspace\pipe_test\BL_12063\AO_2_3_SLO\2019_07_11_OS\Processed\FULL\1_L1C1\tmp\BL_12063_775nm_OS_confocal_0001_1_L1C1_ref_117_lps_6_lbss_6.dmp';

%% Get current python environment
pe = pyenv;
if str2double(pe.Version) >= 3
    try
        pyenv('Version', 2.7)
    catch me
        error('Python 2.7 is required... I think')
    end
end

%% Fix some kind of endline issue
% Ask Rob
fid = py.open(dmp_ffname, 'rb');
text = fid.read().replace('\r\n','\n');
fid.read();
fid.close();

fid = py.open(dmp_ffname, 'wb');
fid.write(text);
fid.close();

%% Load dmp
fid = py.open(dmp_ffname, 'r');
pick = py.pickle.load(fid);
fid.close();

%% Extract transforms
% pick.keys()
% ff_translation_info_rowshift = int64(pick{'full_frame_ncc'}{'row_shifts'});
% ff_translation_info_colshift = int64(pick{'full_frame_ncc'}{'column_shifts'});
% strip_translation_info = pick{'sequence_interval_data_list'};
% exceed_thr_ids = uint16(pick{'acceptable_frames'})+1;
% max_nccs = double(pick{'full_frame_ncc'}{'ncc_max_values'});

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

norm_all_strip_nccs = (all_strip_nccs - mean(all_strip_nccs(:)))./std(all_strip_nccs(:));
thr = mean(all_strip_nccs(:)) - 1*std(all_strip_nccs(:))
orig_thr = pick{'frame_strip_ncc_threshold'};
pick{'frame_strip_ncc_threshold'} = cast(thr, class(orig_thr));

fid = py.open(dmp_ffname, 'w');
py.cPickle.dump(pick, fid)
fid.close()

%% Check that this is on the python search path
if count(py.sys.path,'') == 0
    insert(py.sys.path,int32(0),'');
end

%% Deploy reprocessing kajigger
py.reprocessWithDMP.reprocess_with_dmp(dmp_ffname)

%% Can we re-process without re-measuring??
% % Let's find out
% toolbag = py.CUDABatchProcessorToolBag.CUDABatchProcessorToolBag();
% dmb_ffname = strrep(strrep(dmp_ffname, '.dmp', '.dmb'), filesep, [filesep,filesep]);
% 
% 
% oneOutput = py.MotionEstimation.EstimateMotion(dmb_ffname, tool_bag)

% [success, error_msg, data] = py.CreateRegisteredImages.RegisterPrimaryImageSequence(pick, tool_bag, None)





end

