function next_dsin = getNextDsin(cal_data)
%getNextDsin Finds the next desinusoid object that is ready for processing

% Return empty by default
next_dsin = [];

% Determine the first one in the database that is ready for processing
for ii=1:numel(cal_data.dsin)
    if ~cal_data.dsin(ii).processing && ~cal_data.dsin(ii).processed && ...
            ~isempty(cal_data.dsin(ii).h_filename) && ...
            ~isempty(cal_data.dsin(ii).v_filename) && ...
            ~isempty(cal_data.dsin(ii).fov) && ...
            ~isempty(cal_data.dsin(ii).wavelength)
        next_dsin = cal_data.dsin(ii);
        break;
    end
end


end

