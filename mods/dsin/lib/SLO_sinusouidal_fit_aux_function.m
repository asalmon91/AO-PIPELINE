% SLO_sinusouidal_fit_aux_function is an auxiliary function used for a
%           least square fit of a sine curve using images from a Ronchi
%           ruling captured with an AOSLO with a resonant scanner.

function fit_error = SLO_sinusouidal_fit_aux_function(coefficients, ...
                                                      minima_time_vector,...
                                                      minima_indices_vector,...
                                                      boolean_display_while_fitting)

% sorting the input parameters
oscillation_amplitude   = coefficients(1);
oscillation_n_samples   = coefficients(2);
oscillation_phase       = coefficients(3);
oscillation_offset      = coefficients(4);

% calculating and returning actual fitting error estimation
fit_time_vector         = oscillation_amplitude * sin( 2 * pi / oscillation_n_samples ...
                        * minima_indices_vector + oscillation_phase) + oscillation_offset;

fit_error               = sqrt(sum((minima_time_vector - fit_time_vector).^2));

% displaying the current fitting against the data
if boolean_display_while_fitting,
    
    figure(123), clf
    set(gcf,'NumberTitle','off')
    plot(minima_time_vector, minima_indices_vector,     'rx',...
         oscillation_amplitude*sin(2*pi/oscillation_n_samples * minima_indices_vector +...
         oscillation_phase) + oscillation_offset, minima_indices_vector,'b-')
    axis square
    axis([min(minima_time_vector), max(minima_time_vector),...
          min(minima_indices_vector),  max(minima_indices_vector)])
    
    % adding current parameters to the plot
    line_1 = ['Oscillation amplitude   = ' num2str(oscillation_amplitude)];
    line_2 = ['Oscillation N_{samples} = ' num2str(oscillation_n_samples)];
    line_3 = ['Oscillation phase       = ' num2str(oscillation_phase)];
    line_4 = ['Oscillation offset      = ' num2str(oscillation_offset)];
    line_5 = ['Fitting error           = ' num2str(fit_error)];
    text_x = min(minima_time_vector) + 0.05*(max(minima_time_vector)    - min(minima_time_vector));
    text_y = max(minima_indices_vector)   - 0.15*(max(minima_indices_vector) - min(minima_indices_vector));    
    text(text_x,text_y, {line_1; line_2; line_3; line_4; line_5}, 'fontsize',8)
    
    ylabel('minima position (pixels)')
    xlabel('time (pixels)')
    
    drawnow
end

