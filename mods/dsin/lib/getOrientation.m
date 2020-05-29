function orientation = getOrientation(fnames)
%getOrientation determines if this grid video is horizontal or vertical

horz = contains(fnames, 'horz', 'ignorecase', true);
vert = contains(fnames, 'vert', 'ignorecase', true);
orientation = cell(size(fnames));
orientation(horz) = {'horz'};
orientation(vert) = {'vert'};

% Check for failures
if ~all(horz | vert)
    failed_fnames = fnames(~horz & ~vert);
    for ii=1:numel(failed_fnames)
        warning('Failed to determine orientation in %s.', ...
            failed_fnames{ii});
    end
end





end

