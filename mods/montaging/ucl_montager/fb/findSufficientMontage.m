function montages = findSufficientMontage(montages, loc_data)
%findSufficientMontage Determines if any of the montages contain at least
%one image from every video

if isempty(loc_data)
    return;
end

for ii=1:numel(montages)
    % Get all video numbers
    all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
    [~, all_names] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
    vn_idx = regexp(all_names, '_\d\d\d\d_', 'once');
    vn_str = cellfun(@(x,y) x(y+1:y+4), all_names, vn_idx, 'uniformoutput', false);
    % TODO: These are awkward to work with. Eventually we should come up with a
    % montage class that simplifies this process
    vn_str = unique(vn_str);
    if numel(vn_str) == numel(loc_data.vidnums)
        matches = false(size(vn_str));
        for jj=1:numel(vn_str)
            matches(jj) = ismember(vn_str{jj}, loc_data.vidnums);
            if ~matches(jj)
                break;
            end
        end
        if all(matches)
            fprintf('Montage %i contains at least one image from every video.\n', ii);
            % todo: based on this information, we'll probably want to
            % delete all the unnecessary montages and images, for starters,
            % let's just remove the unnecessary montages
            montages = montages(ii);
            return;
        end
    end
end

%% Additionally, check if any one montage covers all unique locations
% TODO: it's very possible that this is still not sufficient. A more robust
% approach would be to check the acutal alignment values in the montage.
% Each expected location should have a certain area covered. 
% Could go to each target location, and check whether any images contain a 
% 50um^2 area. For now, since this is for the LIVE version with FFR, can
% ignore
u_locs = unique([fixCoordsToMat(loc_data.coords), loc_data.fovs], 'rows');
for ii=1:numel(montages)
    if numel(montages(ii).txfms) < size(u_locs, 1)
        continue;
    end
    u_loc_match = false(size(u_locs, 1), 1);
    
    % Get all video numbers
    all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
    [~, all_names] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
    vn_idx = regexp(all_names, '_\d\d\d\d_', 'once');
    vn_str = cellfun(@(x,y) x(y+1:y+4), all_names, vn_idx, 'uniformoutput', false);
    vn_str = unique(vn_str);
    if numel(vn_str) < numel(u_loc_match)
        % Impossible for this one to contain everything
        continue;
    end
    
    for jj=1:numel(vn_str)
        loc_idx = strcmp(vn_str{jj}, loc_data.vidnums);
        ex_loc = fixCoordsToMat(loc_data.coords(loc_idx, :));
        this_fov = loc_data.fovs(loc_idx);
        
        for kk=1:numel(u_loc_match)
            if isequal([ex_loc, this_fov], u_locs(kk,:))
                u_loc_match(kk) = true;
                break;
            end
        end
    end
    if all(u_loc_match)
        fprintf('Montage %i covers all unique locations.\n', ii);
        % todo: based on this information, we'll probably want to
        % delete all the unnecessary montages and images, for starters,
        % let's just remove the unnecessary montages
        montages = montages(ii);
        return;
    end
end

end

