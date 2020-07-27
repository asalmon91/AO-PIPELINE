function [fids, success] = quickSR(vid, vid_num, fids, this_dsin, paths, prime_fname, sec_fnames)
%quickSR quick Strip-registration

%% Definitions
success_crit    = 3/4 * size(vid,1);
short_circuit   = 1/3 * size(vid,1);

%% Create video readers for secondaries
vr_sec = cell(size(sec_fnames));
for mm=1:numel(sec_fnames)
    vr_sec{mm} = VideoReader(fullfile(paths.raw, sec_fnames{mm})); %#ok<TNMLP>
end

for ii=1:numel(fids)
    for jj=1:numel(fids(ii).cluster)
        these_frames = fids(ii).cluster(jj).fids;
        n_frames = numel(these_frames);
        
        %% Circumvent weird DeMotion bug
        % If the reference frame is 1, it often screws up. Flip the order
        % of the frames and set the reference frame to be the last one
        these_frames = flip(these_frames);
        ref_frame = n_frames;
        
        %% Create a temporary folder for writing video snippets
        append_text = sprintf('%i_L%iC%i', vid_num, ...
            fids(ii).lid, fids(ii).cluster(jj).cid);
        tmp_path = fullfile(paths.out, append_text, 'tmp');
        mkdir(tmp_path);
        % todo: handle failure
        
        %% Write videos
        fn_write_AVI(fullfile(tmp_path, prime_fname), ...
            gather(uint8(vid(:,:, these_frames))));
        
        %% Create batch
        % Construct secondary filename string
        sec_fname_str = strjoin(sec_fnames, ', ');
        
        % Setup defaults
        success = false;
        lps     = 25;
        lbss    = 10;
        ncc_thr = 0.1;
        last_height = 0;
        while ~success
            [~, dmb_fname, status, stdout] = deploy_createDmb(...
                paths, ...
                fullfile(tmp_path, prime_fname), ...
                'lps', lps, 'lbss', lbss, 'ncc_thr', ncc_thr, ...%'secondVidFnames', sec_fname_str, ...
                'ref_frame', ref_frame, ...
                'ffrMinFrames', 3, ...
                'srMinFrames', 3, ...
                'ffrSaveSeq', false, ...
                'srSaveSeq', false, ...
                'appendText', append_text);
            if status
                error(stdout);
            end

            %% Run DeMotion
            [status, stdout] = deploy_callDemotion(paths, tmp_path, dmb_fname);
            if status
                error(stdout);
            end

            %% Get output
            img_path = fullfile(tmp_path, '..', 'Processed', 'SR_TIFs');
            img_dir = dir(fullfile(img_path, '*.tif'));
            img_fnames = {img_dir.name}';
            % todo: include support for other wavelengths and primary
            % modalities
            [~,prime_name] = fileparts(prime_fname);
            out_fnames = img_fnames{contains(img_fnames, prime_name)};

            %% Demotion Feedback
            im_data = imfinfo(fullfile(img_path, img_fnames{1}));
            if im_data.Height >= success_crit
                success = true;
            else
                % Check to see if this at least helped
                if im_data.Height >= last_height
                    % it may be helping. try again
                    last_height = im_data.Height;
                    lps = lps*2;
                end
                if lps > short_circuit || im_data.Height < last_height
                    % Don't keep beating a dead horse
                    break;
                else
                    % We'll be trying again, so hide the failures
                    for ff=1:numel(img_fnames)
                        sequesterFails(img_dir(1).folder, img_fnames{ff})
                    end
                end
            end
        end
        
        %% After demotion, create split and average images
        if success
			% Generate secondary modality images now that we know the registration is successful
			dmp_fname = strrep(dmb_fname, '.dmb', '.dmp');
			for mm=1:numel(sec_fnames)
				writeSnippet(fullfile(tmp_path, sec_fnames{mm}), vr_sec{mm}, ...
					these_frames, this_dsin.mat');
				% Modify video name in dmp to apply strip reg to secondaries			
				[status, stdout] = processSecondary(...
					fullfile(tmp_path, dmp_fname), ...
					fullfile(tmp_path, sec_fnames{mm}), paths);
				if ~status
					error(stdout);
				end
			end
			img_dir = dir(fullfile(img_path, '*.tif'));
            img_fnames = {img_dir.name}';
            % Read specific frames of secondaries that are required
% 			for mm=1:numel(sec_fnames)
% 				vw = VideoWriter(fullfile(tmp_path, sec_fnames{mm}), ...
% 					'grayscale avi'); %#ok<TNMLP>
% 				open(vw);
% 				for nn=1:n_frames
% 					% Read, desinusoid, & write without storing data to be as 
% 					% fast as possible
% 					writeVideo(vw, ...
% 						uint8(single(...
% 						read(vr_sec{mm}, these_frames(nn))) * ...
% 						this_dsin.mat'));
% 				end
% 				close(vw);
% 			end
			
            if numel(find(contains(img_fnames, 'direct'))) == 1 && ...
                    numel(find(contains(img_fnames, 'reflect'))) == 1
                % Prep file names
                direct_fname = img_fnames{contains(img_fnames, 'direct')};
                reflect_fname = img_fnames{contains(img_fnames, 'reflect')};
                split_fname = strrep(direct_fname, 'direct', 'split_det');
                avg_fname = strrep(direct_fname, 'direct', 'avg');
                % Read
                direct_img = single(imread(fullfile(img_path, direct_fname)));
                reflect_img = single(imread(fullfile(img_path, reflect_fname)));
                % Create split and avg images
                split_img = contrast_stretch(...
                    (direct_img - reflect_img) ./ (direct_img + reflect_img));
                avg_img = contrast_stretch((direct_img + reflect_img) ./ 2);

                % Write
                imwrite(split_img, fullfile(img_path, split_fname));
                imwrite(avg_img, fullfile(img_path, avg_fname));

                % Add to output
                out_fnames = [out_fnames; {split_fname; avg_fname}]; %#ok<AGROW>
            end
            fids(ii).cluster(jj).out_fnames = out_fnames;
            

            %% Gather to whole processed directory
            for mm=1:numel(out_fnames)
                copyfile(fullfile(img_path, out_fnames{mm}), ...
                    paths.out);
            end
        end
        fids(ii).cluster(jj).success = success;
        %% Delete temporary path
        [status, msg] = rmdir(fullfile(tmp_path, '..'), 's');
		if status
			warning(msg)
		end
    end
end

end

function writeSnippet(ffname, vr, frame_idx, dsin_mat)

vw = VideoWriter(ffname, 'grayscale avi');
open(vw);
try
	for nn=1:numel(frame_idx)
		% Read, desinusoid, & write without storing data to be as fast as possible
		writeVideo(vw, uint8(single(read(vr, frame_idx(nn))) * dsin_mat));
	end
catch
	close(vw);
	return;
end
close(vw);

end

function [status, stdout] = processSecondary(dmp_ffname, vid_ffname, paths)

[~, vid_name, vid_ext] = fileparts(vid_ffname);

%% Load .dmp and update primary sequence name
fid = py.open(dmp_ffname, 'r');
pick = py.pickle.load(fid);
fid.close();
% pick{'image_sequence_absolute_path'} = vid_path;
pick{'image_sequence_file_name'} = [vid_name, vid_ext];
fid = py.open(dmp_ffname, 'w');
py.cPickle.dump(pick, fid);
fid.close();

%% Get path to reprocessing script
% calling_fx_ffname = mfilename('fullpath');
% path_parts = strsplit(calling_fx_ffname, filesep);
% py_path = calling_fx_ffname(1:end-numel(path_parts{end}));
% py_path = 'D:\Code\AO\_dev\tmp\AO-PIPELINE\mods\regAvg\callDemotion\fb';
% py_ffname = fullfile(py_path, 'reprocessWithDMP.py');

%% Process the .dmp
[status, stdout] = system(sprintf('"%s" "%s" --dmpFFname "%s"', ...
    getIniPath(paths.third_party, 'Python 2.7'), ...
	getIniPath(paths.third_party, 'reprocessWithDMP'), ...
	dmp_ffname));
if status ~=0
    error(stdout);
else
    % Get success status from stdout
    out_lines = strsplit(stdout, '\n');
    status = eval(lower(out_lines{2}));
end



end
