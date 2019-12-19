function [calibration_queue, video_queue, montage_queue] = ...
    initQueues(num_workers)
%initQueues Create queues based on the number of cores available

% todo: make queue sizes optional input arguments
% todo: install safety features in case any queue size ends up being
% impossible (total > # avaialable; any < 1)

calibration_queue = cell(1);
montage_queue = cell(1);
video_queue = cell(num_workers - ...
    numel(calibration_queue) - numel(montage_queue) - 1);
if numel(video_queue) < 1
    video_queue = cell(1);
end

end

