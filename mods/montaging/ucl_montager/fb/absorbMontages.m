function montages = absorbMontages(montages)
%absorbMontages combines montages with shared images

if numel(montages) > 1
    new_absorb = true; % Make sure this loop runs at least once
    while new_absorb
        absorbed = false(size(montages));
        for ii=1:numel(montages)
            if absorbed(ii) % Don't use absorbed montages as sources
                continue;
            end
            % Get all names in this montage
            img_ffnames = cellfun(@(x) x{1}, montages(ii).txfms, 'uniformoutput', false)';
            [~,img_names, img_exts] = cellfun(@fileparts, img_ffnames, 'uniformoutput', false);
            src_fnames = cellfun(@(x,y) [x,y], img_names, img_exts, 'uniformoutput', false);
            
            for jj=1:numel(montages)
                if jj<=ii || absorbed(jj) % Don't look back in anger
                    continue;
                end
                % Get all names in this montage
                img_ffnames = cellfun(@(x) x{1}, montages(jj).txfms, 'uniformoutput', false)';
                [~,img_names, img_exts] = cellfun(@fileparts, img_ffnames, 'uniformoutput', false);
                trg_fnames = cellfun(@(x,y) [x,y], img_names, img_exts, 'uniformoutput', false);
                
                % See if any of the target filenames also exist in the source
                % montage
                shared_fname = '';
                for kk=1:numel(trg_fnames)
                    if ismember(trg_fnames{kk}, src_fnames)
%                         fprintf('%s is shared between two montages, combining.\n', trg_fnames{kk});
                        shared_fname = trg_fnames{kk};
                        break;
                    end
                end
                if ~isempty(shared_fname)
                    % Determine position of the shared image in the source and
                    % target montages.
                    src_idx = find(strcmp(src_fnames, shared_fname));
                    src_idx = src_idx(1); % There could be multiple shared
                    src_pos = cell2mat(montages(ii).txfms{src_idx}(2:3));

                    trg_idx = find(strcmp(trg_fnames, shared_fname));
                    trg_idx_1 = trg_idx(1); % There could be multiple shared
                    trg_pos = cell2mat(montages(jj).txfms{trg_idx_1}(2:3));

                    dxdy = src_pos - trg_pos;
                    
                    % Remove the shared image from the target montage to
                    % avoid redundancy
                    montages(jj).txfms(trg_idx) = [];

                    % Shift all positions in the target montage to match the
                    % source montage
                    for kk=1:numel(montages(jj).txfms)
                        montages(jj).txfms{kk}{2} = ...
                            montages(jj).txfms{kk}{2} + dxdy(1);
                        montages(jj).txfms{kk}{3} = ...
                            montages(jj).txfms{kk}{3} + dxdy(2);
                    end

                    % Add the target txfms to the source txfms and 
                    montages(ii).txfms = [...
                        montages(ii).txfms, ...
                        montages(jj).txfms];
                    % Update absorption status
                    absorbed(jj) = true;
                end
            end
        end
        montages(absorbed) = []; % Remove absorbed montages
        new_absorb = any(absorbed);
    end
end

end

