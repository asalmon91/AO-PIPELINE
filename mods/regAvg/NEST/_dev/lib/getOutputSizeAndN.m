function [ht, wd, nFrames, nCrop, tif_path, tif_fname, contiguous, cropErr] = ...
    getOutputSizeAndN(out_proc, dmb_fname, current_modality, min_frames)
%getOutputSizeAndN determines results of demotion
% todo: there is some weird bug with DeMotion where the SR .avi's don't
% seem to match the registered image. In the SR .avi, you expect the
% reference frame to show up as an undistorted raw frame, but this is
% missing sometimes. This results in chunks of the image being interpreted
% as an average of 0 frames and inferring a cropping error. It would be
% better to determine cropping errors from the .dmp so that we don't have
% to waste time dealing with the binary .avi's.

%% Defaults
ht = 0;
wd = 0;
nFrames = 0;
nCrop = 0;
tif_path = '';
tif_fname = '';
cropErr = false;
contiguous = false;

%% Find matching output tif
[~,dmb_name,~] = fileparts(dmb_fname);
tif_search = dir(fullfile(out_proc, [dmb_name, '*.tif']));
if numel(tif_search) == 0
    warning('Something went wrong with %s', dmb_fname);
    return;
elseif numel(tif_search) > 1
    tif_dates = [tif_search.datenum]';
    tif_search = tif_search(tif_dates == max(tif_dates));
end
tif_path = tif_search.folder;
tif_fname = tif_search.name;

% Get dimensions
f = imfinfo(fullfile(tif_search.folder, tif_search.name));
ht = f.Height;
wd = f.Width;

% Get the number of frames to which the stack was cropped
% (from the filename)...
[~,tif_name,~] = fileparts(tif_search.name);
nameparts = strsplit(tif_name, '_');
nCrop = str2double(nameparts{find(strcmp(nameparts, 'cropped'))+1});
if nCrop == 1
    % This is definitely a crop error, but not one where we want to
    % increase the ncc threshold
    return;
end

%% Get # Frames
% After fixing a demotion bug, n in the filename matches the n in the SR_AVI
nFrames = str2double(nameparts{find(strcmp(nameparts, 'n'))+1});

% This is trickier because the n listed in the filename is not always
% accurate. Check to see if the SR_AVI was output, and determine the # of
% frames that way. Otherwise use the filename and hope for the best

% sr_avi_path = fullfile(out_proc, '..', 'SR_AVIs');
% avi_search = dir(fullfile(sr_avi_path, [dmb_name, '*.avi']));
% if ~isempty(avi_search)
% 	if numel(avi_search) > 1
% 		% Use most recent one
% 		avi_search = avi_search([avi_search.datenum] == max([avi_search.datenum]));
% 	end
% 	
% 	% Like persistent load, but just for finding the number of frames... This is not ideal
% 	read_success = false;
% 	read_iter = 0;
% 	max_iter = 100;
% 	while ~read_success && read_iter < max_iter
% 		try
% 			vr = VideoReader(fullfile(avi_search.folder, avi_search.name)); %#ok<TNMLP>
% 			nFrames = vr.NumFrames;
% 			read_success = true;
% 		catch me
% 			% todo: check for specific codec-related error
% 			warning(me.message);
% 			read_iter = read_iter+1;
% 		end
% 	end
% 	if ~read_success
% 		rethrow(me);
% 	end
% else
%     % Use filename
%     nFrames = str2double(nameparts{find(strcmp(nameparts, 'n'))+1});
% end

%% Get distribution of pixel averages
% And check for crop errors
% Find binary image
if exist('current_modality', 'var') ~=0 && ~isempty(current_modality)
    bin_name = strrep(tif_name, current_modality, 'bin');
    if exist(fullfile(sr_avi_path, [bin_name, '.avi']), 'file') == 0
        warning('%s not found', [bin_name, '.avi']);
        % Assume in this case that something got screwed up in the cropping
        cropErr = true;
        return;
    end
    
    bin_sr_vid = fn_read_AVI(fullfile(sr_avi_path, [bin_name, '.avi']));
    bin_map = sum(bin_sr_vid, 3)./255;
    if numel(find(bin_map(:)==0)) > 0
        cropErr = true;
        return;
    end
    
    %% Measure contiguity of strip-registration
    if exist('min_frames', 'var') == 0 || isempty(min_frames)
        return;
    end
    EDGE_CUTOFF = round(0.05*size(bin_map, 1));
	if EDGE_CUTOFF < 1
		% Default contiguous is false
		% An image this small cannot succeed
		return;
	end
    row_contribution = mean(bin_map, 2);
    contiguous = ~any(...
        row_contribution(EDGE_CUTOFF:end-EDGE_CUTOFF) < min_frames);
    
    
%     % DEV/DB : USED
%     figure;
%     subplot(1,2,1);
%     imagesc(bin_map);
%     subplot(1,2,2);
%     plot(row_contribution, 1:size(bin_map,1), '-k')
%     set(gca,'ydir','reverse','tickdir','out')
%     axis tight
%     hold on;
%     xl = get(gca,'xlim');
%     xlim([0, xl(end)])
%     xl = get(gca,'xlim');
%     plot(xl, ones(2,1).*EDGE_CUTOFF, ':r')
%     plot(xl, ones(2,1).*(size(bin_map,1)-EDGE_CUTOFF), ':r')
%     yl = get(gca,'ylim');
%     plot([3,3], yl, '-r');
%     plot(ones(2,1).*min_frames, ...
%         [EDGE_CUTOFF, (size(bin_map,1)-EDGE_CUTOFF)], '--r');
%     hold off;
%     bool_str = {'False', 'True'};
%     title(sprintf('Contiguous: %s', bool_str{contiguous+1}));
%     % END DEV/DB
    
    % DEV/DB : NOT USED
%     [N,edges] = histcounts(bin_map(:), 0:size(bin_sr_vid,3), ...
%         'normalization', 'cdf');
%     px_cdf = [1-N', edges(1:end-1)'];
    % f95 statistic: 95% of pixels are an average of N frames
%     THR = 0.95;
%     just_lower = max(px_cdf(px_cdf(:,1) < THR, 1));
%     just_higher = min(px_cdf(px_cdf(:,1) >= THR, 1));
%     frames_lower = px_cdf(px_cdf(:,1) == just_lower, 2);
%     frames_higher = px_cdf(px_cdf(:,1) == just_higher, 2);
%     f95 = interp1(...
%         [just_lower; just_higher], [frames_lower; frames_higher], ...
%         THR, 'linear');
    
%     % DEV/DB
%     figure;
%     plot(px_cdf(:,1).*100, px_cdf(:,2),'-k');
%     xlabel('% of pixels');
%     ylabel('# of frames');
%     hold on;
%     plot(THR*100, f95, '*r');
%     hold off;
%     xlim([0,100]);
%     ylim([0, nFrames]);
%     legend({'Pixel Contribution Curve';'Threshold'}, ...
%         'location', 'southwest');
%     set(gca, 'tickdir', 'out', 'box', 'off',...
%         'xminorgrid', 'on', 'yminorgrid', 'on');
%     title(sprintf('F95: %0.1f', f95));
%     % % END DEV/DB
end



end

