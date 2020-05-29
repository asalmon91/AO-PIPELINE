function [amp, t, phi, b] = fit_semi_sinusoid(t_vec, min_ind)

% As a starting point for the fit we assume we are dealing with a semi-cycle 
initial_sinusoid_amplitude    = max(t_vec)-min(t_vec)/2;
initial_sinusoid_n_samples    = 2 * (max(min_ind) - min(min_ind));
initial_sinusoid_phase        = -pi/2;
initial_sinusoid_offset       = mean(t_vec);
boolean_display_while_fitting = false;

% performing the fit
warning off
coefficients_fit = fminsearch('SLO_sinusouidal_fit_aux_function', ...
    [initial_sinusoid_amplitude, ...
    initial_sinusoid_n_samples, ...
    initial_sinusoid_phase,...
    initial_sinusoid_offset], ...
    optimset('MaxFunEvals',1000),...
    t_vec,...
    min_ind,...
    boolean_display_while_fitting);
warning on

amp = coefficients_fit(1);
t   = coefficients_fit(2);
phi = coefficients_fit(3);
b   = coefficients_fit(4);

end

