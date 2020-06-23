function output = persistent_load(in_ffname, pause_sec, max_iterations)
%persistent_load use this when trying to load a .mat file as soon as it's
%available, this makes sure the program doesn't crash if you catch it while
%it's still writing

%% Default
output = [];

%% Check for proper input
[~,~,ext] = fileparts(in_ffname);
assert(strcmpi(ext, '.mat'), 'Extension must be .mat');
assert(exist(in_ffname, 'file')~=0, 'File not found');

%% Check optional inputs
if exist('pause_sec', 'var') == 0 || isempty(pause_sec)
    pause_sec = 0.01; % 10ms
end
if exist('max_iterations', 'var') == 0 || isempty(max_iterations)
    max_iterations = 100; % wait a total of 1s by default
end

%% Try to load
for ii=1:max_iterations
    try
        output = load(in_ffname);
        return;
    catch MException
        if contains(MException.message, 'Unable to read MAT-file')
            % Expected error message segment
            pause(pause_sec)
        else
            % Something else went wrong
            rethrow(MException);
        end
    end
end
% If this line is reached, we failed
error('Failed to read MAT-file');

end

