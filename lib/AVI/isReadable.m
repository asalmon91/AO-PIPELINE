function readSuccess = isReadable(in_path, in_fnames)
%isReadable Tries to read a file (or files) to determine if it is ready for
% processing

if ~iscell(in_fnames)
    in_fnames = {in_fnames};
end

readSuccess = false(size(in_fnames));
for ii=1:numel(in_fnames)
    try
        vr = VideoReader(fullfile(in_path, in_fnames{ii})); %#ok<NASGU,TNMLP>
        clear vr;
        readSuccess(ii) = true;
    catch MException
        if ...
                strcmp(MException.identifier, ...
                'MATLAB:audiovideo:VideoReader:InitializationFailed') || ...
                strcmp(MException.identifier, ...
                'MATLAB:audiovideo:VideoReader:FileNotFound')
            % Do nothing
            % todo: figure out why a file not found error is getting thrown
            % when they definitely exist...
        else
            rethrow(MException)
        end
    end
end

end

