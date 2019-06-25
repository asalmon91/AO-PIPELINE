function ver_no = getAnimalImgNoteVersion( fname )
%getAnimalImgNoteVersion returns the version number of the imaging notes to
%imform processing
%   only version 3 is handled so far

name_parts = strsplit(fname, '_');
ver_str = name_parts{~cellfun(@isempty, regexp(name_parts, 'v[\d]+'))};
ver_no = str2double(ver_str(2:end));

end

