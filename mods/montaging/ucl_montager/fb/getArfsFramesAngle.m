function out_frame_indices = getArfsFramesAngle(vid_num, in_path, in_angle)
%getArfsFramesAngle returns the frames to try in order to connect disjoints
%in a montage

% Get regAvg structure to determine which modality was successful
load(fullfile(in_path, sprintf('%s_regAvg.mat', vid_num)), 'aviSet');
for ii=1:numel(aviSet.reg)
    for jj=1:numel(aviSet.reg(ii).ref)
        if aviSet.reg(ii).ref(jj).success
            mod_used = aviSet.reg(ii).mod;
            mod_index = strcmp(aviSet.mods, mod_used);
            vid_fname = aviSet.fnames{mod_index};
            success_frame = aviSet.reg(ii).ref(jj).frame;
            break;
        end
    end
    if aviSet.reg(ii).ref(jj).success
        break;
    end
end

% Get the frames structure for that video
arfs_mat_fname = strrep(vid_fname, '.avi', '_arfs.mat');
load(fullfile(in_path, arfs_mat_fname), 'frames');

% Get the linked group and xy coords of the successful reference frame
lid = frames(success_frame).link_id;
xy  = frames(success_frame).xy;

% Find the frame that is farthest along the axis specified by @in_angle
% within the same linked group as the successful reference frame
ids = [frames(~[frames.rej]' & [frames.link_id]' == lid).id]';
xy_other = vertcat(frames(ids).xy);
xy_rel = xy_other - xy;
[theta, rho] = cart2pol(xy_rel(:,1), xy_rel(:,2));
% Use min distance from a point at max rho along in_angle as the criterion
% for selection
out_frame_indices = zeros(size(in_angle));
remove = false(size(in_angle));
for ii=1:numel(in_angle)
    tr_targ = repmat([in_angle(ii)*(pi/180), max(rho)], size(theta));
    dists = polardist(tr_targ, [theta, rho]);
    [~, I] = min(dists);
    out_frame_indices(ii) = ids(I);
    if out_frame_indices(ii) == success_frame
        remove(ii) = true;
        warning('No frame closer to break found');
    end
end
out_frame_indices(remove) = [];

% Troubleshooting graphics
% for ii=1:numel(in_angle)
%     tr_targ = repmat([in_angle(ii)*(pi/180), max(rho)], size(theta));
%     dists = polardist(tr_targ, [theta, rho]);
%     [~, I] = min(dists);
%     
%     figure;
%     scatter(xy(1), xy(2), 'rx');
%     hold on;
%     scatter(xy_other(:,1), xy_other(:,2), 'k.');
%     plot([xy(1); xy_other(I,1)], [xy(2); xy_other(I,2)], '-r');
%     hold off;
% end

end




