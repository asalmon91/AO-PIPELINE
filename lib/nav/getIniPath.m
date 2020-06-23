function ini_path = getIniPath(ini, program_name)
%getIniPath

ini_path = [];
for ii=1:numel(ini)
    if strcmpi(ini(ii).name, program_name)
        ini_path = ini(ii).path;
        break;
    end
end

end

