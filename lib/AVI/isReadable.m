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
        if any(strcmp(MException.identifier, ...
                {'MATLAB:audiovideo:VideoReader:UnknownCodec';
                'MATLAB:audiovideo:VideoReader:InitializationFailed';
                'MATLAB:audiovideo:VideoReader:FileNotFound';
                'MATLAB:audiovideo:VideoReader:FilePermissionDenied'}))
            % Do nothing
            % todo: figure out why a file not found error is getting thrown
            % when they definitely exist...
            
            % For the unknown codec error, double check that the input is
            % correct
            % todo: could make some assertions about the inputs at the
            % beginning to avoid this complicated try catch block
            if strcmp(MException.identifier, ...
                'MATLAB:audiovideo:VideoReader:UnknownCodec')
                [~,~,ext] = fileparts(fullfile(in_path, in_fnames{ii}));
                if ~strcmp(ext, '.avi')
                    rethrow(MException);
                end
            end
        else
            rethrow(MException)
        end
    end
end

end

