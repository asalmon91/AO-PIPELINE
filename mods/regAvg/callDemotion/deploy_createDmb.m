function [vid_path, dmb_fname, status, stdout] = deploy_createDmb(...
    py2_path, cal_path, cal_fname, vid_path, vid_fname, vid_size, varargin)
%deploy_createDmb calls a python script which creates a .dmb file for use
%with Demotion

%% DeMotion python scripts
calling_fx_ffname = mfilename('fullpath');
path_parts = strsplit(calling_fx_ffname, filesep);
py_path = calling_fx_ffname(1:end-numel(path_parts{end}));
dmb_py_fname = 'createDmb.py';

%% Create input parser object
ip = inputParser;
ip.FunctionName = mfilename;

%% Input validation fxs
isValidFile = @(x) ischar(x) && (exist(x, 'file') ~= 0);
isValidPath = @(x) ischar(x) && (exist(x, 'dir') ~= 0);
isValidRatio = @(x) isnumeric(x) && (x >= 0) && (x <= 1);
isBoolean = @(x) islogical(x) || x==0 || x==1;
is3D = @(x) isnumeric(x) && numel(x) == 3 && all(floor(x)==x) && all(x > 0);

%% Required parameters
req_params = {...
    'py2_path',     isValidFile;
    'cal_path',     isValidPath; 
    'cal_fname',    @ischar;
    'vid_path',     isValidPath;
    'vid_fname',    @ischar;
    'vid_size',     is3D};
% Add to parser
for ii=1:size(req_params, 1)
    addRequired(ip, req_params{ii,1}, req_params{ii, 2});
end

%% Check if files exist
if exist(fullfile(cal_path, cal_fname), 'file') == 0
    error('%s not found', cal_fname);
elseif exist(fullfile(vid_path, vid_fname), 'file') == 0
    error('%s not found', vid_fname);
end

%% Parse required before adding optional
parse(ip, py2_path, cal_path, cal_fname, vid_path, vid_fname, vid_size);

%% Get dimensions
frame_ht = ip.Results.vid_size(1);
frame_wd = ip.Results.vid_size(2);
n_frames = ip.Results.vid_size(3);

%% Data-dependent validation fx's
isValidNFrames = @(x) ...
    isnumeric(x) && all(x > 0) && all(x <= n_frames);
isValidStripSize = @(x) ...
    isnumeric(x) && isscalar(x) && (x > 0) && (x <= frame_ht);

%% Optional input parameters
opt_params = {...
    'ref_frame',        1,      isValidNFrames;
    'lps',              6,      isValidStripSize;
    'lbss',             6,      isValidStripSize;
    'ncc_thr',          0.85,   isValidRatio;
    'ffrMaxFrames',     Inf,    isValidNFrames;
    'ffrMinFrames',     1,      isValidNFrames;
    'srMaxFrames',      Inf,    isValidNFrames;
    'srMinFrames',      1,      isValidNFrames;
    'secondVidFnames',  '',     @ischar;
    'ffrSaveSeq',       true,   isBoolean
    'srSaveSeq',        true,   isBoolean};

% Add to parser
for ii=1:size(opt_params, 1)
    addParameter(ip, ...
        opt_params{ii, 1}, ...  % name
        opt_params{ii, 2}, ...  % default
        opt_params{ii, 3});     % validation fx
end

%% Parse optional inputs
parse(ip, py2_path, cal_path, cal_fname, vid_path, vid_fname, vid_size, varargin{:});

%% Unpack parser
input_fields = fieldnames(ip.Results);
for ii=1:numel(input_fields)
    eval(sprintf('%s = getfield(ip.Results, ''%s'');', ...
        input_fields{ii}, input_fields{ii}));
end

%% Check if max frames input
if any(contains(ip.UsingDefaults, 'ffrMaxFrames'))
    ffrMaxFrames = n_frames; %#ok<*NASGU>
end
if any(contains(ip.UsingDefaults, 'srMaxFrames'))
    srMaxFrames = n_frames;
end

%% Check that min frames is lower than max frames
if any(ffrMaxFrames < ffrMinFrames)
    error('Min frames (%i) must be less than max frames (%i)', ...
        ffrMinFrames, ffrMaxFrames);
elseif any(srMaxFrames < srMinFrames)
    error('Min frames (%i) must be less than max frames (%i)', ...
        srMinFrames, srMaxFrames);
end

%% Convert max frames to comma-delimited string
ffrMaxFrames = strjoin(...
    cellfun(@num2str, ...
    num2cell(ffrMaxFrames), ...
    'uniformoutput', false), ...
    ', ');
srMaxFrames = strjoin(...
    cellfun(@num2str, ...
    num2cell(srMaxFrames), ...
    'uniformoutput', false), ...
    ', ');

%% Construct string for command line
cmd_prompt = sprintf(horzcat(...
    ... % Formatting string for cmd line evaluation
    '"%s" "%s" ', ... % Python 2.7 path and Script full file name
    '--calPath "%s" --calFname "%s" ', ... % Desinusoid info
    '--vidPath "%s" --vidFname "%s" ', ... % Primary video
    '--refFrame %i ', ... % Reference frame
    '--nRowsRaw %i --nColsRaw %i --vidNFrames %i ', ... % Video info
    '--lps %i --lbss %i --nccThr %1.2f ', ... % Strip reg params
    '--ffrMaxFrames "%s" --srMaxFrames "%s" ', ... % N frames to register
    '--ffrMinFrames %i --srMinFrames %i ', ... % Min overlap for cropping
    '--secondVidFnames "%s" ', ... % Secondary sequence file names
    '--ffrSaveSeq %i --srSaveSeq %i'), ... % Output sequences
    ... % Input
    py2_path, ... % Python 2.7 path
    fullfile(py_path, dmb_py_fname), ... % Script full file name
    cal_path, cal_fname, ... % Desinusoid info
    vid_path, vid_fname, ... % Primary video
    ref_frame, ... % Reference frame
    frame_ht, frame_wd, n_frames, ... % Video info
    lps, lbss, ncc_thr, ... % Strip reg params
    ffrMaxFrames, srMaxFrames, ... % N frames to register
    ffrMinFrames, srMinFrames, ... % Min overlap for cropping
    secondVidFnames, ... % Secondary sequence file names
    ffrSaveSeq, srSaveSeq); % Output sequences

%% Send to OS
[status, stdout] = system(cmd_prompt);
if ~status
    dmb_fname = strtrim(stdout);
end

% Predict filename
% [~,vid_name,~] = fileparts(vid_fname);
% dmb_fname = sprintf('%s_ref_%i_lps_%i_lbss_%i.dmb', ...
%     vid_name, ref_frame, lps, lbss);

% todo: these parameters have yet to be implemented
% argList = [
%     # Major parameters
%     "dsinReq=", 
%     # Strip reg
%     "stripRegReq=", "srPrecision=", "srCropNccRows=", "srCropNccCols=", "srDisp=", "dct=",
%     # Full frame reg
%     "ffrDisp=", "ffrPrecision=", "ffrCropNccLines=",
%     # Output
%     "srSaveImg=", "srSaveSeq=", "ffrSaveImg=", "ffrSaveSeq=", "append="]

end

