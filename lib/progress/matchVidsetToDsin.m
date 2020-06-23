function dsin_idx = matchVidsetToDsin(this_vidset, all_dsins)
%matchVidsetToDsin finds a desinusoid object that goes with the video set

dsin_idx = find(this_vidset.fov == [all_dsins.fov]' & [all_dsins.processed]');

end

