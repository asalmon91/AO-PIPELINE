function [verified, err_msg, version_str] = verifyLocFile(in_ffname)
%verifyLocFile checks whether the supplied file is an AO position file
%   Also determines version # to inform proper processing

%% Constants
MATCH_EXP = 'v\d';
LATEST_VER = '0.1';

%% Defaults
verified = false;
err_msg = [];
version_str = [];

%% Read file
try
    raw = readFixGuiFile(in_ffname);
    loc_head = raw(1,:);
catch MException
    verified = false;
    err_msg = MException.message;
    return;
end

%% Check contents
% First element should be the version #
ver_check = regexp(loc_head{1}, MATCH_EXP);
if ischar(loc_head{1}) &&  ~isempty(ver_check) && ver_check == 1
    % Extract version # and treat accordingly
    version_str = loc_head{1}(2:end);
    switch version_str
        case '0.1'
            loc_head = loc_head(2:end); % remove ver# and check the rest
            verified = ...
                all(contains(loc_head, 'Horizontal Location') | ...
                contains(loc_head, 'Vertical Location') | ...
                contains(loc_head, 'Horizontal FOV') | ...
                contains(loc_head, 'Vertical FOV') | ...
                contains(loc_head, 'Eye'));
            if ~verified
                err_msg = 'File header does not match expectations';
            end
        otherwise
            % TODO: DRY violation, should make one more function that
            % accepts the ver# as an input and call here after the warning
            warning(['Unsupported version of position file: %s\n', ...
                'Attempting to read as version %s.'], ...
                version_str, LATEST_VER);
            loc_head = loc_head(2:end); % remove ver# and check the rest
            verified = ...
                all(contains(loc_head, 'Horizontal Location') | ...
                contains(loc_head, 'Vertical Location') | ...
                contains(loc_head, 'Horizontal FOV') | ...
                contains(loc_head, 'Vertical FOV') | ...
                contains(loc_head, 'Eye'));
            if ~verified
                err_msg = 'File header does not match expectations';
            end
    end
else
    if ~ischar(loc_head{1})
        err_msg = 'Contents did not match expectations';
    elseif regexp(loc_head{1}, MATCH_EXP) ~= 1
        err_msg = 'Version # not found';
    else
        err_msg = 'Unknown error';
    end
end

end






