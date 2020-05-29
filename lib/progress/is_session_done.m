function session_complete = is_session_done(in_path, ld)
%is_session_done checks if a done.txt file exists indicating session
%completion

%% Default
session_complete = false;
if ~isfield(ld.vid, 'vid_set') || isempty(ld.vid.vid_set) || ...
        ~isfield(ld.cal, 'dsin') || isempty(ld.cal.dsin) || ...
        ~isfield(ld.mon, 'montages') || isempty(ld.mon.montages)
    return;
end

% Go until all videos have an image in a montage
all_vn = [ld.vid.vid_set.vidnum]';
vn_montaged = false(size(all_vn));
for ii=1:numel(ld.mon.montages)
    all_ffnames = cellfun(@(x) x{1}, ld.mon.montages(ii).txfms, 'uniformoutput', false);
    [~, all_names] = cellfun(@fileparts, all_ffnames, 'uniformoutput', false);
    vn_idx = regexp(all_names, '_\d\d\d\d_', 'once');
    vn_str = cellfun(@(x,y) x(y+1:y+4), all_names, vn_idx, 'uniformoutput', false);
    vn = cellfun(@str2double, unique(vn_str));
    for jj=1:numel(vn)
        vn_montaged = vn_montaged | all_vn == vn(jj);
    end
end


%% Check for completion
% todo: eventually there will be some other signal for completion; closing
% the montage display GUI for example should be the indication.
session_complete = exist(fullfile(in_path, 'done.txt'), 'file') ~= 0 && ...
    all([ld.vid.vid_set.processed]) && all([ld.cal.dsin.processed]) && ...
    all(vn_montaged);

end

