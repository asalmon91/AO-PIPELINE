function dsin = process_grids(fringe_ffname, hv, dsin)


%% Constants
DC_FILT_RAD_PX  = 50;
FRINGE_T_FRAC   = 0.75;

%% Read avi
vr          = VideoReader(fringe_ffname);
n_frames    = round(vr.FrameRate * vr.Duration);

% adding frames
imgs = zeros(vr.Height, vr.Width, n_frames);
for ii=1:n_frames
    imgs(:,:,ii) = im2double(readFrame(vr));
end
mean_frame = mean(imgs, 3);
clear imgs;

% Determine which direction to average
switch hv
    case 'h'
        avg_dim = 2;
    case 'v'
        avg_dim = 1;
end

% Averaging fringes along the proper dimension
fringes = mean(mean_frame, avg_dim);
if ~iscolumn(fringes)
    fringes = fringes';
end
fringe_len_px = numel(fringes);

%% Coarse estimation of the fringe period
% calculating the normalized 1D spectrum along the column dimension
fringes_spectrum = abs(ifftshift(fft(fftshift(fringes))));
% normalized_fringes_spectrum = fringes_spectrum/max(fringes_spectrum);

% creating frequency vector (this works for even and odd # of pixels)
if (rem(fringe_len_px, 2) == 0)
    freq_shift = (fringe_len_px)/2;
else
    freq_shift = (fringe_len_px +1)/2;
end

% the units are cycles/pixel
freq_vec_cyc_per_px = ((0:fringe_len_px -1)' - freq_shift)/fringe_len_px;

% creating DC-removal (binary) mask
DC_mask = (freq_vec_cyc_per_px > 1/DC_FILT_RAD_PX);

% estimating fringe frequency as the high-pass filtered spectrum maximum
[~, max_index]  = max(fringes_spectrum .* DC_mask);
frequency_maximum       = freq_vec_cyc_per_px(max_index);
fringes_period          = 1 / frequency_maximum;

%% Display
% estimating the fringe period uncertainty
% fringes_period_uncertainty  = 1 / frequency_maximum^2 * (freq_vec_cyc_per_px(2)-freq_vec_cyc_per_px(1))/2;

% generating DC-removal mask (only for display in the plot with log axis)
% DC_high_pass_filter         = (abs(freq_vec_cyc_per_px) <  1/DC_FILT_RAD_PX) + ...
%                               (abs(freq_vec_cyc_per_px) >= 1/DC_FILT_RAD_PX) * ...
%                                min(normalized_fringes_spectrum);

% Keep for troubleshooting
% displaying the spectrum, the DC filter and the estimated fringe frequency
% axes(handles.h_fringes_spectrum_display_tag);
% semilogy(freq_vec_cyc_per_px,  normalized_fringes_spectrum,            'b',...
%          freq_vec_cyc_per_px,  DC_high_pass_filter,                    'r')
% hold on
% semilogy(frequency_maximum, normalized_fringes_spectrum(max_index), 'rx',...
%          'markersize', handles.plot_marker_size, 'linewidth', 2) 
% hold off
% axis square, axis tight
% set(gca, 'yticklabel', [])
% title(['1D spectrum (coarse fringes period \approx ' num2str(fringes_period,3)...
%        '\pm ' num2str(fringes_period_uncertainty,1) ' pix)'])
% xlabel('cycles')

% adjusting the plot axes to show only the positive side of the spectrum
% temp_axis                   = axis;
% temp_axis(1)                = 0;
% temp_axis(2)                = 0.5;
% axis(temp_axis)

%% Find minima
% Finding all local minima
is_local_min    = false(size(fringes));
for kk=2:fringe_len_px - 1
    is_local_min(kk) = ...
        fringes(kk) - fringes(kk-1) <= 0 && ...
        fringes(kk+1) - fringes(kk) >= 0;    
end
min_ind = find(is_local_min);

% removing unwanted local minima using the estimated fringe period
% todo: fix fx to work on col vecs
min_ind = remove_local_minima_that_are_too_close(...
    fringes,...
    min_ind',...
    FRINGE_T_FRAC * fringes_period)';

%% Display
% displaying local minima separated by the given fringe period fraction 
% x = 1:fringe_len_px;
% axes(handles.h_fringes_slice_display_tag);
% plot(x, fringes)
% hold on

% notice that we need to keep track of the handle to the plotted markers
% so that we can do the interactive addition/removal of markers by
% responding to mouse clicks on the plot
% handle_to_markers           = plot(x(min_ind), fringes(min_ind), 'rx',...
%                                   'markersize', handles.plot_marker_size, 'linewidth', 2);
% hold off
% grid on
% set(gca, 'ytick', [])
% title('1D fringes average')
% xlabel('pixels')

% adjusting axis limits so that the curve is not against the top and bottom edges
% axis([min(x), max(x), min(fringes) ...
%       - 0.05 * max(fringes), 1.05 * max(fringes)])

%% Estimating linear/sinudoidal fit
switch hv    
    case 'h'
        % performing the fit
        [slope, intercept] = perform_linear_fit(min_ind);
        % replacing the coarse DFT fringe period estimation with the more
        % accurate least-squares estimation
        dsin.horizontal_fringes_fringes_period = 1/slope;
        
        %% Add data for record-keeping
        % Video data
        dsin.horizontal_fringes_n_frames                    = n_frames;
        dsin.horizontal_fringes_n_rows                      = vr.Height;
        dsin.horizontal_fringes_n_columns                   = vr.Width;
        dsin.horizontal_fringes_frame_range                 = 1:n_frames;
        dsin.horizontal_fringes_average_frame               = mean_frame;
        % FFT data
        dsin.horizontal_fringes_DC_filter_radius_in_pixels  = DC_FILT_RAD_PX;
        dsin.horizontal_fringes_fringe_period_fraction      = FRINGE_T_FRAC;
        dsin.horizontal_fringes_indices_minima              = min_ind;
        % Fit data
        dsin.horizontal_fringes_slope       = slope;
        dsin.horizontal_fringes_intercept   = intercept;
        
    case 'v'
        % performing the fit
        [sin_amp, sin_n, sin_phi, sin_b] = perform_sinusoidal_fit(min_ind);

        %% Add data for record-keeping
        % Video data
        dsin.vertical_fringes_n_frames                      = n_frames;
        dsin.vertical_fringes_n_rows                        = vr.Height;
        dsin.vertical_fringes_n_columns                     = vr.Width;
        dsin.vertical_fringes_frame_range                   = 1:n_frames;
        dsin.vertical_fringes_average_frame                 = mean_frame;  
        % FFT data
        dsin.vertical_fringes_DC_filter_radius_in_pixels    = DC_FILT_RAD_PX;
        dsin.vertical_fringes_fringe_period_fraction        = FRINGE_T_FRAC;
        dsin.vertical_fringes_indices_minima                = min_ind;
        % Fit data
        dsin.vertical_fringes_sinusoid_amplitude            = sin_amp;
        dsin.vertical_fringes_sinusoid_n_samples            = sin_n;
        dsin.vertical_fringes_sinusoid_phase                = sin_phi;
        dsin.vertical_fringes_sinusoid_offset               = sin_b;    
        dsin.vertical_fringes_fringes_period                = fringes_period;
end
end





