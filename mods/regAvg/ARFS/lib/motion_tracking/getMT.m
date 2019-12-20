function [data, pcc1stPass] = getMT(imgs, data, pcc_thr, sdx)
%getMT tracks interframe motion in a video

% global variables
global TRACK_MOTION;
global MFPC;
% global wb;

%% 1st pass: Estimate translations between frame pairs
% waitbar(0, wb, 'Calculating Phase Correlation Coefficients');

% Get indices of fixed and moving frames
fix_id = [data(~[data.rej]).id]';
mov_id = fix_id;
fix_id = fix_id(1:end-1);
mov_id = mov_id(2:end);
link_id = 1;
% fprintf('\nRegistering frames: ');
for ii=1:numel(fix_id)
    fprintf('Registering frame %i to %i, ', mov_id(ii), fix_id(ii));
    if ii==1
        data(fix_id(ii)).link_id = link_id;
        [tform, pcorr, fftfix] = getPhaseCorr(...
            single(imgs(:,:,fix_id(ii))), ...
            single(imgs(:,:,mov_id(ii))));
    else
        [tform, pcorr, fftfix] = getPhaseCorr(...
            fftfix, ...
            single(imgs(:,:,mov_id(ii))));
    end
    
    % Update PCC and coordinates
    if isa(pcorr, 'gpuArray')
        pcorr = gather(pcorr);
    end
    data = updatePCC(data, fix_id(ii), mov_id(ii), pcorr);
    fprintf('PCC=%1.3f\n', pcorr);

    if pcorr > pcc_thr
        % linked
        data(fix_id(ii)).link_id = link_id;
    else
        link_id = link_id+1;
        fprintf('PCC < thr, Link ID now %i\n', link_id);
    end
    data(mov_id(ii)).link_id = link_id;
    data(mov_id(ii)).xy = data(fix_id(ii)).xy + tform.T(3,1:2);
    
    % waitbar
%     waitbar(ii/numel(fix_id), wb);
%     if mod(ii, 10) == 0
%         fprintf('%i, ', ii);
%     elseif ii==numel(fix_id)
%         fprintf('\n');
%     end
end

% Return distribution of pcc's after 1st pass for diagnostics
% todo: comment out after threshold is determined
pcc1stPass = [data.pcc]';
rej = [data.rej]';
pcc1stPass(rej) = [];

% End of 1st pass
% Return if motion tracking turned off,
% or if all frames are either rejected or below the PCC threshold
if ~TRACK_MOTION || isempty(data([data.pcc] > pcc_thr & ~[data.rej]))
    return;
end

%% Start of 2nd pass
% Waitbar
% waitbar(0, wb, 'Correcting breaks in sequence...');
% fprintf('Correcting breaks: ');
% For each linked group of frames (from largest to smallest), try to absorb
% other linked groups by comparing the frames with the highest pcc in each
[link_sorted, szs] = sortLink_id_bySize(data);
absorbed = false(size(link_sorted));
for ii=1:numel(link_sorted)
    if absorbed(ii)
        continue;
    end
    % Find frame in this link group with highest pcc
    fix_id = findKeyFrameIndex(data, link_sorted(ii));
    for jj=1:numel(link_sorted)
        if jj<=ii || absorbed(jj) || szs(jj) == 1
            first_iter = true;
            continue;
        end
        mov_id = findKeyFrameIndex(data, link_sorted(jj));
        if first_iter
            [tform, pcorr, ~, fftfix] = getPhaseCorr(...
                single(imgs(:,:,fix_id)), ...
                single(imgs(:,:,mov_id)));
            first_iter = false;
        else
            [tform, pcorr] = getPhaseCorr(...
                fftfix, ...
                single(imgs(:,:,mov_id)));
        end
        % Display text
        fprintf('Registering frame %i of group %i ', ...
            mov_id, link_sorted(jj));
        fprintf('to frame %i of group %i, ', ...
            fix_id, link_sorted(ii));
        fprintf('PCC=%1.3f.\n', pcorr);
        
        % Update PCC, coordinates, linked
        data = updatePCC(data, fix_id, mov_id, pcorr);
        
        if pcorr > pcc_thr
            absorbed(jj) = true;
            linked = [data([data.link_id] == link_sorted(jj)).id];
            data = updateXY(data, fix_id, mov_id, tform, linked);
            data = updateLinkID(data, linked, link_sorted(ii));
            
            fprintf('PCC > thr, group %i absorbed by %i.\n', ...
                link_sorted(jj), link_sorted(ii));
            break;
        else
            fprintf('PCC < thr, group %i not absorbed by %i.\n', ...
                link_sorted(jj), link_sorted(ii));
        end
    end
    
% %     Waitbar
%     waitbar(ii/numel(link_sorted), wb);
%     if mod(ii, 10) == 0
%         fprintf('%i, ', ii);
%     elseif ii==numel(link_sorted)
%         fprintf('\n');
%     end
end

%% Start of 3rd pass
% Waitbar
% waitbar(0, wb, 'Registering unlinked frames...');
% fprintf('Registering unlinked frames: ')

% Register unlinked frames to key frame in each linked group, proceed
% largest to smallest
link_sorted = sortLink_id_bySize(data);
unlinked = [data([data.link_id] == 0 & ~[data.rej]).id];
if ~isempty(unlinked)
    absorbed = false(size(unlinked));
    for ii=1:numel(link_sorted)
        fix_id = findKeyFrameIndex(data, link_sorted(ii));
        first_iter = true;
        for jj=1:numel(unlinked)
            if absorbed(jj)
                continue;
            end
            mov_id = unlinked(jj);
            if first_iter
                [tform, pcorr, ~, fftfix] = getPhaseCorr(...
                    single(imgs(:,:,fix_id)), ...
                    single(imgs(:,:,mov_id)));
                first_iter = false;
            else
                [tform, pcorr] = getPhaseCorr(...
                    fftfix, ...
                    single(imgs(:,:,mov_id)));
            end
            % Display text
            fprintf('Registering orphan frame %i to ', mov_id);
            fprintf('frame %i of group %i, ', fix_id, link_sorted(ii));
            fprintf('PCC=%1.3f.\n', pcorr);
            
            
            if pcorr > pcc_thr
                absorbed(jj) = true;
                data = updatePCC(data, fix_id, mov_id, pcorr);
                data(unlinked(jj)).link_id = link_sorted(ii);
                data(unlinked(jj)).xy = data(fix_id).xy + tform.T(3,1:2);
                
                fprintf('PCC > thr, frame %i absorbed by group %i.\n', ...
                    mov_id, link_sorted(ii));
                break;
            else
                fprintf('PCC < thr, frame %i not absorbed by group %i.\n', ...
                    mov_id, link_sorted(ii));
            end
        end
        
        % Waitbar
        % %     waitbar(ii/numel(link_sorted), wb);
        %     if mod(ii, 10) == 0
        %         fprintf('%i, ', ii);
        %     elseif ii==numel(link_sorted)
        %         fprintf('\n');
        %     end
    end
end
% End of 3rd Pass

%% Check if largest group of linked frames is smaller than mfpc
[~, link_sz] = sortLink_id_bySize(data);
if max(link_sz) < MFPC
    data(1).TRACK_MOTION = false;
    data(1).TRACK_MOTION_FAILED = true;
    
    warning('Failed to link more than %i frames together.', MFPC);
    return;
end

%% Reject small groups and PCC outliers
% Small groups
data = rejectSmallGroups(data, MFPC);
% PCC outliers
pcc = [data(~[data.rej]).pcc];
ids = [data(~[data.rej]).id];
pcc_norm = (pcc - mean(pcc))./std(pcc);
outliers = pcc_norm < -sdx;
if any(outliers)
    data = rejectFrames(data, ids(outliers), mfilename);
end

end % End of MT

% Subfunctions, moved to separate files

% function data = updatePCC(data, fix, mov, pcorr)
% % updatePCC only updates the PCC of a frame if the new value is higher than
% % the old value
%     if data(fix).pcc < pcorr
%         data(fix).pcc = pcorr;
%     end
%     if data(mov).pcc < pcorr
%         data(mov).pcc = pcorr;
%     end
% end
% 
% function data = updateXY(data, fix_id, mov_id, tform, linked)
% for ii=1:numel(linked)
%     data(linked(ii)).xy = data(linked(ii)).xy - data(mov_id).xy + ...
%         data(fix_id).xy + tform.T(3,1:2);
% end
% end
% 
% function index = findKeyFrameIndex(data, link)
%     ids     = [data([data.link_id] == link).id];
%     [~,I]   = max([data([data.link_id] == link).pcc]);
%     index   = ids(I);
%     if numel(index) > 1
%         index = index(1);
%     end
% end
% 
% function data = updateLinkID(data, ids, link_id)
% for ii=1:numel(ids)
%     data(ids(ii)).link_id = link_id;
% end
% end
% 
% function [uid_sort, link_sz] = sortLink_id_bySize(data)
% [unique_id, ~, ic] = unique([data([data.link_id]~=0).link_id]);
% link_sz = zeros(size(unique_id));
% for ii=1:numel(unique_id)
%     link_sz(ii) = numel(find(ic==ii));
% end
% [~, I] = sort(link_sz, 'descend');
% uid_sort = unique_id(I);
% end
% 
% function data = rejectSmallGroups(data, mfpc)
% rej = false(size(data));
% [uid_sort, link_sz] = sortLink_id_bySize(data);
% for ii=1:numel(data)
%     if data(ii).rej
%         continue;
%     end
%     % Reject all unlinked frames and groups smaller than mfpc
%     if data(ii).link_id == 0 || ...
%             link_sz(data(ii).link_id == uid_sort) < mfpc
%         rej(ii) = true;
%     end
% end
% 
% data = rejectFrames(data, rej, mfilename);
% end