function varargout = montage_display(varargin)
% MONTAGE_DISPLAY MATLAB code for montage_display.fig
%      MONTAGE_DISPLAY, by itself, creates a new MONTAGE_DISPLAY or raises the existing
%      singleton*.
%
%      H = MONTAGE_DISPLAY returns the handle to a new MONTAGE_DISPLAY or the handle to
%      the existing singleton*.
%
%      MONTAGE_DISPLAY('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MONTAGE_DISPLAY.M with the given input arguments.
%
%      MONTAGE_DISPLAY('Property','Value',...) creates a new MONTAGE_DISPLAY or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before montage_display_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to montage_display_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help montage_display

% Last Modified by GUIDE v2.5 27-Jan-2020 10:09:47

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @montage_display_OpeningFcn, ...
                   'gui_OutputFcn',  @montage_display_OutputFcn, ...
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


% --- Executes just before montage_display is made visible.
function montage_display_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to montage_display (see VARARGIN)

% Choose default command line output for montage_display
handles.output = hObject;

% Update modality list
if ~isempty(varargin)
    set(handles.mod_list, 'string', varargin{1});
end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes montage_display wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = montage_display_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = hObject;
varargout{2} = handles;


% --- Executes on selection change in mod_list.
function mod_list_Callback(hObject, eventdata, handles)
% hObject    handle to mod_list (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns mod_list contents as cell array
%        contents{get(hObject,'Value')} returns selected item from mod_list


% --- Executes during object creation, after setting all properties.
function mod_list_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mod_list (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
