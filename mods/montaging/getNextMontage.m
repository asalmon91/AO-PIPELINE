function img_fnames = getNextMontage(ld, paths, mod_order)
%getNextMontage determines un-montaged images and includes at least one image
%that has been previously montaged if available

%% Default
img_fnames = [];

% Check that video database exists
if ~isfield(ld, 'vid') || isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set)
	return;
end

%% Constants
SEARCH_DIST = 2; % it will try to montage any new images with images that are expected to be this far away (degrees)

%% Get all processed image names
% todo: find a more robust way to handle this. The UCL
% automontager only logs confocal. This could be a problem
% if confocal is not collected or different confocal
% wavelengths exist
prime_mod = mod_order{1};
sec_mods = mod_order;
sec_mods(1) = [];
img_fnames = dir(fullfile(paths.out, sprintf('*_%s_*.tif', prime_mod)));
img_fnames = {img_fnames.name}';

% Filter out images that don't have a complete set
remove = false(size(img_fnames));
for ii=1:numel(img_fnames)
	sec_img_ffnames = fullfile(paths.out, strrep(img_fnames{ii}, prime_mod, sec_mods'));
	for jj=1:numel(sec_img_ffnames)
		remove(ii) = exist(sec_img_ffnames{jj}, 'file') == 0;
		if remove(ii)
			break;
		end
	end
end
img_fnames(remove) = [];

% for ii=1:numel(ld.vid.vid_set)
%     if ~ld.vid.vid_set(ii).processed
%         continue;
%     end
%     for jj=1:numel(ld.vid.vid_set(ii).vids)
%         for kk=1:numel(ld.vid.vid_set(ii).vids(jj).fids)
%             for mm=1:numel(ld.vid.vid_set(ii).vids(jj).fids(kk).cluster)
%                 if ~ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).success
%                     continue;
%                 end
%                 out_fnames = ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames;
%                 % todo: find a more robust way to handle this. The UCL
%                 % automontager only logs confocal. This could be a problem
%                 % if confocal is not collected or different confocal
%                 % wavelengths exist
%                 out_fnames(~contains(out_fnames, sprintf('_%s_', prime_mod))) = [];
%                 img_fnames = [img_fnames; out_fnames]; %#ok<AGROW>
%             end
%         end
%     end
% end
if numel(img_fnames) < 2
    return;
end

%% Remove all images that have already been placed in a montage
% if isfield(ld.mon, 'montages') && ~isempty(ld.mon.montages)
%     montages = ld.mon.montages;
%     isMontaged = false(size(img_fnames));
%     for ii=1:numel(ld.mon.montages)
%         % Get all filenames
%         all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
%         [~, all_names, all_exts] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
%         all_fnames = cellfun(@(x,y) [x,y], all_names, all_exts, 'uniformoutput', false);
%         
%         for jj=1:numel(img_fnames)
%             if isMontaged(jj)
%                 continue;
%             end
%             if ismember(img_fnames{jj}, all_fnames)
%                 isMontaged(jj) = true;
%             end
%         end
%     end
%     % Remove them from the list
%     img_fnames(isMontaged) = [];
% end

%% Find videos that have no images that have been montaged
hasAnyMontaged = false(size(ld.vid.vid_set));
for ii=1:numel(ld.vid.vid_set)
    for jj=1:numel(ld.vid.vid_set(ii).vids)
        if hasAnyMontaged(ii)
            break;
        end
        for kk=1:numel(ld.vid.vid_set(ii).vids(jj).fids)
            if hasAnyMontaged(ii)
                break;
            end
            for mm=1:numel(ld.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                if ~ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).success
                    continue;
                end
                these_img_fnames = ...
                    ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames;
                % Filter by modality used in montager
                these_img_fnames = these_img_fnames(contains(these_img_fnames, prime_mod));
                key = findImageInMonDB(ld, these_img_fnames);
                if ~all(key==0)
                    hasAnyMontaged(ii) = true;
                    break;
                end
            end
        end
    end
end

%% Get the images from videos that have not been montaged yet
remove = false(size(img_fnames));
for ii=1:numel(img_fnames)
    key = matchImgToVid(ld.vid.vid_set, img_fnames{ii});
    remove(ii) = hasAnyMontaged(key(1));
end
img_fnames(remove) = [];
if isempty(img_fnames)
    return;
end

% DEV/DB
disp('Un-montaged images being included:')
disp(img_fnames);
% END DEV/DB

%% Determine expected neighbors
% Get locations of the new (non-montaged) images
all_vn = str2double(ld.mon.loc_data.vidnums);
src_locs = zeros(numel(img_fnames), 2);
src_vn = zeros(size(img_fnames));
for ii=1:numel(img_fnames)
    % Get this images's expected location
    key = matchImgToVid(ld.vid.vid_set, img_fnames{ii});
    src_vn(ii) = ld.vid.vid_set(key(1)).vidnum;
    loc_data_idx = all_vn == src_vn(ii);
    src_locs(ii,:) = fixCoordsToMat(ld.mon.loc_data.coords(loc_data_idx, :));
end
[src_vn, ~, ic] = unique(src_vn);
src_locs = src_locs(ic, :);
% src_locs = unique(src_locs, 'rows');

% Get the distances to the new images
trg_locs = zeros(numel(ld.vid.vid_set), 2);
trg_dists = zeros(numel(ld.vid.vid_set), numel(src_vn));
trg_vn = zeros(size(ld.vid.vid_set));
remove = false(size(ld.vid.vid_set));
for ii=1:numel(ld.vid.vid_set)
    remove(ii) = ~hasAnyMontaged(ii);
    if remove(ii)
        continue;
    end
    % Get this images's expected location
    trg_vn(ii) = ld.vid.vid_set(ii).vidnum;
    remove(ii) = ismember(trg_vn(ii), src_vn);
    if remove(ii)
        continue;
    end
    loc_data_idx = all_vn == trg_vn(ii);
    trg_locs(ii, :) = fixCoordsToMat(ld.mon.loc_data.coords(loc_data_idx, :));
    trg_dists(ii, :) = pdist2(trg_locs(ii, :), src_locs);
    remove(ii) = ~any(trg_dists(ii,:) <= SEARCH_DIST);
end
trg_vn(remove) = [];
trg_locs(remove, :) = [];
% trg_dists(remove, :) = [];
if isempty(trg_vn)
    return;
end

% Further filter target (previously montaged) images
% Find the minimum number of target images that overlap with the most
% source images
n_overlap = zeros(numel(trg_vn), numel(src_vn));

% trg_fovs = zeros(size(trg_vn));
trg_tlc_xy = zeros(numel(trg_vn), 2);
trg_brc_xy = trg_tlc_xy;

% src_fovs = zeros(size(src_vn));
src_tlc_xy = zeros(numel(src_vn), 2);
src_brc_xy = src_tlc_xy;

% Get corners for overlap assessment
for ii=1:numel(trg_vn)
    trg_fov = ld.vid.vid_set(all_vn == trg_vn(ii)).fov;
    trg_tlc_xy(ii,:) = trg_locs(ii,:) - trg_fov./2;
    trg_brc_xy(ii,:) = trg_locs(ii,:) + trg_fov./2;
end
for ii=1:numel(src_vn)
    src_fov = ld.vid.vid_set(all_vn == src_vn(ii)).fov;
    src_tlc_xy(ii,:) = src_locs(ii,:) - src_fov./2;
    src_brc_xy(ii,:) = src_locs(ii,:) + src_fov./2;
end
for ii=1:numel(trg_vn)
    for jj=1:numel(src_vn)
        [~, n_overlap(ii,jj)] = doOverlap(...
            trg_tlc_xy(ii,:), trg_brc_xy(ii,:), ...
            src_tlc_xy(jj,:), src_brc_xy(jj,:));
    end
end
% Remove any that are not expected to overlap
remove = ~any(n_overlap,2);
trg_vn(remove) = [];
trg_tlc_xy(remove,:) = [];
trg_brc_xy(remove,:) = [];
n_overlap(remove, :) = [];
if isempty(trg_vn)
    % No other images are expected to overlap
    return;
end

remove = ~any(n_overlap, 1);
src_vn(remove) = [];
src_tlc_xy(remove,:) = [];
src_brc_xy(remove,:) = [];
n_overlap(:, remove) = [];
% Find the best image that overlaps
best_trgs = zeros(size(src_vn));
for ii=1:numel(src_vn)
    best_trg_idx = find(n_overlap(:,ii) == max(n_overlap(:,ii)));
    
    if numel(best_trg_idx) > 1
        % Ties go to the trg with the most overlap with other srcs
        [~, I] = max(sum(n_overlap(best_trg_idx, :), 2));
        best_trg_idx = best_trg_idx(I);
    end
    best_trgs(ii) = best_trg_idx; 
    
end
trg_vn = trg_vn(unique(best_trgs));

% Gather images from these videos
trg_img_fnames = [];
for ii=1:numel(trg_vn)
    vni = trg_vn(ii) == all_vn;
    for jj=1:numel(ld.vid.vid_set(vni).vids)
        for kk=1:numel(ld.vid.vid_set(vni).vids(jj).fids)
            for mm=1:numel(ld.vid.vid_set(vni).vids(jj).fids(kk).cluster)
                if ~ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).success
                    continue;
                end
                these_img_fnames = ...
                    ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).out_fnames;
                these_img_fnames = these_img_fnames(contains(these_img_fnames, prime_mod));
                trg_img_fnames = [trg_img_fnames; these_img_fnames]; %#ok<AGROW>
            end
        end
    end
end

% DEV/DB
disp('Montaged images being included:')
disp(trg_img_fnames);
% END DEV/DB

img_fnames = [img_fnames; trg_img_fnames];


%% Add images at the boundary of a montage break
if numel(ld.mon.montages) <= 1
    return;
end

comb_tlc_xy = [src_tlc_xy; trg_tlc_xy];
comb_brc_xy = [src_brc_xy; trg_brc_xy];
comb_vn = [src_vn; trg_vn];

% Allow a set of images from one video from each disjoint
montages = ld.mon.montages;
remove = false(size(montages));
break_vn = zeros(size(remove));
for ii=1:numel(montages)
    all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
    [~, all_names, all_exts] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
    all_fnames = cellfun(@(x,y) [x,y], all_names, all_exts, 'uniformoutput', false)';
    
    these_vn = zeros(size(all_fnames));
    for jj=1:numel(these_vn)
        key = matchImgToVid(ld.vid.vid_set, all_fnames{jj});
        these_vn(jj) = ld.vid.vid_set(key(1)).vidnum;
    end
    these_vn = unique(these_vn);
    
    % Remove elements that are already part of comb_vn
    remove_trg = false(size(these_vn));
    for jj=1:numel(these_vn)
        remove_trg(jj) = ismember(these_vn(jj), comb_vn);
    end
    if all(remove_trg)
        remove(ii) = true;
        continue;
    end
    these_vn(remove_trg) = [];
    
    % Get corners for overlap assessment
    trg_tlc_xy = zeros(numel(these_vn), 2);
    trg_brc_xy = trg_tlc_xy;
    n_overlap = zeros(numel(these_vn), numel(comb_vn));
    for jj=1:numel(these_vn)
        % Get FOV
        vni = all_vn == these_vn(jj);
        trg_fov = ld.vid.vid_set(vni).fov;
        
        % Get center
        loc_data_idx = str2double(ld.mon.loc_data.vidnums) == these_vn(jj);
        trg_loc = fixCoordsToMat(ld.mon.loc_data.coords(loc_data_idx, :));
        
        % Get corners
        trg_tlc_xy(jj,:) = trg_loc - trg_fov./2;
        trg_brc_xy(jj,:) = trg_loc + trg_fov./2;
        
        % Measure overlap
        for kk=1:numel(comb_vn)
            n_overlap(jj, kk) = doOverlap(...
                comb_tlc_xy(kk,:),  comb_brc_xy(kk,:), ...
                trg_tlc_xy(jj,:),   trg_brc_xy(jj,:));
        end
    end
    % Find the image with the most overall overlap with the new images to
    % be montaged
    [~, I] = max(sum(n_overlap, 2));
    break_vn(ii) = these_vn(I(1));
end
break_vn(remove) = [];
break_vn = unique(break_vn);

% Gather images from these videos
break_img_fnames = [];
for ii=1:numel(break_vn)
    vni = all_vn == break_vn(ii);
    for jj=1:numel(ld.vid.vid_set(vni).vids)
        for kk=1:numel(ld.vid.vid_set(vni).vids(jj).fids)
            for mm=1:numel(ld.vid.vid_set(vni).vids(jj).fids(kk).cluster)
                if ~ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).success
                    continue;
                end
                these_img_fnames = ...
                    ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).out_fnames;
                these_img_fnames = these_img_fnames(contains(these_img_fnames, prime_mod));
                break_img_fnames = [break_img_fnames; these_img_fnames]; %#ok<AGROW>
            end
        end
    end
end

% DEV/DB
disp('Images from disjoints being included:')
disp(break_img_fnames);
% END DEV/DB

img_fnames = [img_fnames; break_img_fnames];



% if ~isfield(ld.mon, 'breaks') || isempty(ld.mon.breaks)
%     return;
% end



% break_vn = unique(cellfun(@str2double, ld.mon.breaks));
% % Get corners for overlap assessment
% % Combine previous src and trg
% src_tlc_xy = [src_tlc_xy; trg_tlc_xy];
% src_brc_xy = [src_brc_xy; trg_brc_xy];
% new_src_vn = [src_vn; trg_vn];
% trg_tlc_xy = zeros(numel(break_vn), 2);
% trg_brc_xy = trg_tlc_xy;
% n_overlap = zeros(numel(break_vn), size(src_tlc_xy, 1)); 
% remove = false(size(break_vn));
% for ii=1:numel(break_vn)
%     vni = all_vn == break_vn(ii);
%     % Remove ones that aren't processed yet
%     remove(ii) = ~ld.vid.vid_set(vni).processed;
%     if remove(ii)
%         continue;
%     end
%     
%     % Get center
%     loc_data_idx = str2double(ld.mon.loc_data.vidnums) == break_vn(ii);
%     trg_loc = fixCoordsToMat(ld.mon.loc_data.coords(loc_data_idx, :));
%     
%     % Get FOV
%     trg_fov = ld.vid.vid_set(vni).fov;
%     
%     % Get corners
%     trg_tlc_xy(ii,:) = trg_loc - trg_fov./2;
%     trg_brc_xy(ii,:) = trg_loc + trg_fov./2;
%     
%     for jj=1:size(src_tlc_xy, 1)
%         [~, n_overlap(ii,jj)] = doOverlap(...
%             trg_tlc_xy(ii,:), trg_brc_xy(ii,:), ...
%             src_tlc_xy(jj,:), src_brc_xy(jj,:));
%     end
% end
% n_overlap(remove,:) = [];
% break_vn(remove) = [];
% remove = ~any(n_overlap > 0, 2);
% n_overlap(remove, :) = [];
% break_vn(remove) = [];
% 
% % Check if any are non-zero for all
% if any(all(n_overlap > 0, 1))
%     break_idx = find(all(n_overlap > 0, 1));
% else
%     pause();
%     
% end
% break_vn = break_vn(break_idx);
% 
% break_img_fnames = [];
% % Gather images from this video
% for ii=1:numel(break_vn)
%     vni = all_vn == break_vn(ii);
%     for jj=1:numel(ld.vid.vid_set(vni).vids)
%         for kk=1:numel(ld.vid.vid_set(vni).vids(jj).fids)
%             for mm=1:numel(ld.vid.vid_set(vni).vids(jj).fids(kk).cluster)
%                 if ~ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).success
%                     continue;
%                 end
%                 these_img_fnames = ...
%                     ld.vid.vid_set(vni).vids(jj).fids(kk).cluster(mm).out_fnames;
%                 these_img_fnames = these_img_fnames(contains(these_img_fnames, prime_mod));
%                 break_img_fnames = [break_img_fnames; these_img_fnames]; %#ok<AGROW>
%             end
%         end
%     end
% end


%     % Append all images from each video involved in a break
%     for bb=1:numel(break_vn)
%         vid_idx = all_vn == break_vn(bb);
%         if ~any(vid_idx) || ~ld.vid.vid_set(vid_idx).processed
%             % The location updating is usually faster than the construction
%             % of video sets, skip this one
%             continue;
%         end
%         
%         for jj=1:numel(ld.vid.vid_set(vid_idx).vids)
%             for kk=1:numel(ld.vid.vid_set(vid_idx).vids(jj).fids)
%                 for mm=1:numel(ld.vid.vid_set(vid_idx).vids(jj).fids(kk).cluster)
%                     % todo: fix this so that it doesn't hard code selecting
%                     % confocal
%                     out_fnames = ...
%                         ld.vid.vid_set(vid_idx).vids(jj).fids(kk).cluster(mm).out_fnames;
%                     out_fnames = out_fnames{contains(out_fnames, prime_mod)};
%                     
%                     img_fnames = [img_fnames; out_fnames];
%                 end
%             end
%         end
%     end
% end



end

