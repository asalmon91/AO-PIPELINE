function redundant = getRedundantStrings(cell_array)
%getRedundantStrings finds duplicate strings in a 1D cell array

redundant = false(size(cell_array));
for jj=1:numel(cell_array)
    for kk=1:numel(cell_array)
        if kk<=jj || redundant(kk)
            continue;
        end
        redundant(kk) = strcmp(cell_array{jj}, cell_array{kk});
    end
end

end

