function out_path = prepMiniMontage(in_path, vid_nums)
%prepMiniMontage copies images into a separate directory to test in
%preparation for checking whether they connect

% Make a separate folder for a copy of these images
out_path = fullfile(in_path, datestr(datetime('now'), 'hhMMss'));
if exist(out_path, 'dir') == 0
    mkdir(out_path);
end

% Copy images into that directory
for ii=1:numel(vid_nums)
    tif_search = dir(fullfile(in_path, sprintf('*_%s_*', vid_nums{ii})));
    for jj=1:numel(tif_search)
        copyfile(fullfile(in_path, tif_search(jj).name), out_path);
    end
end


end

