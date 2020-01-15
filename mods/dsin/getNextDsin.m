function dsin_idx = getNextDsin(cal_data)
%getNextDsin Finds the next desinusoid object that is ready for processing

% Return empty by default
dsin_idx    = [];

% Determine the first one in the database that is ready for processing
for ii=1:numel(cal_data.dsin)
    if ~cal_data.dsin(ii).processing && ~cal_data.dsin(ii).processed && ...
            ~isempty(cal_data.dsin(ii).h_filename) && ...
            ~isempty(cal_data.dsin(ii).v_filename) && ...
            ~isempty(cal_data.dsin(ii).fov) && ...
            ~isempty(cal_data.dsin(ii).wavelength)
        dsin_idx = ii;
        break;
    end
end


end

