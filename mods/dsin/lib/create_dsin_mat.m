function [dsin, out_fname] = create_dsin_mat(dsin, lpmm)

%% Constants
% # px to drop on each side to account for the finite number of samples 
% used for the sinc interpolation formula
N_EDGE_PX_DROP = 16;

% getting desinusoid data from structure
% warped_frame            = dsin.vertical_fringes_average_frame;
n_samples_experimental  = dsin.vertical_fringes_n_columns;
% n_warped_lines          = dsin.vertical_fringes_n_rows;
sin_amp                 = dsin.vertical_fringes_sinusoid_amplitude;
sin_n                   = dsin.vertical_fringes_sinusoid_n_samples;
sin_phi                 = dsin.vertical_fringes_sinusoid_phase;
sin_b                   = dsin.vertical_fringes_sinusoid_offset;
% fringe_period_fraction  = dsin.vertical_fringes_fringe_period_fraction;
other_fringes_period    = dsin.horizontal_fringes_fringes_period;
horizontal_warping      = 1;

% Keep for future application where resonant scanner is vertical
% else
%     warped_frame               = dsin.horizontal_fringes_average_frame;
%     n_samples_experimental     = dsin.horizontal_fringes_n_rows;
%     n_warped_lines             = dsin.horizontal_fringes_n_columns;
%     sin_amp         = dsin.horizontal_fringes_sinusoid_amplitude;
%     sin_n         = dsin.horizontal_fringes_sinusoid_n_samples;
%     sin_phi             = dsin.horizontal_fringes_sinusoid_phase;
%     sin_b            = dsin.horizontal_fringes_sinusoid_offset;
%     fringe_period_fraction     = dsin.horizontal_fringes_fringe_period_fraction;
%     other_fringes_period       = dsin.vertical_fringes_fringes_period;
%     horizontal_warping         = 0;
% end

%% Generate desinusoid matrix
% In what follows x represents the spatial coordinate of the pixels
% recorded at a time t.

% calculating the x-values corresponding to (1 + n_edge_pixels_dropped) and
% (n_samples_experimental - n_edge_pixels_dropped). This is to avoid edge
% artifacts in the interpolation
x_min = sin_amp * sin((2 * pi / sin_n) * ...
    (       1       + N_EDGE_PX_DROP) + sin_phi) + sin_b;

x_max = sin_amp * sin((2 * pi / sin_n) *...
    (n_samples_experimental - N_EDGE_PX_DROP) + sin_phi) + sin_b;

%% Make the pixels square
x_calc_px = x_min : 1 / other_fringes_period : x_max;
n_px_calc = length(x_calc_px);

% calculating corresponding pixel times using the sinusoidal fit
t_calc_px = (asin((x_calc_px - sin_b) / ...
    sin_amp) - sin_phi) / (2 * pi / sin_n);

% remember that the experimental pixels were acquired periodically...
t_experimental_px = 1 : n_samples_experimental;

% creating the interpolation matrix using the sinc reconstruction formula
% the eps is for avoiding the discontinuity in the sinc at t = 0
desinusoid_matrix = zeros(...
    n_px_calc, ...
    numel(t_experimental_px));
for t=1:n_px_calc
    desinusoid_matrix(t,:) = ...
        sin(pi * (t_calc_px(t) - t_experimental_px - eps)) ./ ...
        (pi * (t_calc_px(t) - t_experimental_px - eps));
end

%% Display
% displaying desinusoid image and matrix only if the user requests it
% display_desinusoid_matrix = get(handles.view_desinusoid_matrix_tag, 'value');

% if display_desinusoid_matrix
%     % initializing new figure to display calculation outputs
%     figure(2), clf, colormap('pink')
%     set(gcf,'Name',        handles.application_name, ...
%             'NumberTitle', 'off', ...
%             'color',        [1 1 1] * 0.95)
% 
%     % displaying warped average frame
%     subplot(221)
%     imagesc(warped_frame)
%     axis equal, axis tight
%     title('Sinusoidally warped fringes', 'fontweight', 'bold')
% 
%     % keeping axis dimensions so that they can be used for the dewarped image
%     temp_axis                       = axis;
% 
%     % displaying the interpolation matrix
%     subplot(212)
%     imagesc(log(abs(desinusoid_matrix)))
%     axis equal, axis tight
%     xlabel(['experimental pixels ({\itN} = ' num2str(n_samples_experimental) ')'],...
%                                                         'fontweight', 'bold')
%     ylabel(['calculated pixels ({\itN} = '   num2str(n_pixels_calculated) ')'], ...
%                                                         'fontweight', 'bold')
%     title(  'log(|desinusoid matrix|) ',                'fontweight', 'bold')
%     caxis([-6, 0])
% end

%% Desinusoided frame
% if horizontal_warping
%     desinusoided_image          = warped_frame * desinusoid_matrix';
% 
%     % averaging fringes along the columns
% %     averaged_frame_fringes      = mean(desinusoided_image,1); 
% else
%     desinusoided_image          = desinusoid_matrix * warped_frame; %#ok<UNRCH>
% 
%     % averaging fringes along the rows
%     averaged_frame_fringes      = mean(desinusoided_image,2)'; 
% end

% % creating frequency vector
% if (rem(n_px_calc,2) == 0)
%     frequency_shift             = (n_px_calc    )/2;
% else
%     frequency_shift             = (n_px_calc + 1)/2;
% end

% the units are cycles/pixel
% frequency_vector_calculated     = ([0 : n_px_calc - 1] - frequency_shift)/n_px_calc;

% calculating normalized spectrum
% spectrum                        = abs(ifftshift(fft(fftshift(averaged_frame_fringes))));
% normalized_spectrum             = spectrum/max(spectrum);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% coarse estimation of the desinusoided fringes period using the DFT  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% creating DC-removal mask
% DC_mask                        = (frequency_vector_calculated > 1/(2*other_fringes_period));

% estimating the fringe frequency
% [~, max_index]          = max(spectrum .* DC_mask);
% frequency_maximum              = frequency_vector_calculated(max_index);
% new_fringes_period             = 1 / frequency_maximum;    
% new_fringes_period_uncertainty = 1 / frequency_maximum^2 * ...
%                                 (frequency_vector_calculated(2) - frequency_vector_calculated(1))/2;

% if display_desinusoid_matrix
%     % displaying dewarped frame
%     subplot(222)
%     imagesc(desinusoided_image)
%     axis equal, axis tight
%     title('Dewarped fringes', 'fontweight', 'bold')
% end

% adding new data to the structure
if horizontal_warping
    dsin.vertical_fringes_x_calculated_pixels           = x_calc_px;
    dsin.vertical_fringes_t_calculated_pixels           = t_calc_px;
    dsin.vertical_fringes_desinusoid_matrix             = desinusoid_matrix;

else
    dsin.horizontal_fringes_x_calculated_pixels         = x_calc_px;
    dsin.horizontal_fringes_t_calculated_pixels         = t_calc_px;
    dsin.horizontal_fringes_desinusoid_matrix           = desinusoid_matrix;   

end
dsin.horizontal_warping                                 = horizontal_warping; % change made by yusufu sulai on 10/07/14

% creating file name
% lpmm_string     = strrep(sprintf('%3.1f', lpmm),'.','p');
% fov_deg_string  = strrep(sprintf('%3.2f', gridPair.fov),'.','p');

if horizontal_warping
    fringe_period_in_pixels = dsin.horizontal_fringes_fringes_period;
else
    fringe_period_in_pixels = dsin.vertical_fringes_fringes_period;
end
% fringe_period_in_pixels     = strrep(num2str(fringe_period_in_pixels, 5),'.','p');

% if isempty(lpmm_string) || isempty(fov_deg_string) || isempty(fringe_period_in_pixels)
%     errordlg('Make sure that grid lines/mm, wavelength and field of view are correctly entered.',...
%                  'roc_create_desinusoid_matrix_3p3',...
%                  'modal');
%     return
% end

%% Write to file
out_path    = dsin.horizontal_fringes_path;
out_fname   = [strrep(sprintf(...
    'desinusoid_matrix_%inm_%1.2f_deg_%3.1f_lpmm_fringe_%s_pix', ...
    dsin.wl_nm, dsin.fov, dsin.lpmm, ...
    num2str(fringe_period_in_pixels, 5)), ...
    '.', 'p'), ...
    '.mat'];

% todo: include desinusoid file version numbers to assist parsing output
% it would make a lot more sense to just save the variable dsin, rather
% than this dynamic programming stuff

% Initialize string
save_str = 'save(fullfile(out_path, out_fname)';

% Add to string
field_names = fieldnames(dsin);
for field_index = 1:length(field_names)            
    % adding the fields to save to the list
    save_str = [save_str, ', ''', field_names{field_index}, '''']; %#ok<AGROW>

    % flattening the structure by hand
    eval([field_names{field_index} ' = dsin.' field_names{field_index} ';'])
end

% finalizing the string
save_str = strcat(save_str,');');

% evaluating the string
eval(save_str)

end
