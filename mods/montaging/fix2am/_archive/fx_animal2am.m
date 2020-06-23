function [pos_ffnames, ok] = fx_animal2am(xl_ffname, penn_ucl, dsins, ...
    sub_id, date_tag, eye_tag)
%fx_fix2am converts fixation gui output to automontager input

% todo: make dsins optional input arg
% this is only required for the Penn automontager

%% Read, process file
[xl_path, xl_name, xl_ext] = fileparts(xl_ffname);
xl_fname = [xl_name, xl_ext];
loc_data = processLocFile(xl_path, xl_fname);

if strcmpi(penn_ucl, 'both')
    pos_ffnames = cell(2, 1);
    ok = false(2, 1);
else
    pos_ffnames = cell(1);
end

%% Format data and output
if strcmpi(penn_ucl, 'Penn') || strcmpi(penn_ucl, 'Both')
    % Choose template
    template_fname = 'penn.xlsx';
    
    % Construct fringe table
    fringe_tbl = zeros(numel(dsins), 2);
    for ii=1:numel(dsins)
        fringe_tbl(ii, 1) = dsins(ii).lut.fov;
        fringe_tbl(ii, 2) = dsins(ii).lut.fringe;
    end
    
    % Generate position file data
    posfile = getPennPosFile(loc_data, fringe_tbl);
    
    % Format file name
    out_fname = sprintf('pf_v1_%s_%s_%s_Penn.xlsx', ...
        sub_id, ...
        strjoin(strsplit(date_tag, '_')), ...
        eye_tag);
    
    % Write data
    penn_ok = writePosFile(...
        xl_path, out_fname, posfile, template_fname);
    
    % Format output variable
    pos_ffnames{1} = fullfile(xl_path, out_fname);
end
if strcmpi(penn_ucl, 'UCL') || strcmpi(penn_ucl, 'Both')
    % Choose template
    template_fname = 'ucl.xlsx';
    
    % Generate position file data
    posfile = getUclPosFile(loc_data);
    
    % Format file name
    out_fname = sprintf('pf_v1_%s_%s_%s_UCL.xlsx', ...
        sub_id, ...
        strjoin(strsplit(date_tag, '_')), ...
        eye_tag);
    
    % Write data
    ucl_ok = writePosFile(...
        xl_path, out_fname, posfile, template_fname);  
    
    % Format output variable
    pos_index = 1;
    if strcmpi(penn_ucl, 'both')
        pos_index = 2;
        
    end
    pos_ffnames{pos_index} = fullfile(xl_path, out_fname);
end

% Report errors
% todo: find a better way to do this
if strcmpi(penn_ucl, 'both')
    ok = [penn_ok; ucl_ok];
elseif strcmpi(penn_ucl, 'penn')
    ok = penn_ok;
elseif strcmpi(penn_ucl, 'ucl')
    ok = ucl_ok;
end



end

