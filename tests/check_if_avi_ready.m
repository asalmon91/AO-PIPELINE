WAIT = 1;
in_path = 'E:\tmphide\live_test\2018_08_24_OS\Raw';
loop_condition=0;
while loop_condition==0
    avi_dir = dir(fullfile(in_path, '*.avi'));
    for ii=1:numel(avi_dir)
        try
            fid = fopen(fullfile(in_path, avi_dir(ii).name), 'r');
            fclose(fid);
            fprintf('%s is ready\n', avi_dir(ii).name);
        catch
            fprintf('%s is being written\n', avi_dir(ii).name);
        end
    end
    pause(WAIT)
end