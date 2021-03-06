function [ld, tasks, paths] = montage_LIVE(ld, paths, opts, tasks, pool_id, gui)
%montage_LIVE Handles parallelization for montaging

%% Return if empty
if isempty(ld.vid) || ~isfield(ld.vid, 'vid_set') || ...
		isempty(ld.vid.vid_set) || ~isfield(ld.mon, 'am_file') || ...
		isempty(ld.mon.am_file)
	return;
end

%% Check image directory for new images
srch = dir(fullfile(paths.out, '*.tif'));
this_datenum = max([srch.datenum]);

if isfield(ld.mon, 'img_datenum') && ~isempty(ld.mon.img_datenum) && ...
        this_datenum == ld.mon.img_datenum && ~any(all(findImageInMonDB(ld, {srch.name}) == 0, 2))
    return;
end

% Todo: figure out a way to allocate as many workers to montaging as
% possible. If desinusoiding and registration and averaging are all done,
% it would be good to put as much effort into this step as possible

%% Montage images if there's an open slot
for tt=1:numel(tasks)
	if ~strcmp(tasks(tt).task_type, 'mon')
		continue;
	end
	
	%% Task begin
	if strcmp(tasks(tt).task_pff.State, 'unavailable')
		% TODO: figure out how to call specific python functions without having
		% to use the command line architecture. If we could pass data directly
		% to python, this module would be a lot smoother. This may actually be
		% necessary to achieve the intended purpose of the LIVE pipeline, but
		% this will suffice as a prototype for now
		% TODO: implement our own fast matlab-based automontager...
		
		% Try mini-montages of adjacent images. Accept any successful
		% connections. The goal here is not a perfect montage, just to
		% identify poor connections
		%     all_img_fnames = vertcat(ld.mon.imgs.fnames);
% 		prime_img_fnames = getNextMontage(ld, paths, opts.mod_order{1});
% 		if numel(prime_img_fnames) < 2
% 			return;
% 		end
		
		prime_img_fnames = tasks(tt).task_obj;
		% Get the other modalities as well
		n_mods = numel(ld.mon.opts.mods);
		prime_mod = ld.mon.opts.mods{1};
		sec_mods = ld.mon.opts.mods;
		sec_mods(1) = [];
		all_img_fnames = cell(numel(prime_img_fnames)*n_mods, 1);
		for ii=1:numel(prime_img_fnames)
			all_img_fnames((ii-1)*n_mods +1:(ii-1)*n_mods +n_mods) = ...
				[prime_img_fnames{ii}; ...
				strrep(prime_img_fnames{ii}, prime_mod, sec_mods')];
% 			k = findImageInVidDB(ld, prime_img_fnames{ii});
% 			all_img_fnames((ii-1)*n_mods +1:(ii-1)*n_mods +n_mods) = ...
% 				ld.vid.vid_set(k(1)).vids(k(2)).fids(k(3)).cluster(k(4)).out_fnames;
		end
		
		% Sequester these images in a separate folder for montaging
		paths.tmp_mon = prepMiniMontage(paths.out, all_img_fnames);
		
		% Call the UCL automontager on this folder, unfortunately this still
		% means continually updating an excel file.
		
		% TODO: Make another function which includes the mini-montage setup,
		% parsing the JSX, and updating the montage database. All that stuff is
		% cluttering up this function which is supposed to mirror the
		% calibrate_LIVE and ra_LIVE functions
		
		tasks(tt).task_pff = parfeval(pool_id, @deployUCL_AM, 2, ...
			'C:\Python37\python.exe', paths.tmp_mon, ...
			fullfile(ld.mon.am_file.folder, ld.mon.am_file.name), ...
			ld.eye, paths.tmp_mon);
		update_pipe_progress(ld, paths, 'mon', gui);
% 		% DEV/DB
% 		[fail, stdout] = deployUCL_AM('C:\Python37\python.exe', paths.tmp_mon, ...
% 			fullfile(ld.mon.am_file.folder, ld.mon.am_file.name), ...
% 			ld.eye, paths.tmp_mon);
% 		% END DEV/DB
		
	%% Task finished
	elseif strcmp(tasks(tt).task_pff.State, 'finished') && isempty(tasks(tt).task_pff.Error)
		[fail, stdout] = fetchOutputs(tasks(tt).task_pff);
		
		if fail 
			error(stdout)
		else % Success
			% Find the .jsx
			srch = dir(fullfile(paths.tmp_mon, ...
				'create_recent_montage_*_fov.jsx'));
			if numel(srch) ~= 1
				% This shouldn't happen
				warning(stdout);
				warning('The automontager failed; retrying. If this keeps happening, restart the pipeline');
				
				rmdir(paths.tmp_mon, 's');
				tasks(tt) = ao_task();
				return;
			end
			
			%% Parse the montage file
			jsx_data = parseJSX(fullfile(paths.tmp_mon, srch.name));
			
			%% Convert units to degrees
			% Find the minimum FOV used in this montage
			min_fov = inf;
			for ii=1:numel(jsx_data)
				for jj=1:numel(jsx_data(ii).txfms)
					img_ffname = jsx_data(ii).txfms{jj}{1};
					[~,img_name, img_ext] = fileparts(img_ffname);
					kv = matchImgToVid(ld.vid.vid_set, [img_name, img_ext]);
% 					kv = findImageInVidDB(ld, [img_name, img_ext]);
					this_fov = ld.vid.vid_set(kv(1)).fov;
					if this_fov < min_fov
						min_fov = this_fov;
					end
				end
			end
			% Get the pixels per degree that was used for this montage
			this_ppd = ld.cal.dsin([ld.cal.dsin.fov] == min_fov).ppd;
			
			% Overwrite the paths with the original output path
			% Also overwrite the pixel units with degree values
			for ii=1:numel(jsx_data)
				for jj=1:numel(jsx_data(ii).txfms)
					[~,img_name, img_ext] = fileparts(jsx_data(ii).txfms{jj}{1});
					jsx_data(ii).txfms{jj}{1} = fullfile(paths.out, ...
						[img_name, img_ext]);
					
					for kk=2:5
						jsx_data(ii).txfms{jj}{kk} = ...
							jsx_data(ii).txfms{jj}{kk}./this_ppd;
					end
				end
			end
			ld.mon.montages = vertcat(ld.mon.montages, jsx_data');
			
			% Finally, delete the mini-montage
			[success, msg] = rmdir(paths.tmp_mon, 's');
			if ~success
				warning('Failed to remove %s', paths.tmp_mon)
				warning(msg);
			end
			
			%% For profiling
			ld = updateMontageProfile(ld);
		end
		
		% Indicate that the database needs updating
		ld.mon.needs_update = true;
		
		% Update progress
		update_pipe_progress(ld, paths, 'mon', gui);
		ld.state_changed = true;
		
		% Reset task
		tasks(tt) = ao_task;
		
	%% Task Error
	elseif ~isempty(tasks(tt).task_pff.Error)
		error(getReport(tasks(tt).task_pff.Error))
	end
end

end

