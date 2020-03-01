function txfm_xy = getTxfmdRectCoords(wh, txfm, global_dxdy)
%getTxfmdRectCoords gets the coordinates of the corners of a rectangle that
%has been transformed by txfm

% txfm(1:2,3) = -txfm(1:2,3);

xyz = [0,wh(1),wh(1),0; wh(2),wh(2),0,0; ones(1,4)]';
% Translate so it's centered on 0,0
center_shift_xyz = [wh(1)/2, wh(2)/2, 0];
xyz = xyz - center_shift_xyz; 
% Rotate it
rotation_txfm = txfm;
rotation_txfm(1:2, 3) = 0;
rotate_xyz = xyz*rotation_txfm';
% Translate it back to origin, then by txfm
txfm_xyz = rotate_xyz + [wh(1)/2, wh(2)/2, 0] + [txfm(1:2,3)',0] + [global_dxdy, 0];
txfm_xy = txfm_xyz(:,1:2);

% 
% % Rotate corners a
% xyz = [wh(1)
%     -wh(1)/2, wh(1)/2, wh(1)/2, -wh(1)/2; 
%     wh(2)/2, wh(2)/2, -wh(2)/2, -wh(2)/2; 
%     ones(1,4)]';
% txfm_xyz = xyz*txfm';
% txfm_xy = txfm_xyz(:,1:2);

% Not needed - these are equivalent
% % First rotate about the origin
% rotate_txfm = txfm;
% rotate_txfm(1:2, 3) = 0;
% rotate_xyz = xyz*rotate_txfm';
% % Then translate
% translate_txfm = eye(3);
% translate_txfm(1:2,3) = txfm(1:2,3);
% txfm_xyz = rotate_xyz*translate_txfm';
% txfm_xy = txfm_xyz(:,1:2);

end

