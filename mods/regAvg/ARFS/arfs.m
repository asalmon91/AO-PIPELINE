function frames = arfs(vid, varargin)
% arfs estimates the ... (todo) finish the intro
% vid must be a 3D matrix of size [height, width, #frames]
% outputs the frames structure with length==#frames. Each frame object has
% the properties: number, rank, group, cluster, coord, rej, and rej_method.

%% Todo
% Matlab version check
% Stats toolbox version check (required for clustering)

%% Imports
% Add ARFS library and subfolders
function_full_path = mfilename('fullpath');
path_parts = strsplit(function_full_path, filesep);
function_root = strjoin(path_parts(1:end-1), filesep);
addpath(genpath(function_root));

%% Parse inputs
parseinputs(varargin)
global TRACK_MOTION;
global MFPC;
% global wb;
global pcc_thr;
REJ_THR = 1; % Rejection threshold, a standard deviation multiplier
fprintf('PCC threshold=%1.3f, MFPC=%i, Tracking motion: %i\n', ...
    pcc_thr, MFPC, TRACK_MOTION);

%% Construct frame objects
frames = initFrames(size(vid,3));

%% Reject frames based on mean intensity, contrast, and sharpness
frames = rejectDuplicates(vid, frames);
frames = getInt(vid, frames, REJ_THR);
frames = getContrast(vid, frames, REJ_THR);
frames = getSharpness(vid, frames, REJ_THR);

%% Intra-frame motion detection
% arfs_data = getIFM(vid, arfs_data, wb);

%% Inter-frame motion detection
% Will only do 1st pass if TRACK_MOTION is false
[frames, ~] = getMT(vid, frames, pcc_thr, REJ_THR);
% frames.pcc1stPass = pcc1stPass;

%% STEP 5: CLUSTER ANALYSIS OF FIXATIONS
if TRACK_MOTION
    frames = getClusters(frames, size(vid));
else
    frames = updateCluster(frames, [frames.id], ones(numel(frames),1));
end

% waitbar(1,wb,'Done!');

end

function parseinputs(varargin)
%% Parse inputs
% defaults: arfs_main(vid, 'TrackMotion', true, 'MFPC', 10)
varargin = varargin{1};
global TRACK_MOTION; TRACK_MOTION = true;
% Minimum frames per cluster
global MFPC; MFPC = 10;
% Phase correlation coefficient threshold
global pcc_thr; pcc_thr = 0.01;
% global wb;

if ~isempty(varargin)
    %TRACK_MOTION
    tm_input = strcmpi(varargin, 'trackmotion');
    if any(tm_input)
        TRACK_MOTION = varargin{find(tm_input)+1};
    end
    
    % MFPC
    mfpc_input = strcmpi(varargin, 'mfpc');
    if any(mfpc_input)
        MFPC = varargin{find(mfpc_input)+1};
    end
    
    % PCC_THR
    pcc_thr_input = strcmpi(varargin, 'pcc_thr');
    if any(pcc_thr_input)
        pcc_thr = varargin{find(pcc_thr_input)+1};
    end
    
    % Waitbar
    wb_input = strcmpi(varargin, 'wb');
    if any(wb_input)
%         wb = varargin{find(wb_input)+1};
    else
%         wb = createWaitbar();
    end
else
%     wb = createWaitbar();
end
end



