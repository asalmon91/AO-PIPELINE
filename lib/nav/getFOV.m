function aviSets = getFOV(in_path, aviSets)
%getFOV Extracts the fov for a video in the set

%% Constants
SCAN_TAG = 'optical_scanners_settings';
FOV_TAG     = 'resonant_scanner_amplitude_in_deg';

for ii=1:numel(aviSets)
    for jj=1:numel(aviSets(ii).fnames) % modality loop
        mat_ffname = fullfile(in_path, ...
            strrep(aviSets(ii).fnames{jj}, '.avi', '.mat'));
        
        if exist(mat_ffname, 'file') ~= 0
            try
                m = load(mat_ffname, SCAN_TAG); %#ok<NASGU>
                
                aviSets(ii).fov = eval(...
                    sprintf('m.%s.%s', SCAN_TAG, FOV_TAG));
                
                break; % out of the modality loop, 
            catch % do nothing
            end
        end
    end
end



end

