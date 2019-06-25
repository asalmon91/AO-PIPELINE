function [date_string, eye_string] = getDateAndEye(root_path)
%getDateAndEye the current folder should be of the form yyyy_mm_dd_OX

%% Defaults
eye_string = 'OX';
date_string = 'yyyy_mm_dd';

%% Expectations
date_n_digits = 10;
date_expr = '\d\d\d\d[_]\d\d[_]\d\d[_]';
eye_n_digits = 2;
eye_expr = '[_]O[DS]';

%% Get current directory
path_parts = strsplit(root_path, filesep);
current_dir = path_parts{end};

%% Get Date
date_search = regexp(current_dir, date_expr, 'once');
if ~isempty(date_search)
    date_string = current_dir(date_search:date_search+date_n_digits-1);
else
    % Older datasets were mm_dd_yyyy
    alt_date_expr = '\d\d[_]\d\d[_]\d\d\d\d[_]';
    date_search = regexp(current_dir, alt_date_expr, 'once');
    if ~isempty(date_search)
        date_string = current_dir(date_search:date_search+date_n_digits-1);
    else
        warning('Date search failed, defaulting to %s', date_string);
    end
end

%% Get Eye
eye_search = regexp(current_dir, eye_expr, 'once');
if ~isempty(eye_search)
    eye_string = current_dir(eye_search+1:eye_search+eye_n_digits);
else
    warning('Eye search failed, defaulting to %s', eye_string);
end

end

