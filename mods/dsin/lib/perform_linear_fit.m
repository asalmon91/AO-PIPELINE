function [slope, intercept] = perform_linear_fit(indices_minima)

% performing the fit
n_minima            = length(indices_minima);
minima_time_vector  = (1:n_minima)';
fit_coefficients    = polyfit(indices_minima, minima_time_vector, 1);

% returned values. Note that the inverse of the slope is the fringe period
slope       = fit_coefficients(1);
intercept   = fit_coefficients(2);

%% The rest is for display
% evaluating the fitting parameters and the fitting uncertainty
%     fit_time_vector              = polyval(fit_coefficients, indices_minima);

%     relative_fitting_uncertainty = sqrt(sum((minima_time_vector - fit_time_vector).^2))/ ...
%                                    sqrt(sum((minima_time_vector).^2));

% displaying fitted line
%     axes(linear_fit_axes)
% 
%     plot(indices_minima, minima_time_vector, 'rx', 'markersize', marker_size, 'linewidth', 2)
%     hold on
%     plot(indices_minima, fit_time_vector,'b-')
%     hold off
%     axis square
%     temp = [minima_time_vector, fit_time_vector];
%     axis([min(indices_minima),  max(indices_minima), min(temp), max(temp)])
%     title(['fringe period = ' num2str(1/fit_coefficients(1),7) ' pix'])
% 
%     % adding current parameters to the plot
%     line_0                       = ['{\it t} = {\itA} x + {\itB}'];
%     line_1                       = ['{\itA}  = '    num2str(fit_coefficients(1))];
%     line_2                       = ['{\itB}  = '    num2str(fit_coefficients(2))];
%     line_3                       = ['\epsilon   = ' num2str(100*relative_fitting_uncertainty,2) '%'];
%     text_x                       = min(indices_minima) + 0.07*(max(indices_minima) - min(indices_minima));
%     text_y                       = max(temp)           - 0.19 *(max(temp)           - min(temp));    
%     text(text_x, text_y, {line_0; line_1; line_2; line_3}, 'fontsize', get(gca,'fontsize'))
%     ylabel('{\itx}_{minima} (a.u.)')
%     xlabel('{\itt}_{minima} (a.u.)')

end