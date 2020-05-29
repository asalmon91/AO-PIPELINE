function create_n_save_desinusoid_matrix(hObject, eventdata, handles)

% getting the number of pixels to drop on each side to account for the 
% finite number of samples used for the sinc interpolation formula
n_edge_pixels_dropped          = str2double(get(handles.pixels_dropped_at_edges_tag, 'string'));

% getting desinusoid data from structure
if isfield(handles.desinusoid_data, 'vertical_fringes_sinusoid_amplitude')
    warped_frame               = handles.desinusoid_data.vertical_fringes_average_frame;
    n_samples_experimental     = handles.desinusoid_data.vertical_fringes_n_columns;
    n_warped_lines             = handles.desinusoid_data.vertical_fringes_n_rows;
    sinusoid_amplitude         = handles.desinusoid_data.vertical_fringes_sinusoid_amplitude;
    sinusoid_n_samples         = handles.desinusoid_data.vertical_fringes_sinusoid_n_samples;
    sinusoid_phase             = handles.desinusoid_data.vertical_fringes_sinusoid_phase;
    sinusoid_offset            = handles.desinusoid_data.vertical_fringes_sinusoid_offset;
    fringe_period_fraction     = handles.desinusoid_data.vertical_fringes_fringe_period_fraction;
    other_fringes_period       = handles.desinusoid_data.horizontal_fringes_fringes_period;
    horizontal_warping         = 1;
else
    warped_frame               = handles.desinusoid_data.horizontal_fringes_average_frame;
    n_samples_experimental     = handles.desinusoid_data.horizontal_fringes_n_rows;
    n_warped_lines             = handles.desinusoid_data.horizontal_fringes_n_columns;
    sinusoid_amplitude         = handles.desinusoid_data.horizontal_fringes_sinusoid_amplitude;
    sinusoid_n_samples         = handles.desinusoid_data.horizontal_fringes_sinusoid_n_samples;
    sinusoid_phase             = handles.desinusoid_data.horizontal_fringes_sinusoid_phase;
    sinusoid_offset            = handles.desinusoid_data.horizontal_fringes_sinusoid_offset;
    fringe_period_fraction     = handles.desinusoid_data.horizontal_fringes_fringe_period_fraction;
    other_fringes_period       = handles.desinusoid_data.vertical_fringes_fringes_period;
    horizontal_warping         = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    generating desinusoid matrix                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% In what follows x represents the spatial coordinate of the pixels
% recorded at a time t.

% calculating the x-values corresponding to (1 + n_edge_pixels_dropped) and
% (n_samples_experimental - n_edge_pixels_dropped). This is to avoid edge
% artifacts in the interpolation
x_min                        = sinusoid_amplitude * sin((2 * pi / sinusoid_n_samples) *...
                              (       1       + n_edge_pixels_dropped) + sinusoid_phase) + sinusoid_offset;

x_max                        = sinusoid_amplitude * sin((2 * pi / sinusoid_n_samples) *...
                              (n_samples_experimental - n_edge_pixels_dropped) + sinusoid_phase) + sinusoid_offset;

% note the step here will make the pixels square
x_calculated_pixels          = x_min : 1 / other_fringes_period : x_max;                        

n_pixels_calculated          = length(x_calculated_pixels);


% calculating corresponding pixel times using the sinusoidal fit
t_calculated_pixels          = (asin((x_calculated_pixels - sinusoid_offset)...
                               /sinusoid_amplitude) - sinusoid_phase) / (2 * pi / sinusoid_n_samples);

% remember that the experimental pixels were acquired periodically...
t_experimental_pixels        = 1 : n_samples_experimental;

% creating the interpolation matrix using the sinc reconstruction formula
% the eps is for avoiding the discontinuity in the sinc at t = 0
for k = 1 : n_pixels_calculated,
    desinusoid_matrix(k,:)   = sin(pi * (t_calculated_pixels(k) - t_experimental_pixels - eps))...
                                ./(pi * (t_calculated_pixels(k) - t_experimental_pixels - eps));
end

% displaying desinusoid image and matrix only if the user requests it
display_desinusoid_matrix = get(handles.view_desinusoid_matrix_tag, 'value');

if display_desinusoid_matrix
    % initializing new figure to display calculation outputs
    figure(2), clf, colormap('pink')
    set(gcf,'Name',        handles.application_name, ...
            'NumberTitle', 'off', ...
            'color',        [1 1 1] * 0.95)

    % displaying warped average frame
    subplot(221)
    imagesc(warped_frame)
    axis equal, axis tight
    title('Sinusoidally warped fringes', 'fontweight', 'bold')

    % keeping axis dimensions so that they can be used for the dewarped image
    temp_axis                       = axis;

    % displaying the interpolation matrix
    subplot(212)
    imagesc(log(abs(desinusoid_matrix)))
    axis equal, axis tight
    xlabel(['experimental pixels ({\itN} = ' num2str(n_samples_experimental) ')'],...
                                                        'fontweight', 'bold')
    ylabel(['calculated pixels ({\itN} = '   num2str(n_pixels_calculated) ')'], ...
                                                        'fontweight', 'bold')
    title(  'log(|desinusoid matrix|) ',                'fontweight', 'bold')
    caxis([-6, 0])
end

% calculating desinusoided frame
if horizontal_warping
    desinusoided_image          = warped_frame * desinusoid_matrix';

    % averaging fringes along the columns
    averaged_frame_fringes      = mean(desinusoided_image,1); 
else
    desinusoided_image          = desinusoid_matrix * warped_frame;

    % averaging fringes along the rows
    averaged_frame_fringes      = mean(desinusoided_image,2)'; 
end

% creating frequency vector
if (rem(n_pixels_calculated,2) == 0)
    frequency_shift             = (n_pixels_calculated    )/2;
else
    frequency_shift             = (n_pixels_calculated + 1)/2;
end

% the units are cycles/pixel
frequency_vector_calculated     = ([0 : n_pixels_calculated - 1] - frequency_shift)/n_pixels_calculated;

% calculating normalized spectrum
spectrum                        = abs(ifftshift(fft(fftshift(averaged_frame_fringes))));
normalized_spectrum             = spectrum/max(spectrum);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% coarse estimation of the desinusoided fringes period using the DFT  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% creating DC-removal mask
DC_mask                        = (frequency_vector_calculated > 1/(2*other_fringes_period));

% estimating the fringe frequency
[not_used, max_index]          = max(spectrum .* DC_mask);
frequency_maximum              = frequency_vector_calculated(max_index);
new_fringes_period             = 1 / frequency_maximum;    
new_fringes_period_uncertainty = 1 / frequency_maximum^2 * ...
                                (frequency_vector_calculated(2) - frequency_vector_calculated(1))/2;

if display_desinusoid_matrix
    % displaying dewarped frame
    subplot(222)
    imagesc(desinusoided_image)
    axis equal, axis tight
    title('Dewarped fringes', 'fontweight', 'bold')
end

% adding new data to the structure
if horizontal_warping
    handles.desinusoid_data.vertical_fringes_x_calculated_pixels           = x_calculated_pixels;
    handles.desinusoid_data.vertical_fringes_t_calculated_pixels           = t_calculated_pixels;
    handles.desinusoid_data.vertical_fringes_desinusoid_matrix             = desinusoid_matrix;

else
    handles.desinusoid_data.horizontal_fringes_x_calculated_pixels         = x_calculated_pixels;
    handles.desinusoid_data.horizontal_fringes_t_calculated_pixels         = t_calculated_pixels;
    handles.desinusoid_data.horizontal_fringes_desinusoid_matrix           = desinusoid_matrix;   

end
handles.desinusoid_data.horizontal_warping                                 = horizontal_warping; % change made by yusufu sulai on 10/07/14

% creating file name
lines_per_mm_string         = strrep(get(handles.grid_lines_per_mm_for_file_name_tag, 'String'),'.','p');
field_of_view_in_deg_string = strrep(get(handles.horizontal_FOV_for_file_name_tag,    'String'),'.','p');

if horizontal_warping
    fringe_period_in_pixels = handles.desinusoid_data.horizontal_fringes_fringes_period;
else
    fringe_period_in_pixels = handles.desinusoid_data.vertical_fringes_fringes_period;
end
fringe_period_in_pixels     = strrep(num2str(fringe_period_in_pixels, 5),'.','p');

if isempty(lines_per_mm_string) || isempty(field_of_view_in_deg_string) || isempty(fringe_period_in_pixels)
    errordlg('Make sure that grid lines/mm, wavelength and field of view are correctly entered.',...
                 'roc_create_desinusoid_matrix_3p3',...
                 'modal');
    return
end

% saving data   
[filename,path] = uiputfile('*.mat',...
                    'Enter filename for saving dewarp data',...
                    [handles.savedpath,filesep,'desinusoid_matrix_' get(handles.Wavelength_in_nm_for_file_name_tag, 'String'),...
                    'nm_' field_of_view_in_deg_string '_deg_' lines_per_mm_string '_lpmm_fringe_',...
                    fringe_period_in_pixels '_pix.mat']);

if (filename ~= 0)

    % saving MAT file
    field_names = fieldnames(handles.desinusoid_data);

    % initializing the string
    temp_string = 'save([path, filename]';

    for field_index = 1:length(field_names)            
        % adding the fields to save to the list
        temp_string = strcat(temp_string, ', ''', field_names{field_index}, '''');

        % flattening the structure by hand
        eval([field_names{field_index} ' = handles.desinusoid_data.' field_names{field_index} ';'])
    end

    % finalizing the string
    temp_string = strcat(temp_string,');');

    % evaluating the string
    eval(temp_string)            
end
end
