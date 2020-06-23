function db = updateMontageProfile(db)
%updateMontageProfile updates the clock arrays for montaged images

% Sorry about this horrible mess. This section can be removed if
% profiling is not needed
for ii=1:numel(db.vid.vid_set)
	if isempty(db.vid.vid_set(ii).t_proc_mon)
		found_in_montage = false;
		for jj=1:numel(db.vid.vid_set(ii).vids)
			if found_in_montage
				break
			end
			for kk=1:numel(db.vid.vid_set(ii).vids(jj).fids)
				if found_in_montage
					break
				end
				for mm=1:numel(db.vid.vid_set(ii).vids(jj).fids(kk).cluster)
					if ~db.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).success
						continue;
					end

					key = findImageInMonDB(db, ...
						db.vid.vid_set(ii).vids(jj).fids(kk).cluster(mm).out_fnames(1));
					if ~all(key==0)
						% It doesn't count if it's not attached to an image from a
						% different video
						% Get video numbers for all videos in this
						% montage
						all_ffnames = cellfun(@(x) x{1}, db.mon.montages(key(1)).txfms, 'uniformoutput', false)';
						[~, all_names, all_exts] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
						all_fnames = cellfun(@(x,y) [x, y], all_names, all_exts, 'uniformoutput', false);
						all_vn = zeros(size(all_fnames));
						for nn=1:numel(all_fnames)
							k = matchImgToVid(db.vid.vid_set, all_fnames{nn});
							all_vn(nn) = db.vid.vid_set(k(1)).vidnum;
						end
						all_vn = unique(all_vn);
						if ~all(all_vn == db.vid.vid_set(ii).vidnum)
							found_in_montage = true;
							db.vid.vid_set(ii).t_proc_mon = clock;
							break;
						end
					end
				end
			end
		end
	end
end

end

