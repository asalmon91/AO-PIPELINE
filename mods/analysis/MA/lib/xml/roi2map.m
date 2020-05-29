function docNode = roi2map(fovea_xy, rois, ma_ver)
%roi2map Converts an roi object to an xml doc object
%   currently supports Mosaic versions 0.4-0.5

%% Constants
% Headers
MAP_HEAD    = 'MAPattern';
REF_HEAD    = 'reference';
ROIS_HEAD   = 'rois';
ROI_HEAD    = 'roi';
NAME_HEAD   = 'name';
TYPE_HEAD   = 'type';
SCALE_HEAD  = 'scalingType';
REGION_HEAD = 'regionType';
COLOR_HEAD  = 'color';
BOUNDS_HEAD = 'bounds';
XY_HEAD     = {'x','y'};
XYWH_HEAD   = {'x','y', 'width', 'height'};
% Formats
NUM_FMT = '%0.8f';

%% Construct the document
docNode = com.mathworks.xml.XMLUtils.createDocument(MAP_HEAD);
% map_xml = docNode.createElement(MAP_HEAD);

%% Create a reference point child
ref_xml = docNode.createElement(REF_HEAD);
% Add coordinates
for ii=1:numel(XY_HEAD)
    ref_xy = docNode.createElement(XY_HEAD{ii});
    ref_xy.appendChild(docNode.createTextNode(...
        sprintf(NUM_FMT, fovea_xy(ii))));
    ref_xml.appendChild(ref_xy);
end
% Append to document
docNode.getDocumentElement.appendChild(ref_xml);

%% Create ROIs container
rois_xml = docNode.createElement(ROIS_HEAD);

%% Construct ROIs
% todo: this could probably be simplified if I had a lookup table of
% parameters and formats. Low priority.
roi_name = 0;
for ii=1:numel(rois)
    if ~rois(ii).success
        continue;
    end
    roi_xml = docNode.createElement(ROI_HEAD);
    
    % Name
    roi_name = roi_name+1;
    name_xml = docNode.createElement(NAME_HEAD);
    name_xml.appendChild(docNode.createTextNode(...
        sprintf('%i', roi_name)));
    roi_xml.appendChild(name_xml);
    
    switch ma_ver
        case 0.4
            % Type
            type_xml = docNode.createElement(TYPE_HEAD);
            type_xml.appendChild(docNode.createTextNode(...
                'Rectangular Fixed')); % todo: support more ROI types
            roi_xml.appendChild(type_xml);
            
        case 0.5
            % Scaling type
            type_xml = docNode.createElement(SCALE_HEAD);
            type_xml.appendChild(docNode.createTextNode(...
                'Fixed')); % todo: support more scaling types
            roi_xml.appendChild(type_xml);
            
            % Region type
            type_xml = docNode.createElement(REGION_HEAD);
            type_xml.appendChild(docNode.createTextNode(...
                'Rectangular')); % todo: support more region types
            roi_xml.appendChild(type_xml);
    end
    
    % Color
    color_xml = docNode.createElement(COLOR_HEAD);
    color_xml.appendChild(docNode.createTextNode(...
        '-65536')); % todo: support more colors
    roi_xml.appendChild(color_xml);
    
    % Bounds container
    bounds_xml = docNode.createElement(BOUNDS_HEAD);
    
    % Bounds values
    for jj=1:numel(XYWH_HEAD)
        roi_xy = docNode.createElement(XYWH_HEAD{jj});
        roi_xy.appendChild(docNode.createTextNode(...
            sprintf(NUM_FMT, rois(ii).xywh(jj))));
        bounds_xml.appendChild(roi_xy);
    end
    roi_xml.appendChild(bounds_xml);
    
    % Append to rois container
    rois_xml.appendChild(roi_xml);
end
% Append rois container to MApattern
docNode.getDocumentElement.appendChild(rois_xml);

% % DEV/DB
% map_char = xmlwrite(docNode);
% % END DEV/DB


end

