function [outputArg1,outputArg2] = jsx_setPixels(fid_in, p, c, t, l, b, r)
%jsx_setPixels sets the pixel values for the current layer
%PSSETPIXELS    Set pixel data to the current layer in Photoshop.
%   PSSETPIXELS(P) P is a H-by-W-by-C pixel matrix containing all the active
%   channels (C), the height (H), and width (W) of the document. For an RGB
%   document this would be a H-by-W-by-3 matrix.
%
%   PSSETPIXELS(P, 1) Set the Red channel. P is a H-by-W matrix containing
%   the 'Red' channel data.
%   PSGETPIXELS(P, 'Red') is the same as above.
%
%   PSSETPIXELS(P, 16) Set the transparency channel. P is the H-by-W
%   transparency channel for the given layer. The layer cannot be the
%   background layer. It must be a standard layer. Set the transparency
%   channel data first before setting the actual pixel data.
%
%   C is the channel ID, channel ID can be a string for the name of the
%   channel or a number from the information below:
%             Red=1, Green=2, Blue=3,
%             Cyan=4, Magenta=5, Yellow=6, Black=7,
%             L=8, A=9, B=10,
%             Duotone=11, Index=12, Bitmap=13,
%             ColorSelected=14, ColorProtected=15,
%             Transparency=16, LayerMask=17,
%             InvertedLayerMask=18, SpotColor=20
%
%   PSSETPIXELS(P, 'undefined', 0, 0, 10, 10) P is a 10-by-10-C pixel matrix
%   containing the t left 10-by-10-C square pixel. C is the number of
%   active channels.
%
%   PSSETPIXELS(P, 'Red', 0, 0, 10, 10) P is a 10-by-10 pixel matrix
%   containing the top left 10-by-10 of the Red channel.
%
%   Top, left, bottom, right must all be defined if one is defined. This,
%   for example, is illegal. pssetpixels(pd, 'Red', 22 23);
%
%   The class of the matrix is 'uint8' for 8 bit depth documents, 'uint16'
%   for 16 bit depth documents, and 'double' for 32 bit depth documents.
%   'uint16' bit documents have the range of 0 <-> 32768 and 'double' bit
%   documents have the range of 0 <-> max double value.
%
%   This function only works on normal layers. Rasterize, flatten, or
%   ungroup layers as necessary to perform this function.
%
%   Example:
%   pssetpixels(p);
%   pssetpixels(p, 1);
%   pssetpixels(p, 'Red', 0, 0, 10, 10);
%
%   See also PSGETPIXELS, PSCONFIG, PSCHANNELNAMES, PSSETACTIVECHANNELS,
%   PSNUMCHANNELS

%   Thomas Ruark, 03/05/2012
%   Copyright 2012 Adobe Systems Incorporated
%	Alex Salmon - 2020.06.27 - Modified to write javascript instructions to file. TODO: this is not
%	going to work. This makes a temporary mat file for writing to the active layer. If the matfiles
%	are deleted during the course of running this function, then calling it after the fact won't add
%	any images. We're going to need to look into placing the images from a file.

psmatfile = fullfile(tempdir, 'pspixels.bin');
psmatfile = strrep(psmatfile, '\', '\\');

if exist(psmatfile, 'file')
    delete(psmatfile);
end

if ndims(p) == 3
    h = size(p, 1);
    w = size(p, 2);
    pd = size(p, 3);
elseif ndims(p) == 2
    h = size(p, 1);
    w = size(p, 2);
    pd = 1;
else
    h = 1;
    w = 1;
    pd = 1;
end

[f,msg] = fopen(psmatfile, 'wb');
if f ~= -1
	fwrite(f, 1, 'int32');
	fwrite(f, w, 'int32');
	fwrite(f, h, 'int32');
	fwrite(f, pd, 'int32');

	if isa(p, 'uint8')
		bpp = 1;
	elseif isa(p, 'uint16')
	    bpp = 2;
	else
	    bpp = 4;
	end

	fwrite(f, bpp, 'int32');

	if isa(p, 'uint8')
	    fwrite(f, p);
	elseif isa(p, 'uint16')
	    fwrite(f, p, 'uint16');
	else
	    fwrite(f, p, 'single');
	end

	fclose(f);

	pstext = 'var result = "";';
	pstext = [pstext 'try {'];
	pstext = [pstext 'var wos = $.os.search(/windows/i) != -1;'];
	pstext = [pstext 'if ( LayerKind.NORMAL == activeDocument.activeLayer.kind ) {'];
	pstext = [pstext 'var desc = new ActionDescriptor();'];
	pstext = [pstext 'desc.putString( app.charIDToTypeID( "File" ), "' psmatfile '");'];
	pstext = [pstext 'desc.putEnumerated( app.charIDToTypeID( "Cmd " ), app.charIDToTypeID( "TCmd" ), app.charIDToTypeID( "MatP" ) );'];

	if exist('c', 'var')
	    if isnumeric(c)
	        pstext = [pstext '     desc.putInteger( charIDToTypeID( "Type" ), "' num2str(c) '" );'];
	    elseif ischar(c)
			if ~strcmp(c, 'undefined')
	            pstext = [pstext '     desc.putString( charIDToTypeID( "ChnN" ), "' c '" );'];
			end
		end
	end
	
	if exist('t', 'var') && exist('l', 'var') && exist('b', 'var') && exist('r', 'var')
	    pstext = [pstext 'var rectDesc = new ActionDescriptor();'];
	    pstext = [pstext  sprintf('rectDesc.putInteger( app.charIDToTypeID( "Top " ), %d);', t)];
	    pstext = [pstext  sprintf('rectDesc.putInteger( app.charIDToTypeID( "Left" ), %d);', l)];
	    pstext = [pstext  sprintf('rectDesc.putInteger( app.charIDToTypeID( "Btom" ), %d);', b)];
	    pstext = [pstext  sprintf('rectDesc.putInteger( app.charIDToTypeID( "Rght" ), %d);', r)];
	    pstext = [pstext 'desc.putObject( app.charIDToTypeID( "T   " ),  app.charIDToTypeID( "Type" ), rectDesc );'];
	end
	
	pstext = [pstext 'result = app.executeAction( stringIDToTypeID( "733B7310-9259-48fd-8A07-24CF7521590D" ), desc, DialogModes.NO );'];
	pstext = [pstext 'var rslt = app.charIDToTypeID( "Rslt" );'];
	pstext = [pstext 'if ( result.hasKey( rslt ) ) {'];
	pstext = [pstext '    var needOK = result.getEnumerationValue( rslt );'];
	pstext = [pstext '    if ( needOK == app.charIDToTypeID( "OK  " ) )'];
	pstext = [pstext '         result = "OK";'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoCd" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoCommand=No command found" ) : localize( "$$$/private/JavaScripts/MATLAB/NoCommand/mac=No command found" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoPt" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoPointer=No pointer found" ) : localize( "$$$/private/JavaScripts/MATLAB/NoPointer/mac=No pointer found" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoTo" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoTo=No target found" ) : localize( "$$$/private/JavaScripts/MATLAB/NoTo/mac=No target found" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoTC" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoTargetChannel=No target channel" ) : localize( "$$$/private/JavaScripts/MATLAB/NoTargetChannel/mac=No target channel" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "Unsp" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/Unsupported=Unsupported configuration" ) : localize( "$$$/private/JavaScripts/MATLAB/Unsupported/mac=Unsupported configuration" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "memF" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/MemoryFull=Memory full" ) : localize( "$$$/private/JavaScripts/MATLAB/MemoryFull/mac=Memory full" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "Dmsm" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/DataMismatch=Data mismatch" ) : localize( "$$$/private/JavaScripts/MATLAB/DataMismatch/mac=Data mismatch" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "Dpms" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/DepthMismatch=Depth mismatch" ) : localize( "$$$/private/JavaScripts/MATLAB/DepthMismatch/mac=Depth mismatch" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "Pmsm" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/PlanesMismatch=Planes Mismatch" ) : localize( "$$$/private/JavaScripts/MATLAB/PlanesMismatch/mac=Planes Mismatch" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "Bmsm" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/BoundsMismatch=Bounds Mismatch" ) : localize( "$$$/private/JavaScripts/MATLAB/BoundsMismatch/mac=Bounds Mismatch" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoMt" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoMatFile=No Mat File" ) : localize( "$$$/private/JavaScripts/MATLAB/NoMatFile/mac=No Mat File" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "PSEr" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/PhotoshopError=Photoshop Error" ) : localize( "$$$/private/JavaScripts/MATLAB/PhotoshopError/mac=Photoshop Error" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "NoCd" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/NoCommand=No command found" ) : localize( "$$$/private/JavaScripts/MATLAB/NoCommand/mac=No command found" );'];
	pstext = [pstext '    else if ( needOK == app.charIDToTypeID( "FtNo" ) )'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/FeatureDisabled=MATLAB feature is not enabled" ) : localize( "$$$/private/JavaScripts/MATLAB/FeatureDisabled/mac=MATLAB feature is not enabled" );'];
	pstext = [pstext '    else'];
	pstext = [pstext '         result = wos ? localize( "$$$/JavaScripts/MATLAB/Unknown=Unknown error occured" ) : localize( "$$$/private/JavaScripts/MATLAB/Unknown/mac=Unknown error occured" );'];
	pstext = [pstext '}'];
	pstext = [pstext '} else {']; % this is the if LayerKind.NORMAL
	pstext = [pstext '  result = wos ? localize( "$$$/JavaScripts/MATLAB/LayerNeedsNormal=Layer needs to be a NORMAL layer: " ) : localize( "$$$/private/JavaScripts/MATLAB/LayerNeedsNormal/mac=Layer needs to be a NORMAL layer: " );'];
	pstext = [pstext '  result = result + activeDocument.activeLayer.kind;'];
	pstext = [pstext '}']; % end of if LayerKind.NORMAL
	pstext = [pstext '}']; % this is the try/catch ender
	pstext = [pstext 'catch(e) {'];
	pstext = [pstext '    result = e.toString();'];
	pstext = [pstext '}'];
	pstext = [pstext 'result;'];
	
	psresult = psjavascriptu(pstext);
	
	delete(psmatfile);
	
	if ~strcmp(psresult, 'OK')
	    error(psresult);
	end
else
	error(msg);
end

end

