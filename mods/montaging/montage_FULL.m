function [outputArg1,outputArg2] = montage_FULL(db, paths)
%montage_FULL handles input to the Penn Automontager
% Sets up the inital montage, and reprocesses videos as necessary
%
% References:
% [1] Chen M, Cooper RF, Han GK, Gee J, Brainard DH, Morgan JI. Multi-modal 
%   automatic montaging of adaptive optics retinal images. Biomed Opt 
%   Express. 2016;7(12):4899-918. doi: https://doi.org/10.1364/BOE.7.004899. 
%   PubMed PMID: 28018714; PMCID: PMC5175540.
% [2] Vedaldi A, Fulkerson B, editors. VLFeat: An open and portable library
%   of computer vision algorithms. Proceedings of the 18th ACM 
%   international conference on Multimedia; 2010.

% Set up the Vision Lab Features Library
vl_setup;
% vl_version verbose

% Get position file
paths.mon_out = fullfile(paths.mon, 'FULL');
if exist(paths.mon_out, 'dir') == 0
    mkdir(paths.mon_out);
end
loc_search = find_AO_location_file(paths.root);
% [loc_folder, loc_name, loc_ext] = fileparts(loc_search.name);
% loc_data = processLocFile(loc_folder, [loc_name, loc_ext]);
[out_ffname, ~, ok] = fx_fix2am(loc_search.name, ...
                'human', 'penn', db.cal.dsin, [], ...
                db.id, db.date, db.eye, paths.mon);

% Call Penn automontager
txfm_type   = 1; % Rigid
append      = false;
featureType = 0; % SIFT
exportToPS  = false;
montage_file = AOMosiacAllMultiModal(paths.out, out_ffname{1}, ...
    paths.mon_out, 'multi_modal', opts.mod_order', txfm_type, ...
    append, [], exportToPS, featureType);

pause();
% DEAL WITH BREAKS



end

