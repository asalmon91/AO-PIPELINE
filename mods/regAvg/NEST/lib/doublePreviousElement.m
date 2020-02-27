function doubled_array = doublePreviousElement(start_num, end_num)
%doublePreviousElement returns an array that starts at start_num, then each
%successive element is 2x the previous element, until end_num is exceeded.
%end_num is always the last element of the array

y = ceil(log2(end_num/start_num))+1;
doubled_array = ones(y,1).*start_num;
for ii=2:y-1
    doubled_array(ii) = 2*doubled_array(ii-1);
end
doubled_array(end) = end_num;

end

