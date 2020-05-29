function dsins = createDsin(in_path)
%createDsin Creates desinusoid files from grid videos

% % Optional input arg
% if exist(cyc_per_mm, 'var') == 0 || isempty(cyc_per_mm)
%     cyc_per_mm = 3000/25.4;
% end
cyc_per_mm = 3000/25.4;

%% Find pairs
gridPairs = pairHorzVert(in_path);
if isempty(gridPairs)
    dsins = [];
    return;
end

%% Measure grid frequencies and generate desinusoid matrix
dsins(numel(gridPairs)).lut = [];
for ii=1:numel(gridPairs)
    dsins(ii).lut = getDsin(in_path, gridPairs(ii), cyc_per_mm);
end

end

