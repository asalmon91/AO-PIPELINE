function data = updateXY(data, fix_id, mov_id, tform, linked)

% Make coordinates of all frames in moving group relative to key frame
% Shift coordinates of all frames in moving group to the key frame of the
% fixed group
% Shift coordinates of all frames in moving group by computed transform
% between key frames of moving and fixed group

xy_orig = getAllXY(data(linked));
xy_mov = data(mov_id).xy;
xy_fix = data(fix_id).xy;
xy_txfm = tform.T(3,1:2);
xy_new = xy_orig - xy_mov + xy_fix + xy_txfm;
% figure;
% hold on;
% for ii=1:numel(linked)
%     plot(...
%         [xy_orig(ii,1), xy_new(ii,1)],...
%         [xy_orig(ii,2), xy_new(ii,2)],'xk')
% %     pause()
% end
% plot(xy_fix(1), xy_fix(2), 'rx');
% hold off;
% axis equal

for ii=1:numel(linked)
%     data(linked(ii)).xy = data(linked(ii)).xy - (data(mov_id).xy + data(fix_id).xy + tform.T(3,1:2));
    data(linked(ii)).xy = xy_new(ii,:);
end

end

