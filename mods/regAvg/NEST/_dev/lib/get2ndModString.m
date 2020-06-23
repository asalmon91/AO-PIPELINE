function other_mod_string = get2ndModString(vidname, mod1, mods)
%get2ndModString creates a comma separated string of the secondary
%modalities

other_mods = mods;
other_mods(contains(other_mods, mod1)) = [];
other_mod_string = cell(size(other_mods));
for ii=1:numel(other_mods)
    other_mod_string{ii} = ...
        strrep(vidname, mod1, other_mods{ii});
end
other_mod_string = strjoin(other_mod_string, ', ');
            
end

