function [vidsets, db_keys] = getReadyVidsets(vidsets)
%getReadyVidsets returns an array of vidset objects that are ready for processing
%	todo: hopefully this could be a method of the video database class

remove = false(size(vidsets));
db_keys = 1:numel(vidsets);
for ii=1:numel(vidsets)
    remove(ii) = ...
		vidsets(ii).processing || vidsets(ii).processed || ...
		~all([vidsets(ii).vids.ready]) || ~vidsets(ii).hasCal || ~vidsets(ii).hasAllMods || ...
		isempty(vidsets(ii).fov) || isempty(vidsets(ii).vidnum);
end
vidsets(remove) = [];
db_keys(remove) = [];

end

