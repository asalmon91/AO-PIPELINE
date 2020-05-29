function loc_data = readFixGuiFile(in_ffname)
%readFixGuiFile reads the .csv output by the fixation GUI without using
%excel

%% Determine current size of file for preallocation
fid = fopen(in_ffname, 'r');
loc_data = '';
n_rows = 0;
while all(ischar(loc_data))
    try
        loc_data = fgetl(fid);
    catch
        fclose(fid);
        error('Failed to read fixation gui file');
    end
    n_rows = n_rows+1;
end
fclose(fid);

%% Check if empty
if n_rows < 3
    loc_data = [];
    return;
end

%% Re-read and store the data this time
fid = fopen(in_ffname, 'r');
head = strsplit(fgetl(fid), ',');
loc_data = cell(n_rows-1, numel(head));
loc_data(1, :) = head;
for ii=2:n_rows-1
    try
        loc_data(ii,:) = strsplit(fgetl(fid), ',');
        % Also have to convert some to numbers
        for jj=1:numel(head)
            num_val = str2double(loc_data{ii, jj});
            if ~isnan(num_val)
                loc_data{ii, jj} = num_val;
            end
        end
    catch
        fclose(fid);
        error('Failed to read fixation gui file');
    end
end
fclose(fid);

end

