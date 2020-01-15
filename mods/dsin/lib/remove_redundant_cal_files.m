function remove = remove_redundant_cal_files(orientations, fovs, wavelengths, datenums)
%remove_redundant_cal_files figures out which files are outdated

%% Default
remove = false(size(orientations));

%% Get a string of parameters which should be unique
param_str = cellfun(@(x,y,z) sprintf('%s, %0.3f, %0.3f', x, y, z), ...
    orientations, ...
    mat2cell(fovs, ones(size(fovs))), ...
    mat2cell(wavelengths, ones(size(fovs))), 'uniformoutput', false);
[u_param_str, ~, ic] = unique(param_str);

%% Identify redundant files
redundant = false(size(param_str));
for ii=1:numel(u_param_str)
    if numel(find(ic==ii)) > 1
        redundant(ii==ic) = true;
    end
end

%% Figure out which of the redundant files to remove
if any(redundant)
    % Choose the more recent one
    for ii=1:numel(u_param_str)
        these_datenums = datenums(ic==ii);
        if numel(these_datenums) > 1
            [~, max_idx] = max(these_datenums);
            these_indices = find(ic==ii);
            remove_subset = true(size(these_indices));
            remove_subset(max_idx) = false;
            remove(these_indices) = remove_subset;
        end
    end
end

end

