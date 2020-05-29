function indices_minima = remove_local_minima_that_are_too_close(y_samples,...
                                                                 indices_minima,...
                                                                 minimum_minima_separation)
    x_samples             = 1 : length(y_samples);
    current_minimum_index = 1;

    while (current_minimum_index < length(indices_minima)) 

        % whenever two consecutive minima are closer than the minimum separation
        while ((current_minimum_index < length(indices_minima) & ...
              ( x_samples(indices_minima(current_minimum_index + 1)) ...
              - x_samples(indices_minima(current_minimum_index    )) ...
              < minimum_minima_separation)))

             % ...find the one with the lower value...
             if y_samples(indices_minima(current_minimum_index)) ...
             >  y_samples(indices_minima(current_minimum_index + 1))

                % ...and remove the other one
                 if (current_minimum_index == 1)
                     indices_minima = indices_minima(2:end);
                 else
                     indices_minima = [indices_minima(1:current_minimum_index - 1),...
                                       indices_minima(  current_minimum_index + 1 : end)];
                 end
             else             
                 % ...and remove the other one
                 if (current_minimum_index + 1 == length(indices_minima))
                     indices_minima = indices_minima(1:end-1);
                 else
                     indices_minima = [indices_minima(1:current_minimum_index),...
                                       indices_minima(  current_minimum_index+2:end)];
                 end
             end
        end
        current_minimum_index = current_minimum_index + 1;
    end
end

