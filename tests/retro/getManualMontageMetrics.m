%% Import list of manual montage full filenames
% uiget

mon_scales_ppd = zeros(size(man_mon_ffname));
for ii=1:numel(man_mon_ffname)
    [mon_path, mon_name, mon_ext] = fileparts(man_mon_ffname{ii});
    disp(mon_name)
    winopen(mon_path);
    pause();
end
