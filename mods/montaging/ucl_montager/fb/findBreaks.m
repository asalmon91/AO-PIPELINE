function [suggested_locations, break_vidnums] = findBreaks(db, montages, loc_data, opts)
%findBreaks identifies breaks in the montage and suggests acquisition
%locations

%% Defaults
suggested_locations = [];
break_vidnums = [];

%% Check input
if isempty(loc_data)
    return;
end

%% Find video numbers involved in breaks
all_break_pairs = [];
for ii=1:numel(montages)
    % Get all vidnums
    all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
    [~, all_names] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
    vn_idx = regexp(all_names, '_\d\d\d\d_', 'once');
    vn_str = cellfun(@(x,y) x(y+1:y+4), all_names, vn_idx, 'uniformoutput', false);
    vn_str = unique(vn_str);
    
    for jj=1:numel(montages(ii).txfms)
        % Determine video number
        [~,img_name,~] = fileparts(montages(ii).txfms{jj}{1});
        key = matchImgToVid(db.vid.vid_set, img_name);
%         this_vidnum = db.vid.vid_set(key(1)).vidnum;
        this_vidnum = db.vid.vid_set(key(1)).getVidNumStr;
        
%         vn_idx = regexp(img_name, '_\d\d\d\d_');
%         if isempty(vn_idx)
%             error('Failed to extract video number from %s', img_name);
%         end
%         if numel(vn_idx) > 1
%             % Sometimes the ID fits this description too. We should
%         end
%         this_vidnum = img_name(vn_idx+1:vn_idx+4); % warning: will break if padding ever changes
        
        % Determine index in the location data
        loc_idx = strcmp(this_vidnum, loc_data.vidnums);
        ex_loc = fixCoordsToMat(loc_data.coords(loc_idx, :));
        this_fov = loc_data.fovs(loc_idx);
        % Identify corner coordinates for checking overlap
        src_tlc = ex_loc-(this_fov/2);
        src_brc = ex_loc+(this_fov/2);
        
        % Look through the location data to see if it's supposed to overlap
        % with any images (by more than a certain threshold)
        overlaps = false(size(loc_data.vidnums));
        overlap_amounts = zeros(size(overlaps));
        for kk=1:numel(loc_data.vidnums)
            trg_xy = fixCoordsToMat(loc_data.coords(kk,:));
            trg_fov = loc_data.fovs(kk);
            trg_tlc = trg_xy-(trg_fov/2);
            trg_brc = trg_xy+(trg_fov/2);
            [overlaps(kk), overlap_amounts(kk)] = doOverlap(...
                src_tlc, src_brc, trg_tlc, trg_brc);
        end
        % Convert amounts to fraction of src area
        overlap_prop = overlap_amounts./(this_fov^2);
        % Filter out the source as well as by overlapping and by the threshold
        overlap_filt = ~loc_idx & overlaps & overlap_prop > opts.min_overlap;
        overlap_nums = loc_data.vidnums(overlap_filt);
        
        % Check whether all those images exist in the current 
        found = false(size(overlap_nums));
        for kk=1:numel(found)
            if ismember(overlap_nums{kk}, vn_str)
                found(kk) = true;
            end
        end
        overlap_nums(found) = [];
        if ~isempty(overlap_nums)
            break_pairs = [repmat({this_vidnum}, size(overlap_nums)), overlap_nums];
            all_break_pairs = vertcat(all_break_pairs, break_pairs);
        end
    end
end
% Clean up redundant pairs
remove = false(size(all_break_pairs, 1), 1);
for ii=1:size(all_break_pairs, 1)
    for jj=ii+1:size(all_break_pairs, 1)
        if all(cellfun(@(x,y) strcmp(x,y), all_break_pairs(ii,:), all_break_pairs(jj,:))) || ...
                all(cellfun(@(x,y) strcmp(x,y), all_break_pairs(ii,:), flip(all_break_pairs(jj,:),2)))
            remove(jj) = true;
        end
    end
end
all_break_pairs(remove,:) = [];

%% Get the locations involved in these breaks
% Suggest acquiring intermediate images
suggested_locations = zeros(size(all_break_pairs, 1), 2);
for ii=1:size(all_break_pairs, 1)
    loc_a = fixCoordsToMat(...
        loc_data.coords(...
        strcmp(all_break_pairs{ii,1}, loc_data.vidnums), :));
    loc_b = fixCoordsToMat(...
        loc_data.coords(...
        strcmp(all_break_pairs{ii,2}, loc_data.vidnums), :));
    suggested_locations(ii,:) = mean([loc_a; loc_b], 1);
end
suggested_locations = unique(suggested_locations, 'rows');
break_vidnums = all_break_pairs(:);

end

