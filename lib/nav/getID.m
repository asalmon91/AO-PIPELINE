function id_tag = getID(ao_vid_filename)
%getID Infers the id from the filename of one of the videos

%% Default
id_tag = 'ID';

% Due to the different styles of ID's, find either the wavelength or eye,
% figure out which comes first, then take everything before that to be the
% ID
WL_EXPR = '[_][\d]+nm[_]';
EYE_EXPR = 'O[DS]';

wl_idx = regexp(ao_vid_filename, WL_EXPR, 'once');
eye_idx = regexp(ao_vid_filename, EYE_EXPR, 'once');

min_idx = min([wl_idx, eye_idx]);
if ~isempty(min_idx)
    id_tag = ao_vid_filename(1:min_idx-1);
else
    warning('Failed to infer ID from %s', ao_vid_filename);
end

end

