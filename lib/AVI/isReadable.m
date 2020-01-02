function readSuccess = isReadable(in_path, in_fnames)
%isReadable Tries to read a file (or files) to determine if it is ready for
% processing

readSuccess = false(size(in_fnames));
for ii=1:numel(in_fnames)
    try
        fid = fopen(fullfile(in_path, in_fnames{ii}), 'r');
        fclose(fid);
        readSuccess(ii) = true;
    catch
        % Do nothing
        % todo: should probably make sure the reason it failed is because
        % it's not accessible, and not some other error
    end
end

end

