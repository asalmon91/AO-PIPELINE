function [dsins, db_keys] = getReadyDsin(dsins)
%getReadyDsin returns an array of dsins that are ready for processing, and their associated
%addresses within the database
% todo: hopefully this will be a method of the calibration database class

remove = true(size(dsins));
db_keys = 1:numel(dsins);
for ii=1:numel(dsins)
	remove(ii) = ...
		dsins(ii).processing || dsins(ii).processed || ...
		isempty(dsins(ii).h_filename) || isempty(dsins(ii).v_filename) || ...
		isempty(dsins(ii).fov) || isempty(dsins(ii).wavelength);
end
dsins(remove)	= [];
db_keys(remove) = [];

end