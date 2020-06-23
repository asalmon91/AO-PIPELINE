function [amp, t, phi, b] = perform_sinusoidal_fit(indices_minima)
      

% performing the fitting
n_minima            = length(indices_minima);
minima_t_vec        = (1:n_minima)';
[amp, t, phi, b]    = fit_semi_sinusoid(minima_t_vec, indices_minima);                               

%% Display
% %evaluating the fitting parameters and the fitting uncertainty
% fit_time_vector              = amp * sin(2 * pi / t * ...
%                                indices_minima + phi) + b;
% 
% relative_fitting_uncertainty = sqrt(sum((minima_time_vector - fit_time_vector).^2))/ ...
%                                sqrt(sum((minima_time_vector).^2));
% 
% % displaying fitted sinusoid
% axes(sinusoidal_fit_axes)
% 
% plot(indices_minima, minima_time_vector, 'rx', 'markersize', marker_size, 'linewidth', 2)
% hold on
% plot(indices_minima, fit_time_vector,'b-')
% hold off
% axis square
% temp = [minima_time_vector, fit_time_vector];
% axis([min(indices_minima),  max(indices_minima), min(temp), max(temp)])
% 
% % adding current parameters to the plot
% line_0                       = ['x = {\itA} sin(2\pi t / N + \phi) + {\itB}'];
% line_1                       = ['{\itA}  = ' num2str(amp)];
% line_2                       = ['N  = '      num2str(t)];
% line_3                       = ['\phi = '  num2str(phi)];
% line_4                       = ['{\itB}  = ' num2str(b)];
% line_5                       = ['\epsilon   = ' num2str(100*relative_fitting_uncertainty,2) '%'];
% text_x                       = min(indices_minima) + 0.07*(max(indices_minima) - min(indices_minima));
% text_y                       = max(temp)           - 0.29 *(max(temp)           - min(temp));
% text(text_x,text_y, {line_0; line_1; line_2; line_3; line_4; line_5} ,'fontsize', get(gca,'fontsize'))
% ylabel('{\itx}_{minima} (a.u.)')
% xlabel('{\itt}_{minima} (a.u.)')

end 
 