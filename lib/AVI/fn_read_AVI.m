function [ avi ] = fn_read_AVI( ffname, wb )
%fn_read_AVI Read an avi and output 3D matrix

%% Update waitbar
if nargin == 2
    [~,fname,~] = fileparts(ffname);
    waitbar(0, wb, sprintf('Reading %s...', fname));
end

%% Create video reader object
vr      = VideoReader(ffname);
nFrames = round(vr.FrameRate*vr.Duration);

%% Read video
if ~isempty(strfind(vr.VideoFormat, 'RGB24'))
    avi = zeros(vr.Height, vr.Width, nFrames, 3, 'uint8');
    for i=1:nFrames
        avi(:, :, i, :) = readFrame(vr);
        
        if mod(i,10) == 0 && nargin == 2 % Only update every other 10 frames
            waitbar(i/nFrames, wb); 
        end
    end
else
    avi = zeros(vr.Height, vr.Width, nFrames, 'uint8');
    for i=1:nFrames
        avi(:, :, i) = readFrame(vr);
        
        if mod(i,10) == 0 && nargin == 2 % Only update every other 10 frames
            waitbar(i/nFrames, wb); 
        end
    end
end





end

