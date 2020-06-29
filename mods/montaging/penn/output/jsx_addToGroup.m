function fid_in = jsx_addToGroup(fid_in, name, frombeginning)
%jsx_addToGroup adds a group to another group
%   Robert F Cooper 10-21-2014
%	Alex Salmon - 2020.06.27 - writes to file

%% Check for frombeginning flag
if ~exist('frombeginning', 'var')
    frombeginning = 1;
end

%% Build javascript
script = [ 'function moveToGroupByName(name){'...
''...
'   var i = getNumberLayers();'...
'   if( ' num2str(frombeginning) '== 0 ){'...
'       i = getActiveLayerIndex()-1;'...
'   }'...
'   var res = new Array();'...
'   var prop =  stringIDToTypeID("layerSection");'... 
''...
'   var startingsectiondepth = 0;'...
'   var sectiondepth = 0;'...
'   var visibilitylock = false;'...
''...
'    for(i; i > hasBackground() ; i--){'...
'      var type = getLayerType(i,prop);'...
''...
'       if( type == "layerSectionStart" && getLayerName(i).match( "^"+name +"$" ) ){'...
'                 moveSelectedToGroup(i);'...
'                 break;'... % Kick out at the first one we find, so that it doesn't just keep scrolling downward
'       }'...
''...
'    }'...
'   return res;'...
''...
'   function moveSelectedToGroup(idx){'...
'       var idmove = charIDToTypeID( "move" );'...
'            var desc28 = new ActionDescriptor();'...
'            var idnull = charIDToTypeID( "null" );'...
'                var ref13 = new ActionReference();'...
'                var idLyr = charIDToTypeID( "Lyr " );'...
'                var idOrdn = charIDToTypeID( "Ordn" );'...
'                var idTrgt = charIDToTypeID( "Trgt" );'...
'                ref13.putEnumerated( idLyr, idOrdn, idTrgt );'...
'            desc28.putReference( idnull, ref13 );'...
'            var idT = charIDToTypeID( "T   " );'...
'                var ref14 = new ActionReference();'...
'                var idLyr = charIDToTypeID( "Lyr " );'...
'                ref14.putIndex( idLyr, idx );'...
'            desc28.putReference( idT, ref14 );'...
'            var idAdjs = charIDToTypeID( "Adjs" );'...
'            desc28.putBoolean( idAdjs, false );'...
'            var idVrsn = charIDToTypeID( "Vrsn" );'...
'            desc28.putInteger( idVrsn, 5 );'...
'        executeAction( idmove, desc28, DialogModes.NO );'...
'   }'...
''...
'   function getNumberLayers(){'...
'       var ref = new ActionReference();'...
'       ref.putProperty( charIDToTypeID("Prpr") , charIDToTypeID("NmbL") );'...
'       ref.putEnumerated( charIDToTypeID("Dcmn"), charIDToTypeID("Ordn"), charIDToTypeID("Trgt") );'...
'       return executeActionGet(ref).getInteger(charIDToTypeID("NmbL"));'...
'   }'...
''...
'   function hasBackground() {'...
'       var ref = new ActionReference();'...
'       ref.putProperty( charIDToTypeID("Prpr"), charIDToTypeID( "Bckg" ));'...
'       ref.putEnumerated(charIDToTypeID( "Lyr " ),charIDToTypeID( "Ordn" ),charIDToTypeID( "Back" ));'...
'       var desc =  executeActionGet(ref);'...
'       var res = desc.getBoolean(charIDToTypeID( "Bckg" ));'...
'       if(res){'...
'            return 1;'...
'       }else{'...
'            return 0;'...
'       }'...
'    };'...
''...
'   function getLayerType(idx,prop) {'...
'       var ref = new ActionReference();'...
'       ref.putIndex(charIDToTypeID( "Lyr " ), idx);'...
'       var desc =  executeActionGet(ref);'...
'       var type = desc.getEnumerationValue(prop);'...
'       var res = typeIDToStringID(type);'...
'       return res;'...   
'    };'...
''...
'    function getLayerName(idx){'...
'        var ref = new ActionReference();'...
'        ref.putProperty( charIDToTypeID("Prpr"), charIDToTypeID("Nm  ") );'...
'        ref.putIndex( charIDToTypeID("Lyr "), idx);'...
'        var desc = executeActionGet(ref);'...
'        var res = desc.getString( charIDToTypeID("Nm  ") );'...
'        return res;'...
'    };'...
''...
'    function isVisible( idx ) {'...
'        var ref = new ActionReference();'...
'        ref.putProperty( charIDToTypeID("Prpr") , charIDToTypeID( "Vsbl" ));'...
'        ref.putIndex( charIDToTypeID( "Lyr " ), idx );'...
'        return executeActionGet(ref).getBoolean(charIDToTypeID( "Vsbl" ));'...
'    };'...
'    function getActiveLayerIndex() {  '...
'         var ref = new ActionReference();  '...
'         ref.putProperty( 1349677170 , 1232366921 );  '...
'         ref.putEnumerated( 1283027488, 1332896878, 1416783732 );  '...
'         var res = executeActionGet(ref).getInteger( 1232366921 ) - Number( hasBackground() );  '...
'         res == 4 ? res++:res;  '...
'         return res;     '...
'    }'...
'};'...
'moveToGroupByName("' name '");' ];

% psjavascript(script);

%% Write to file
fprintf(fid_in, script);

end

