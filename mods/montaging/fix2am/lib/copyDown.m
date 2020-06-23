function new_cell_col = copyDown( cell_col )
%copyDown 

new_cell_col = cell_col;
last_non_nan_val = NaN;
for ii=1:numel(cell_col)
    if ~isnan(cell_col{ii})
        last_non_nan_val = cell_col{ii};
    else
        new_cell_col{ii} = last_non_nan_val;
    end
end


end

