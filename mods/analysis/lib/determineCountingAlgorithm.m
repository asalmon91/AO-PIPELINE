function [alg_handle, modality] = determineCountingAlgorithm(roi, opts)
%determineCountingAlgorithm Chooses a cone counting algorithm based on the
%retinal location and species/condition

ROD_ZONE = 2.5; % degrees from fovea
modality = 'confocal'; % Default

switch opts.subject
    case 'Healthy Human'
        % Check distance from fovea, use split after 2 degrees
        if pdist2(roi.loc_deg, [0,0]) < ROD_ZONE
            alg_handle = @li_roorda_count_cones;
        else
            alg_handle = @cunefare_farsiu_split_cones;
            modality = 'split_det';
        end
        
    case {'13-LGS', 'ACHM'}
        alg_handle  = @cunefare_farsiu_split_cones;
        modality    = 'split_det';
        
    otherwise
        alg_handle  = @cunefare_farsiu_split_cones;
        modality    = 'split_det';
end






end

