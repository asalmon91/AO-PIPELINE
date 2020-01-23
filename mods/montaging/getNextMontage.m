function img_fnames = getNextMontage(ld)
%getNextMontage determines un-montaged images and includes at least one image
%that has been previously montaged if available

%% Default
img_fnames = [];

%% Get all processed image names
for ii=1:numel(ld.vid.vid_set)
    if ~ld.vid.vid_set(ii).processed
        continue;
    end
    for jj=1:numel(ld.vid.vid_set(ii).vids)
        for kk=1:numel(ld.vid.vid_set(ii).vids(jj).fids)
            for mm=1:numel(ld.vid.vid_set(ii).vids(jj).fids(kk).cluster)
                out_fnames = ld.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames;
                % todo: find a more robust way to handle this. The UCL
                % automontager only logs confocal. This could be a problem
                % if confocal is not collected or different confocal
                % wavelengths exist
                out_fnames(~contains(out_fnames, '_confocal_')) = [];
                img_fnames = [img_fnames; out_fnames];
            end
        end
    end
end

%% Remove all images that have already been placed in a montage
if isfield(ld.mon, 'montages') && ~isempty(ld.mon.montages)
    montages = ld.mon.montages;
    isMontaged = false(size(img_fnames));
    for ii=1:numel(ld.mon.montages)
        % Get all filenames
        all_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false);
        [~, all_names, all_exts] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
        all_fnames = cellfun(@(x,y) [x,y], all_names, all_exts, 'uniformoutput', false);
        
        for jj=1:numel(img_fnames)
            if isMontaged(jj)
                continue;
            end
            if ismember(img_fnames{jj}, all_fnames)
                isMontaged(jj) = true;
            end
        end
    end
    % Remove them from the list
    img_fnames(isMontaged) = [];
end

%% Add images at the boundary of a montage break
if isfield(ld.mon, 'breaks') && ~isempty(ld.mon.breaks)
    break_nums = cellfun(@str2double, ld.mon.breaks);
    all_vn = [ld.vid.vid_set.vidnum]';
    % Append all images from each video involved in a break
    for bb=1:numel(break_nums)
        vid_idx = all_vn == break_nums(bb);
        if ~any(vid_idx) || ~ld.vid.vid_set(vid_idx).processed
            % The location updating is usually faster than the construction
            % of video sets, skip this one
            continue;
        end
        
        for jj=1:numel(ld.vid.vid_set(vid_idx).vids)
            for kk=1:numel(ld.vid.vid_set(vid_idx).vids(jj).fids)
                for mm=1:numel(ld.vid.vid_set(vid_idx).vids(jj).fids(kk).cluster)
                    % todo: fix this so that it doesn't hard code selecting
                    % confocal
                    out_fnames = ...
                        ld.vid.vid_set(vid_idx).vids(jj).fids(kk).cluster(mm).out_fnames{1};
                    
                    img_fnames = [img_fnames; out_fnames];
                end
            end
        end
    end
end



end

