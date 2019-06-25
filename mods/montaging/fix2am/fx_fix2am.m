function [pos_ffnames, loc_data, ok] = fx_fix2am(loc_ffname, loc_type, penn_ucl, dsins, ...
    aviSets, sub_id, date_tag, eye_tag)
%fx_fix2am converts fixation gui output to automontager input

% todo: make dsins optional input arg
% this is only required for the Penn automontager

%% Read, process file
[loc_path, loc_name, loc_ext] = fileparts(loc_ffname);
loc_fname = [loc_name, loc_ext];

switch loc_type
    case 'human'
        loc_data = processLocFile(loc_path, loc_fname);
    case 'animal'
        ver_no = getAnimalImgNoteVersion(loc_fname);
        switch ver_no
            case 3
                sheet_name = 'AO_Img';
            otherwise
                error('Unsupported notes version');
        end
        
        loc_data = processAnimalLocFile(loc_path, loc_fname, ...
            sheet_name, aviSets, eye_tag);
end

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
        strjoin(strsplit(date_tag, '_'), ''), ...
        eye_tag);
    
    % Write data
    penn_ok = writePosFile(...
        loc_path, out_fname, posfile, template_fname);
    
    % Format output variable
    pos_ffnames{1} = fullfile(loc_path, out_fname);
end
if strcmpi(penn_ucl, 'UCL') || strcmpi(penn_ucl, 'Both')
    % Choose template
    template_fname = 'ucl.xlsx';
    
    % Generate position file data
    posfile = getUclPosFile(loc_data);
    
    % Format file name
    out_fname = sprintf('pf_v1_%s_%s_%s_UCL.xlsx', ...
        sub_id, ...
        strjoin(strsplit(date_tag, '_'), ''), ...
        eye_tag);
    
    % Write data
    ucl_ok = writePosFile(...
        loc_path, out_fname, posfile, template_fname);  
    
    % Format output variable
    pos_index = 1;
    if strcmpi(penn_ucl, 'both')
        pos_index = 2;
        
    end
    pos_ffnames{pos_index} = fullfile(loc_path, out_fname);
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

