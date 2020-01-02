function [cal_future, cq, vid_future, vq, montage_future, mq] = ...
    initQueues()
%initQueues Create queues based on the number of cores available

%% Create parfeval future output objects
cal_future      = parallel.FevalFuture;
montage_future  = parallel.FevalFuture;
vid_future      = parallel.FevalFuture;

% % Remaining slots for registration and averaging 
% n_workers_remaining = num_workers - ...
%     numel(cal_future) - numel(montage_future) - 1;
% vid_future(1:n_workers_remaining) = parallel.FevalFuture;
% if n_workers_remaining < 1
%     vid_future = parallel.FevalFuture;
% end

%% Establish data Queues
cq = parallel.pool.DataQueue;
vq = parallel.pool.DataQueue;
mq = parallel.pool.DataQueue;

end

