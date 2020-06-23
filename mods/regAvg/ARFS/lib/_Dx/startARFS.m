function frames = startARFS(trackMotion, mfpc)
%startARFS is a simple function to call arfs and select a video
% Note: the video should be desinusoided prior to running

%% Imports
addpath('E:\Code\AO\gl\AVI');

%% Get video
[vid_fnames, vid_path] = uigetfile('*.avi', 'Select video', '.',...
    'multiselect','on');
if isnumeric(vid_fnames)
    return;
elseif ~iscell(vid_fnames)
    vid_fnames = {vid_fnames};
end
vid_fnames = vid_fnames';

%% Waitbar
global wb;
wb = waitbar(0, sprintf('Reading %s...', vid_fnames{1}));
wb.Children.Title.Interpreter = 'none';

%% Diagnostic test for PCC threshold
pcc1 = cell(numel(vid_fnames), 1);
for ii=1:numel(vid_fnames)
    %% Read video
    vid = fn_read_AVI(fullfile(vid_path, vid_fnames{ii}), wb);

    %% Start ARFS
    frames = arfs(vid, 'trackmotion', trackMotion, 'mfpc', mfpc, 'wb', wb);
    pcc1{ii} = frames.pcc1stPass;

    %% Write report
    FrameNumber = [frames.id]';
    Rejected = [frames.rej]';
    PhaseCorr = [frames.pcc]';
    Coords = cell2mat({frames.xy}');
    FrameGroup = [frames.link_id]';
    Cluster = [frames.cluster]';
    if any(Rejected)
        RejectionMethod = {frames.rej_method}';
    else
        RejectionMethod = cell(numel(frames),1);
    end
    T = table(FrameNumber,Rejected,PhaseCorr,Coords,...
        FrameGroup,Cluster,RejectionMethod);
    out_fname = strrep(vid_fnames, '.avi', '_arfs.xlsx');
    writetable(T,fullfile(vid_path, out_fname));
end
close(wb);
end

