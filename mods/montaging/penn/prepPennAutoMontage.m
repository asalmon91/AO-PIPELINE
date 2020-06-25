function db = prepPennAutoMontage(db, paths)
%prepPennAutoMontage prepares for automontaging by setting up the Vision Lab Features Library and making
%a position file from the Fixation Software output

%% Set up the Vision Lab Features Library
vl_setup;
vl_version verbose
% TODO: check to see if vl_setup worked

%% Get position file
paths.mon_out = fullfile(paths.mon, 'FULL');
if exist(paths.mon_out, 'dir') == 0
    mkdir(paths.mon_out);
end
loc_search = find_AO_location_file(paths.root);
[loc_folder, loc_name, loc_ext] = fileparts(loc_search.name);
loc_data = processLocFile(loc_folder, [loc_name, loc_ext]);
db.mon.loc_file = loc_search;
db.mon.loc_data = loc_data;

%% Gather other metadata
if ~isfield(db, 'id') || isempty(db.id)
    db.id = getID(db.vid.vid_set(1).vids(1).filename);
end
if ~isfield(db, 'date') || ~isfield(db, 'eye') || ...
        isempty(db.date) || isempty(db.eye)
    [date_str, eye_str] = getDateAndEye(paths.root);
    db.date = date_str;
    db.eye  = eye_str;
end

%% Create a position file compatibile with the Penn AM
% todo: input data directly, rather than having to write and read an excel
% file, which causes problems all the time
% Althgough it is helpful for manual feedback to have a position file made
[out_ffname, ~, ok] = fx_fix2am(loc_search.name, ...
                'human', 'penn', db.cal.dsin, [], ...
                db.id, db.date, db.eye, paths.mon_out);
if ~ok
    error('Something went wrong while reading %s', loc_search.name);
end

db.mon.PennPosFile = out_ffname{1};

end

