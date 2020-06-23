function out_path = prepMiniMontage(in_path, img_fnames)
%prepMiniMontage copies images into a separate directory to test in
%preparation for checking whether they connect

% Make a separate folder for a copy of these images
out_path = fullfile(in_path, datestr(datetime('now'), 'hhMMss'));
if exist(out_path, 'dir') == 0
    mkdir(out_path);
end

% Copy images into that directory
for ii=1:numel(img_fnames)
    copyfile(fullfile(in_path, img_fnames{ii}), out_path);
end


end

