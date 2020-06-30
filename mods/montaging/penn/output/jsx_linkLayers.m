function fid_in = jsx_linkLayers(fid_in, layer_names)
% Robert F Cooper 10-17-2014
%   This function takes in a cell array of names for photoshop to link
%   together. It does this by making the first layer in the list active,
%   then adding all other layers to the existing selection.
%	Alex Salmon - 2020.06.29 - Modified to write to .jsx file

if length(layer_names) > 1
	jsx_setActiveLayer(fid_in, layer_names{1});

	for i=2:length(layer_names)

		jsx_addToSelection(fid_in, layer_names{i});

	end

	jsx_linkSelectedLayers(fid_in);
end

end

