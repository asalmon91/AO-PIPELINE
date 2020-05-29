function [status, stdout] = deploy_reprocess(dmp_ffname, ncc_thr)
%deploy_reprocess Calls the DubraLab modules: CreateRegisteredImages & 
% CreateRegisteredSequences to obtain strip-registered images and
% sequences after adjusting the ncc threshold

%% Load .dmp and update ncc_threshold
fid = py.open(dmp_ffname, 'r');
pick = py.pickle.load(fid);
fid.close();
old_thr = pick{'frame_strip_ncc_threshold'};
pick{'frame_strip_ncc_threshold'} = cast(ncc_thr, class(old_thr));
fid = py.open(dmp_ffname, 'w');
py.cPickle.dump(pick, fid);
fid.close();

%% Update the .dmb as well for record keeping
% Get .dmb file name
dmb_ffname = strrep(dmp_ffname, '.dmp', '.dmb');
fid = py.open(dmb_ffname, 'r');
pick = py.pickle.load(fid);
fid.close();
old_thr = pick{'frame_strip_ncc_threshold'};
pick{'frame_strip_ncc_threshold'} = cast(ncc_thr, class(old_thr));
fid = py.open(dmb_ffname, 'w');
py.cPickle.dump(pick, fid);
fid.close();

%% Get path to reprocessing script
% calling_fx_ffname = mfilename('fullpath');
% path_parts = strsplit(calling_fx_ffname, filesep);
% py_path = calling_fx_ffname(1:end-numel(path_parts{end}));
py_path = 
py_ffname = fullfile(py_path, 'reprocessWithDMP.py');

%% Process the .dmp
[status, stdout] = system(sprintf('"%s" "%s" --dmpFFname "%s"', ...
    'C:\Python27\python.exe', py_ffname, dmp_ffname));
if status ~=0
    error(stdout);
else
    % Get success status from stdout
    out_lines = strsplit(stdout, '\n');
    status = eval(lower(out_lines{2}));
end

end

