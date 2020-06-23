# Imports
import cPickle
import os
import DeSinusoider as dsin
import numpy as np

# Desinusoid file
cal_fname = 'desinusoid_matrix_790nm_1p50_deg_118p1_lpmm_fringe_9p9282_pix.mat'
cal_path = 'E:\\datasets\\demotion\\test\\JC_0616-20171222-OD\\Calibration'
# Video file
vid1_fname = 'JC_0616_790nm_OD_confocal_0111.avi'
vid2_fname = str(vid1_fname).replace('confocal','split_det')
vid3_fname = str(vid1_fname).replace('confocal','avg')
vid_path = 'E:\\datasets\\demotion\\test\\JC_0616-20171222-OD\\Raw'

# Video information
data = {'clinical_version': False,
        'image_sequence_file_name': vid1_fname,
        'image_sequence_absolute_path': vid_path,
        'fast_scanning_horizontal': True,
        'reference_frame': 53,
        'n_rows_raw_sequence': 604,
        'n_columns_raw_sequence': 752,
        'n_frames': 150,
        'desinusoiding_required': True}

# Desinusoiding
data['desinusoid_data_filename']      = cal_fname
data['desinusoid_data_absolute_path'] = cal_path
data['desinusoid_matrix']             = np.float32(dsin.DeSinusoider(
        filename=cal_fname, absolute_path=cal_path, store_error=True).GetDesinusoidMatrix())
dim1, new_col = data['desinusoid_matrix'].shape
data['n_rows_desinusoided']           = data['n_rows_raw_sequence']
data['n_columns_desinusoided']        = new_col

# SR motion estimation parameters ##############################
data['strip_registration_required'] = True
data['frame_strip_lines_per_strip'] = 20
data['frame_strip_calculation_precision'] = 'single'
data['frame_strip_lines_between_strips_start'] = 10
data['frame_strip_ncc_n_rows_to_ignore'] = int(round(data['frame_strip_lines_per_strip']/2))
data['frame_strip_ncc_n_columns_to_ignore'] = 150
data['frame_strip_ncc_threshold'] = 0.75
data['strip_max_displacement_threshold'] = 200
data['strip_DCT_terms_retained_percentage'] = 50

# FFR motion estimation parameters ##############################
data['full_frame_max_displacement_threshold'] = 200
data['full_frame_calculation_precision'] = 'single'
data['full_frame_ncc_n_lines_to_ignore'] = 150

# N frames to register
data['full_frame_n_frames_with_highest_ncc_value'] = 50
data['strip_n_frames_with_highest_ncc_value'] = 50
data['min_overlap_for_cropping_strip_image'] = 5
data['min_overlap_for_cropping_full_frame_image'] = 5

# FFR/SR save image and/or sequence
data['save_strip_registered_image'] = True
data['save_strip_registered_sequence'] = True
data['save_full_frame_registered_image'] = True
data['save_full_frame_registered_sequence'] = True

# Secondaries
data['secondary_sequences_file_names'] = [vid2_fname, vid3_fname]
data['secondary_sequences_absolute_paths'] = vid_path

# File name generation
lps = '_lps_' + str(data['frame_strip_lines_per_strip'])
lbss = '_lbss_' + str(data['frame_strip_lines_between_strips_start'])
name_root = '_ref_' + str(data['reference_frame'] + 1) + lps + lbss
batch_file_name = vid1_fname[:len(vid1_fname)-4] + name_root + '.dmb'
data['user_defined_suffix'] = ''

f = open(vid_path + os.sep + batch_file_name, 'w')
cPickle.dump(data, f)
f.close()



