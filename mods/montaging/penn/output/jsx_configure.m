function fid_in = jsx_configure(fid_in)
%jsx_configure writes instructions to a .jsx to configure a photoshop document with recommended settings
%	See psconfig for more details
%   Thomas Ruark, 2/3/2006
%   Copyright 2012 Adobe Systems Incorporated
%	Adapted by Alex Salmon - 2020.06.27

%% Constants
r = 'pixels';	% ruler units
t = 'pixels';	% type units
n = 10;			% number of history states
d = 'no';		% dialogue mode (no = no dialogue boxes)

%% Build javascript instructions
pstext = ['try { '...
    'var result = "";' ...
    'var errorDetails = "";' ...
    'var a = [ app.preferences.rulerUnits.toString(),' ...
    'app.preferences.typeUnits.toString(),' ...
    'app.preferences.numberOfHistoryStates.toString(),' ...
    'app.displayDialogs.toString() ];'];

% Units. { CM INCHES MM PERCENT PICAS PIXELS POINTS }
if exist('r', 'var')
    r = upper(r);
    pstext = [pstext 'app.preferences.rulerUnits = Units.' r ';'];
end

% TypeUnits. { MM PIXELS POINTS }
if exist('t', 'var')
    t = upper(t);
    pstext = [pstext 'app.preferences.typeUnits = TypeUnits.' t ';'];
end

% ( 1 - 100 )
if exist('n', 'var')
    pstext = [pstext 'app.preferences.numberOfHistoryStates = ' num2str(n) ';'];
end

% DialogModes. { ALL ERROR NO }
if exist('d', 'var')
    d = upper(d);
    pstext = [pstext 'app.displayDialogs = DialogModes.' d ';'];
end

pstext = [pstext '} catch(e) {' ...
    '    errorDetails = e.toString();' ...
    '    result = "8F6AFB7E-EC1F-4b6f-AD15-C1AF34221EED";' ...
    '}'];

pstext = [pstext 'if ( result != "8F6AFB7E-EC1F-4b6f-AD15-C1AF34221EED" ) {'...
    '    result = a;' ...
    '} else {' ...
    '    result = [result, errorDetails];' ...
    '}' ...
    'result = result.toSource();' ...
    'result = result.replace("[", "{");' ...
    'result = result.replace("]", "}");' ...
    'result = result.replace("TypeUnits.", "");' ...
    'result = result.replace("Units.", "");' ...
    'result = result.replace("DialogModes.", "");' ...
    'result = result.replace(/\"/g, String.fromCharCode(39));' ...
    'result;'];

%% Write instructions to file
fprintf(fid_in, pstext);

end

