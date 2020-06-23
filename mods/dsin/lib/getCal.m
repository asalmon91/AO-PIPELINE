function cal_data = getCal(in_path, cal_data, opts)
%getDsin creates a dsin object array and creates desinusoid files

%% Add basic information
dsin.horizontal_fringes_path        = in_path;
dsin.vertical_fringes_path          = in_path;
dsin.horizontal_fringes_filename    = cal_data.dsin.h_fname;
dsin.vertical_fringes_filename      = cal_data.dsin.v_fname;

%% Process horizontal and vertical grids
dsin = process_grids(fullfile(in_path, gridPair.h_fname), 'h', dsin);
dsin = process_grids(fullfile(in_path, gridPair.v_fname), 'v', dsin);

%% Create desinusoid matrix
[dsin, dsin_mat_fname] = create_dsin_mat(dsin, gridPair, opts.lpmm);
fprintf('%s created.\n', dsin_mat_fname);

%% Extract only most relevant information from dsin for dsin_lut
dsin_lut.fov        = gridPair.fov;
dsin_lut.wl         = gridPair.wl_nm;
dsin_lut.dsin_mat   = dsin.vertical_fringes_desinusoid_matrix;
dsin_lut.fringe     = dsin.horizontal_fringes_fringes_period;
dsin_lut.path       = in_path;
dsin_lut.fname      = dsin_mat_fname;

end