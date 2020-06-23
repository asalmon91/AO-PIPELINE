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
    catch me
        expected_err_ids = {
            'MATLAB:audiovideo:VideoReader:FilePermissionDenied';
            'MATLAB:audiovideo:VideoReader:InitializationFailed';
            'MATLAB:audiovideo:VideoReader:FileNotFound'};
        
        if any(strcmp(me.identifier, expected_err_ids))
            % Do nothing
            % todo: figure out why a file not found error is getting thrown
            % when they definitely exist...
        else
            rethrow(me)
        end
    end
end

end

