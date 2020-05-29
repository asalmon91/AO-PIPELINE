function dn = clock2datenum(c)

if isempty(c)
    dn = [];
    return;
end

c = sprintf('%4.0f_%02.0f_%02.0f_%02.0f_%02.0f_%0.3f', ...
    c(1),c(2),c(3),c(4),c(5),c(6));
dn = datenum(c, 'yyyy_mm_dd_HH_MM_ss');

end
