function paths = initPaths(root_path)
%initPaths initializes paths structure and checks for existence

paths.root = root_path;
paths.raw = guessPath(root_path, 'Raw');
paths.cal = guessPath(root_path, 'Calibration');
paths.mon = guessPath(root_path, 'Montages');
paths.pro = guessPath(root_path, 'Processed');

% todo: create some failsafe in case these aren't where we expect


end

