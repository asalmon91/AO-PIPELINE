function fail_status = isArfsFail(frames, mfpc)
%isArfsFail Summary of this function goes here
%   Detailed explanation goes here
fail_status = isfield(frames(1), 'TRACK_MOTION_FAILED') && ...
    frames(1).TRACK_MOTION_FAILED || ...
    numel(find(~[frames.rej])) < mfpc;
end

