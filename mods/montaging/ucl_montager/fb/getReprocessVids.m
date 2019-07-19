function [reprocess_vid_nums, vid_pairs, montages] = getReprocessVids(montages, locs)
%getReprocessVids Determines which videos would be the best to reprocess in
%order to connect disjoints in the montage

%% Sort by decreasing size
msizes = zeros(size(montages));
for ii=1:numel(montages)
    msizes(ii) = numel(montages(ii).txfms);
end
[~, I] = sort(msizes, 'descend');
montages = montages(I);

%% Gather information about theoretical and experimental overlap
for ii=1:numel(montages)
    % Make a structure for recording information about each image. Number,
    % expected location, actual location, expected size, actual size,
    montages(ii).images(numel(montages(ii).txfms)).num = '';
    for jj=1:numel(montages(ii).txfms)
        % todo: add tif names to aviSet or include that information in the
        % regAvg.mat so that I don't have to guess at the video number here
        img_ffname = montages(ii).txfms{jj}{1};
        [~,img_name,~] = fileparts(img_ffname);
        nameparts = strsplit(img_name, '_');
        vidnum = nameparts{find(strcmp(nameparts, 'confocal'))+1};
        montages(ii).images(jj).num = vidnum;
        this_loc_ind = strcmp(locs.vidnums, vidnum);
        
        % Get expected coordinates
        coords = str2double(...
            strsplit(...
            strrep(locs.coords(this_loc_ind, :), ' ', ''), ...
            ','));
        montages(ii).images(jj).xyt = coords;
        
        % Get FOV
        fov = locs.fovs(this_loc_ind);
        montages(ii).images(jj).fov = fov;
        
        % Get opposite corners of image
        montages(ii).images(jj).tlc_t = coords - fov/2;
        montages(ii).images(jj).brc_t = coords + fov/2;
        
        % Find photoshop coordinates
        montages(ii).images(jj).xye = [montages(ii).txfms{jj}{2:3}];
        xy = [montages(ii).txfms{jj}{2:3}];
        ht = montages(ii).txfms{jj}{4};
        wd = montages(ii).txfms{jj}{5};
        
        montages(ii).images(jj).tlc_e = xy - [wd/2, ht/2];
        montages(ii).images(jj).brc_e = xy + [wd/2, ht/2];        
    end
end

%% Determine expected and actual overlap
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).images)
%         montages(ii).images(jj).vid_pair = {};
        montages(ii).images(jj).neighbor = [];
        
        % Start for loops over
        for kk=1:numel(montages)
            if kk<=ii % Don't look within or back at connected montages
                continue;
            end
            for mm=1:numel(montages(kk).images)
                % Check if these images are expected to overlap
                [overlap, amount, theta_deg] = doOverlap(...
                        montages(ii).images(jj).tlc_t, ...
                        montages(ii).images(jj).brc_t, ...
                        montages(kk).images(mm).tlc_t, ...
                        montages(kk).images(mm).brc_t);
                if overlap
                    % Disjoint found, add neighbor to montage structure
%                     montages(ii).images(jj).vid_pair = ...
%                         [montages(ii).images(jj).vid_pair; ...
%                         {montages(ii).images(jj).num, ...
%                         montages(kk).images(mm).num, ...
%                         amount, theta_deg}];
                    neighbor.num = montages(kk).images(mm).num;
                    neighbor.amount = amount;
                    neighbor.angle = theta_deg;
                    montages(ii).images(jj).neighbor = vertcat(...
                        montages(ii).images(jj).neighbor, ...
                        neighbor);
                    
                    fprintf(...
                        ['Vid %s expected to overlap with %s ', ...
                        'by %1.3f deg^2 at an angle of %1.2f deg, ', ...
                        'but doesn''t\n'], ...
                        montages(ii).images(jj).num, ...
                        montages(kk).images(mm).num, ...
                        amount, theta_deg);
                end
            end
        end
    end
end

%% Sort by most commonly mentioned, then by amount of expected overlap
% Get number of pairs
k=0;
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).images)
%         k=k+size(montages(ii).images(jj).vid_pair, 1);
        k=k+numel(montages(ii).images(jj).neighbor);
    end
end
% Generate video number and amount arrays
vid_pairs = cell(k, 2);
ol_amounts = zeros(k,1);
k=0;
for ii=1:numel(montages)
    for jj=1:numel(montages(ii).images)
%         for kk=1:size(montages(ii).images(jj).vid_pair, 1)
        for kk=1:numel(montages(ii).images(jj).neighbor)
            k=k+1;
            vid_pairs{k, 1} = montages(ii).images(jj).num;
            vid_pairs{k, 2} = montages(ii).images(jj).neighbor.num;
            ol_amounts(k) = montages(ii).images(jj).neighbor.amount;
%             vid_pairs{k, 1} = montages(ii).images(jj).vid_pair{kk, 1};
%             vid_pairs{k, 2} = montages(ii).images(jj).vid_pair{kk, 2};
%             ol_amounts(k) = montages(ii).images(jj).vid_pair{kk, 3};
        end
    end
end
% Sort by most prevalent
[u_vid_nums, ~, ic] = unique(vid_pairs(:));
n_exp_ol = zeros(size(u_vid_nums));
for ii=1:numel(u_vid_nums)
    n_exp_ol(ii) = numel(find(ii==ic));
end
[~,I] = sort(n_exp_ol, 'descend');
order_vid_nums = u_vid_nums(I);

% Put the highest priority pairs at the top (most overlapping)
reprocess_vid_nums = cell(numel(order_vid_nums), 1);
si=1;
for ii=1:numel(order_vid_nums)/2
    % Add next most prevalent video to the next slot in queue
    if any(strcmp(reprocess_vid_nums, order_vid_nums{ii}))
        continue;
    end
    reprocess_vid_nums{si} = order_vid_nums{ii};
    si=si+1;
    % Followed by its most highly overlapping partner
    vid_pair_index = any(contains(vid_pairs, order_vid_nums{ii}), 2);
    these_vid_pairs = vid_pairs(vid_pair_index, :);
    [~, I] = sort(ol_amounts(vid_pair_index), 'descend');
    sorted_vid_pairs = these_vid_pairs(I,:);
    sorted_vid_pairs(strcmp(sorted_vid_pairs, order_vid_nums{ii})) = [];
    % Remove videos already in the queue
    for jj=1:si
        sorted_vid_pairs(strcmp(sorted_vid_pairs, reprocess_vid_nums{jj})) = [];
    end
    if ~isempty(sorted_vid_pairs)
        reprocess_vid_nums{si} = sorted_vid_pairs{1};
    else
        continue;
    end
    si=si+1;
end

% Add the rest
for ii=1:numel(order_vid_nums)
    if ~any(strcmp(reprocess_vid_nums, order_vid_nums{ii}))
        idx = find(cellfun(@isempty, reprocess_vid_nums), 1);
        reprocess_vid_nums{idx} = order_vid_nums{ii};
    end
end
    
end


