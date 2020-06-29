function fid_in = jsx_openFileInPS(fid_in, f)
%jsx_openFileInPS writes the instructions to open a file in photoshop
%   For more details, see psopendoc

%   Thomas Ruark, 2/23/2006
%   Copyright 2012 Adobe Systems Incorporated
%	Alex Salmon - 2020.06.29 - Modified to write to .jsx file

% an extra backslash on windows doesn't hurt
f = strrep(f, '\', '\\');

% build up the JavaScript
pstext = ['var result = "";' ...
    'var errorDetails = "";' ...
    'try {' ...
    '    app.open(File("' f '"));' ...
    '    result = app.activeDocument.name;' ...
    '}' ...
    'catch(e) {' ...
    '    errorDetails = e.toString();' ...
    '    result = "8F6AFB7E-EC1F-4b6f-AD15-C1AF34221EED";' ...
    '}' ...
    'var b = result + errorDetails;' ...
    'b;'];

% psresult = psjavascriptu(pstext);
fprintf(fid_in, pstext);

% lo = strfind(psresult, '8F6AFB7E-EC1F-4b6f-AD15-C1AF34221EED');
% 
% if isempty(lo)
%     n = psresult;
% else
%     error(psresult(length('8F6AFB7E-EC1F-4b6f-AD15-C1AF34221EED') + 1:end));
% end



end

