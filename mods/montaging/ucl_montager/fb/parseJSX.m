function breaks = parseJSX(jsx_ffname)
%parseJSX obtains the transforms of each image for each disjointed montage
% breaks is 1xM struct with field txfms
% txfms is a 1xN cell array of 1x5 cell arrays
% M is the number of disjointed montages, N is the number of images per
% montage, and each cell contains the image full file name, the x, y, ht,
% and wd. Importantly, the x and y coordinates are the CENTER, not the
% origin

%% Constants
TXFM_EXPR  = 'var data[\d]+ = *';

%% Read jsx, look for txfm label
fid = fopen(jsx_ffname, 'r');
this_line = '';
disjoints = {}; % todo, figure out how to preallocate
sis = [];
eis = [];
while isempty(this_line) || ~isnumeric(this_line) && all(this_line ~= -1)
    this_line = fgetl(fid);
    if isnumeric(this_line)
        continue;
    end
    [si, ei] = regexp(this_line, TXFM_EXPR);
    if ~isempty(si)
        disjoints = [disjoints; {this_line}]; %#ok<*AGROW>
        sis = [sis; si];
        eis = [eis; ei];
    end
end
fclose(fid);

%% Evaluate variable assignments in matlab syntax
breaks(numel(disjoints)).txfms = {};
for ii=1:numel(disjoints)
    mat_line = disjoints{ii};
    mat_line = strrep(mat_line, '[', '{'); % switch to cell array
    mat_line = strrep(mat_line, ']', '}');
    mat_line(sis(ii):eis(ii)) = ''; % remove variable name
    % remove double slashes
    mat_line(regexp(mat_line, ['[',filesep,filesep,']{2}'])) = [];
    eval(sprintf('breaks(ii).txfms = %s;', mat_line));
end

end

