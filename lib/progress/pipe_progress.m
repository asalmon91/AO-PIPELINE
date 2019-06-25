function varargout = pipe_progress(varargin)
% PIPE_PROGRESS MATLAB code for pipe_progress.fig
%      PIPE_PROGRESS, by itself, creates a new PIPE_PROGRESS or raises the existing
%      singleton*.
%
%      H = PIPE_PROGRESS returns the handle to a new PIPE_PROGRESS or the handle to
%      the existing singleton*.
%
%      PIPE_PROGRESS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PIPE_PROGRESS.M with the given input arguments.
%
%      PIPE_PROGRESS('Property','Value',...) creates a new PIPE_PROGRESS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before pipe_progress_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to pipe_progress_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help pipe_progress

% Last Modified by GUIDE v2.5 14-Jun-2019 10:30:10

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pipe_progress_OpeningFcn, ...
                   'gui_OutputFcn',  @pipe_progress_OutputFcn, ...
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


% --- Executes just before pipe_progress is made visible.
function pipe_progress_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to pipe_progress (see VARARGIN)

% Choose default command line output for pipe_progress
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes pipe_progress wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = pipe_progress_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
varargout{2} = handles;
