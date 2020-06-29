function fid_in = jsx_initDoc(fid_in, h, w, r, n, m)
%jsx_initDoc writes instructions to create a new document in photoshop
% See psnewdoc for more details
%
%   Thomas Ruark, 3/29/2006
%   Copyright 2012 Adobe Systems Incorporated
%	Adapted by Alex Salmon - 2020.06.27

%% Build up the JavaScript
pstext = 'try { var result = "";';
pstext = [pstext 'documents.add('];

if exist('w', 'var')
    if isnumeric(w)
        w = num2str(w);
    end
    pstext = [pstext w ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('h', 'var')
    if isnumeric(h)
        h = num2str(h);
    end
    pstext = [pstext h ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('r', 'var')
    if isnumeric(r)
        r = num2str(r);
    end
    pstext = [pstext r ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('n', 'var')
    if ~strcmp(n, 'undefined')
        pstext = [pstext '"' n '", '];
    else
        pstext = [pstext 'undefined, '];
    end
else
    pstext = [pstext 'undefined, '];
end

if exist('m', 'var')
    pstext = [pstext 'NewDocumentMode.' upper(m) ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('f', 'var')
    pstext = [pstext 'DocumentFill.' upper(f) ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('a', 'var')
    pstext = [pstext num2str(a) ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('b', 'var')
    if ~isnumeric(b)
        b = str2num(b);
    end
    if b == 1
        b = 'ONE';
    elseif b == 16
        b = 'SIXTEEN';
    elseif b == 32
        b = 'THIRTYTWO';
    else
        b = 'EIGHT';
    end
    pstext = [pstext 'BitsPerChannelType.' b ', '];
else
    pstext = [pstext 'undefined, '];
end

if exist('p', 'var')
    if ~strcmp(n, 'undefined')
        pstext = [pstext '"' p '", '];
    else
        pstext = [pstext 'undefined, '];
    end
end

pstext = [pstext ');'];

% footer start, wrap in try catch block
pstext = [pstext ' result = "OK";'];
pstext = [pstext '}'];
pstext = [pstext 'catch(e) { result = e.toString(); } '];
pstext = [pstext 'result;'];
% footer end, wrap in try catch block

% psresult = psjavascriptu(pstext);

%% Write to the .jsx
fprintf(fid_in, pstext);


end

