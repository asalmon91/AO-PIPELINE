function id_tag = getID(aviSet)
%getID Infers the id from the filename of one of the videos

name_parts = strsplit(aviSet.fnames{1}, '_');
id_tag = strjoin(name_parts(1:2), '_');

end

