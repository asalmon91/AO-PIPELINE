function okay_to_use = check_gpu_space(gpu_thr)
%check_gpu_space determines if there's sufficient space to process on the
%GPU. This is a really weak way to do it; we're probably not getting as 
%much use out of it as possible

%% Default
okay_to_use = true;

%% Optional Inputs
if exist('gpu_thr', 'var') == 0 || isempty(gpu_thr)
    gpu_thr = 0.5;
end

%% Check GPU
g = gpuDevice;
if isempty(g) || g.AvailableMemory/g.TotalMemory < gpu_thr
    okay_to_use = false;
end

end

