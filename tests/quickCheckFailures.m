ra = dir(fullfile(raw_path, '*regAvg.mat'));
for ii=1:numel(ra)
    load(fullfile(raw_path, ra(ii).name), 'status');
    if ~status
        fprintf('Failure in %s\n', ra(ii).name);
    end
end