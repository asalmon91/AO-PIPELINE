% simulate writing ao vids
[ao_fnames, ao_path] = uigetfile('*.avi', 'Select AO video', '.', ...
    'multiselect','on');
if ~iscell(ao_fnames)
    ao_fnames = {ao_fnames};
end
ao_fnames = ao_fnames';

out_path = uigetdir(ao_path, 'Select target directory');

for ii=1:numel(ao_fnames)
    % Load header and write to target directory
    mat_fname = strrep(ao_fnames{ii}, '.avi', '.mat');
    load(fullfile(ao_path, mat_fname));
    save(fullfile(out_path, mat_fname), ...
        'clinical_version', ...
        'frame_numbers', ...
        'frame_time_stamps', ...
        'image_acquisition_settings', ...
        'image_resolution_calculation_settings', ...
        'optical_scanners_settings');
    
    % Read video and write to target directory
    vid = fn_read_AVI(fullfile(ao_path, ao_fnames{ii}));
    fn_write_AVI(fullfile(out_path, ao_fnames{ii}), vid, 1/16, [], 0.5);
    
end

root_dir = uigetdir(ao_path, 'Select root directory to finish');
if isnumeric(root_dir)
    return;
end
fid = fopen(fullfile(root_dir, 'done.txt'), 'w');
fclose(fid);





