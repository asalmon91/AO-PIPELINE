function checkFutureError(parfeval_future_object)
%checkFutureError Simple error handler for parfeval future objects
%   We just want to be notified of the error message

if ~isempty(parfeval_future_object.Error)
    error(parfeval_future_object.Error);
end

end

