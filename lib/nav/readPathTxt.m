function repo_path = readPathTxt(local_path)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

% Default if fail
repo_path = 0;

% Path should be save in .txt file called path
[fid, err] = fopen(fullfile(local_path, 'path.txt'), 'r');
if isempty(err)
    repo_path = fscanf(fid,'%255c');
else
    warning('Failure to read repo path in %s', local_path);
end
fclose(fid);


end

