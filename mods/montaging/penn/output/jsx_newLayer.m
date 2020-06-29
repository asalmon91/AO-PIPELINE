function fid_in = jsx_newLayer(fid_in, n)
%jsx_newLayer creates a new layer in photoshop
% See psnewlayer for more details
%
%   Thomas Ruark, 2/3/2006
%   Copyright 2012 Adobe Systems Incorporated
%	Alex Salmon - 2020.06.27 - Modified to write to file

%% Build the JavaScript
pstext = 'try { var result = "";';
pstext = [pstext 'app.activeDocument.artLayers.add();'];

% footer start, wrap in try catch block
pstext = [pstext ' result = "OK";'];
pstext = [pstext '}'];
pstext = [pstext 'catch(e) { result = e.toString(); } '];
pstext = [pstext 'result;'];
% footer end, wrap in try catch block

% psresult = psjavascriptu(pstext);
fprintf(fid_in, pstext);

% if ~strcmp(psresult, 'OK')
%     error(psresult);
% end

if exist('n', 'var')
    pstext = 'try { var result = "";';
    pstext = [pstext 'app.activeDocument.activeLayer.name = "' n '";'];

    % footer start, wrap in try catch block
    pstext = [pstext ' result = "OK";'];
    pstext = [pstext '}'];
    pstext = [pstext 'catch(e) { result = e.toString(); } '];
    pstext = [pstext 'result;'];
    % footer end, wrap in try catch block

%     psresult = psjavascriptu(pstext);
% 
%     if ~strcmp(psresult, 'OK')
%         error(psresult);
%     end

	%% Write to file
	fprintf(fid_in, pstext);
end




