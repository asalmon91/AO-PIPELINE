function varargout = getModLambdaOrder(varargin)
% GETMODLAMBDAORDER MATLAB code for getModLambdaOrder.fig
%      GETMODLAMBDAORDER, by itself, creates a new GETMODLAMBDAORDER or raises the existing
%      singleton*.
%
%      H = GETMODLAMBDAORDER returns the handle to a new GETMODLAMBDAORDER or the handle to
%      the existing singleton*.
%
%      GETMODLAMBDAORDER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GETMODLAMBDAORDER.M with the given input arguments.
%
%      GETMODLAMBDAORDER('Property','Value',...) creates a new GETMODLAMBDAORDER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before getModLambdaOrder_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to getModLambdaOrder_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help getModLambdaOrder

% Last Modified by GUIDE v2.5 14-Jun-2019 08:44:33

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @getModLambdaOrder_OpeningFcn, ...
                   'gui_OutputFcn',  @getModLambdaOrder_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before getModLambdaOrder is made visible.
function getModLambdaOrder_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to getModLambdaOrder (see VARARGIN)

% Choose default command line output for getModLambdaOrder
% todo: figure out how to actually use the defaultModLambda function to set
% the defaults
handles.output = hObject;
handles.prime_mod = [];
handles.prime_lambda = [];

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes getModLambdaOrder wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = getModLambdaOrder_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.prime_mod;
varargout{2} = handles.prime_lambda;
delete(handles.figure1)



% --- Executes on button press in go_btn.
function [prime_mod, prime_lambda] = go_btn_Callback(hObject, eventdata, handles)
% hObject    handle to go_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uit = get(handles.uit, 'Data');
labels = get(handles.uit, 'columnname');
% remove any rows with empty columns
remove = any(cell2mat(cellfun(@isempty, uit, 'uniformoutput', false)), 2);
remove = remove | ~cell2mat(uit(:, strcmpi(labels, 'use')));
uit(remove,:) = [];
% Extract used modalities and wavelengths
prime_mod = uit(:, strcmpi(labels, 'modality'));
prime_lambda = cell2mat(uit(:, strcmpi(labels, 'wavelength (nm)')));
handles.prime_mod = prime_mod;
handles.prime_lambda = prime_lambda;
guidata(hObject, handles);
figure1_CloseRequestFcn(hObject, eventdata, handles)


% --- Executes on button press in up_btn.
function up_btn_Callback(hObject, eventdata, handles)
% hObject    handle to up_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
reorder(hObject, handles, -1);


% --- Executes on button press in down_btn.
function down_btn_Callback(hObject, eventdata, handles)
% hObject    handle to down_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
reorder(hObject, handles, 1);


% --- Executes when entered data in editable cell(s) in uit.
function uit_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to uit (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
isValidWavelength = @(x) isempty(x) || ...
    ~isempty(str2double(x)) && str2double(x) > 0;
labels = get(handles.uit, 'columnname');
if strcmpi(labels{eventdata.Indices(2)}, 'wavelength (nm)')
    if ~isValidWavelength(eventdata.EditData)
        lambda = eventdata.PreviousData;
        flashError(hObject, handles)
    else
        lambda = str2double(eventdata.EditData);
    end
    handles.uit.Data{eventdata.Indices(1), eventdata.Indices(2)} = lambda;
end
guidata(hObject, handles);


function flashError(hObject, handles)
N_FLASH = 2;
FLASH_T = 0.5;
for ii=1:N_FLASH
    handles.uit.BackgroundColor = [1,0,0];
    pause(FLASH_T/(2*N_FLASH));
    handles.uit.BackgroundColor = [1,1,1];
    pause(FLASH_T/(2*N_FLASH));
end


% --- Executes when selected cell(s) is changed in uit.
function uit_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to uit (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
if ~isempty(eventdata.Indices)
    handles.current_row = eventdata.Indices(1);
    guidata(hObject, handles);
end


function reorder(hObject, handles, idx)
current_table = get(handles.uit, 'Data');
n_channels = size(current_table, 1);
row_idx = handles.current_row;
order = 1:n_channels;
if row_idx + idx <= 0 || row_idx + idx > n_channels
    return;
end
order([row_idx, row_idx+idx]) = [row_idx+idx, row_idx];
updated_table = current_table(order, :);
set(handles.uit, 'Data', updated_table);
handles.current_row = row_idx + idx;
guidata(hObject, handles);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isequal(get(handles.figure1, 'waitstatus'), 'waiting')
    % The GUI is still in UIWAIT, us UIRESUME
    uiresume(handles.figure1);
else
    % The GUI is no longer waiting, just close it
    delete(handles.figure1);
end




