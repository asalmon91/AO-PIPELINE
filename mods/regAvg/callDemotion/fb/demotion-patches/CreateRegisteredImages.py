# Demotion: Image registration module that outputs cropped and uncroppend
#           registered images in TIFF and ASCII format with the
#           corresponding frame sum maps in ASCII.
#
#
# Alf Dubra (adubra@cvs.rochester.edu) and Zach Harvey (zgh7555@gmail.com)
# University of Rochester
# March 2010
# MOD:AES:20200310:__find_max_area_cropping_rectangle__: Changed hard-coded cropping search from 10px to 2


# loading general modules
import cPickle, wx, Image, os
import numpy as np
from   scipy import interpolate, ndimage
import time

# loading our modules
import FindExtremesOfMonotonicIntervals, DCTInterpolator


# creating global variables
strip_interpolation_order                 = 3

# calculating the machine epsilon for float (single) precision
float32_eps                               = 2**-24


###########################################################################
#                                                                         #
#                   REGISTERING PRIMARY SEQUENCE ONLY                     #
#                                                                         #
###########################################################################

def RegisterPrimaryImageSequence(data, batch_processor_tool_bag, progress_bar, profile = False):
    
    """This function takes a Python dictionary generated with the GUI
       wxDemotionCreateAndModifyBatchFile_settings, and produces the
       following outputs if required:

       - cropped registered images in single-precision ASCII files.

       - contrast stretched cropped registered images in 8-bit monochrome
         TIFF format.

       - cropped frame sum map in ASCII format that correspond to the
         registered image.

       Calculation results, such as cropping coordinates and interpolation
       curves for the strip registration are added to the input dictionary
       before returning it.
    """

    ####
    # If profiling is true then we keep track of the different steps using
    # this dictionary
    ####
    if profile:
        timing_dictionary = {}
        timing_dictionary['file_reading']  = 0
        timing_dictionary['file_writing']  = 0
        timing_dictionary['interpolating'] = 0

    #######################################################################
    #  Creating the desinusoider                                          #
    #######################################################################

    desinudoiding_required              = data['desinusoiding_required']
    fast_scanning_horizontal            = data['fast_scanning_horizontal']

    if desinudoiding_required:

        # initializing the desinusoider by passing the desinusoid matrix
        # and direction, rather than a Matlab desinusoid file. Note that
        # for desinusoiding single precision is more than enough.
        desinusoider                    = batch_processor_tool_bag.GenerateDeSinusoider(
                                          numpy_desinusoid_matrix = data['desinusoid_matrix'],
                                          horizontal_warping      = fast_scanning_horizontal,
                                          store_error             = True,
                                          precision               = 'single')

        # checking for errors when creating the desinusoider
        failed, error_msg, error_title  = desinusoider.GetErrorMsg()
        if failed:
            return False, error_msg, data
    else:
        desinusoider                    = None
        

    #######################################################################
    #  Creating CUDA image readers (AVIs only for now)                    # 
    #######################################################################

    batch_path, batch_file_name               = os.path.split(data['batch_file_name_and_path'])
    batch_file_name_without_extension         = batch_file_name[:len(batch_file_name)-4]
    data['batch_path']                        = batch_path
    data['batch_file_name_without_extension'] = batch_file_name_without_extension

    # testing if the file can be found in the original path    
    success, correct_path                     = __find_the_path__(data['image_sequence_absolute_path'],
                                                                  data['image_sequence_file_name'],
                                                                  batch_path)

    if not success:
        return False, 'Could not find the AVI file in the original '    +\
                      'directory, the same directory but in the batch ' +\
                      'file drive or the batch file directory.', data

    if profile:
        start_time = time.clock()

    # creating primary sequence reader 
    image_reader                              = batch_processor_tool_bag.GenerateImageReader(
                                                  filename      = data['image_sequence_file_name'],
                                                  img_type      = 'avi',
                                                  absolute_path = correct_path,
                                                  precision     = 'single',
                                                  store_error   = True)

    if profile:
        timing_dictionary['file_reading'] += time.clock() - start_time

    # checking for errors when creating the image reader
    failed, error_msg, error_title            = image_reader.GetErrorMsg()
    if failed:
        return False, error_msg, data

    # getting AVI info
    n_frames                                  = image_reader.n_frames
    n_columns_raw                             = image_reader.n_columns
    n_rows_raw                                = image_reader.n_rows


    #######################################################################
    #   Determining which frames are considered acceptable                #
    #######################################################################

    # Acceptable frames are those in which the estimated full frame motion
    # is smaller than the maximum displacement threshold entered by the
    # user. Within those frames, only the ones with highest normalized
    # cross-correlation (ncc) values will be used in what follows.

    full_frame_row_shifts               = data['full_frame_ncc']['row_shifts']
    full_frame_column_shifts            = data['full_frame_ncc']['column_shifts']

    # initializing values
    full_frame_n_frames_to_register     = 0
    strip_max_n_frames_to_register      = 0
    
    # getting the maximum number of frames that need to be registered
    if data.has_key('full_frame_n_frames_with_highest_ncc_value'):

        if type(data['full_frame_n_frames_with_highest_ncc_value']) == type(1):
            full_frame_n_frames_to_register = [    data['full_frame_n_frames_with_highest_ncc_value']]
        else:
            full_frame_n_frames_to_register = list(data['full_frame_n_frames_with_highest_ncc_value'])

        full_frame_max_n_frames_to_register = max(full_frame_n_frames_to_register)

        # sorting the list in increasing order
        full_frame_n_frames_to_register.sort()


    if data.has_key('strip_n_frames_with_highest_ncc_value'):
        # reading data from the dictionary
        if type(data['strip_n_frames_with_highest_ncc_value'])      == type(1):
            strip_n_frames_to_register      = [    data['strip_n_frames_with_highest_ncc_value']]
        else:
            strip_n_frames_to_register      = list(data['strip_n_frames_with_highest_ncc_value'])

        strip_max_n_frames_to_register      = max(strip_n_frames_to_register)


    if (not data.has_key('full_frame_n_frames_with_highest_ncc_value')) and\
       (not data.has_key('strip_n_frames_with_highest_ncc_value')):
       return False, 'No outputs were selected (i.e. registered images or sequences).',data

    # finding the acceptable frames
    acceptable_frames                       = __determine_acceptable_frames__(
                                            full_frame_row_shifts                 = full_frame_row_shifts,
                                            full_frame_column_shifts              = full_frame_column_shifts,
                                            full_frame_max_displacement_threshold = data['full_frame_max_displacement_threshold'],
                                            full_frame_ncc_max_values             = data['full_frame_ncc']['ncc_max_values'],
                                            max_n_full_frames_to_register         = max(full_frame_n_frames_to_register,
                                                                                        strip_max_n_frames_to_register))


    # exiting if there is only one frame to register (i.e. the reference)
    if type(acceptable_frames) == type(1):
        return False, 'Exiting the registration because there is only ' +\
                      'one acceptable frame.', data
    else:        
        n_acceptable_frames             = len(acceptable_frames)

        # returning if there is no single acceptable frame. Not even the reference frame!
        if n_acceptable_frames == 0:
            return False, 'Exiting the registration because there is ' +\
                          'not a single acceptable frame. Reconsider ' +\
                          'input parameters, such as, # of NCC lines ' +\
                          'to ignore.', data

    if data.has_key('full_frame_n_frames_with_highest_ncc_value'):
        # the number of frames to register might be higher than the number of
        # acceptable frames. In order to take care of this, we clamp to the
        # maximum number of frames and remove the repeated elements
        full_frame_n_frames_to_register = np.where(np.array(full_frame_n_frames_to_register) <= n_acceptable_frames,
                                                            full_frame_n_frames_to_register,
                                                            n_acceptable_frames)

        full_frame_n_frames_to_register = list(set(full_frame_n_frames_to_register))

        full_frame_n_frames_to_register.sort()


    #######################################################################
    #   Determining size of desinusoided registered uncropped images      #
    #######################################################################

    # priming the desinusoider
    success, current_frame, error_msg = __read_an_image__(
                                frame_index            = 0,
                                image_reader           = image_reader,
                                desinusoider           = desinusoider,
                                desinudoiding_required = desinudoiding_required)
    
    # getting the size of a single desinusoided single frame
    if desinudoiding_required:
        if fast_scanning_horizontal:
            initial_n_lines, final_n_lines      = desinusoider.desinusoid_matrix.shape

            # defining the number of rows and columns values
            n_rows_desinusoided                 = n_rows_raw
            n_columns_desinusoided              = final_n_lines
        else:
            final_n_lines, initial_n_lines      = desinusoider.desinusoid_matrix.shape

            # defining the number of rows and columns values
            n_rows_desinusoided                 = final_n_lines
            n_columns_desinusoided              = n_columns_raw
    else:
        # defining the number of rows and columns values
        n_rows_desinusoided                     = n_rows_raw
        n_columns_desinusoided                  = n_columns_raw


    # determining the size of the extended image
    full_frame_n_rows_reg_img                   = n_rows_desinusoided                               +\
                                                  max(full_frame_row_shifts    [acceptable_frames]) -\
                                                  min(full_frame_row_shifts    [acceptable_frames])
    full_frame_n_columns_reg_img                = n_columns_desinusoided                            +\
                                                  max(full_frame_column_shifts [acceptable_frames]) -\
                                                  min(full_frame_column_shifts [acceptable_frames])

    # calculating fixed offsets for all frames   
    full_frame_row_offset                       = max(full_frame_row_shifts   [acceptable_frames])
    full_frame_column_offset                    = max(full_frame_column_shifts[acceptable_frames])

    data['full_frame_ncc']['n_rows_reg_img']    = full_frame_n_rows_reg_img
    data['full_frame_ncc']['n_columns_reg_img'] = full_frame_n_columns_reg_img
    data['full_frame_ncc']['row_offset']        = full_frame_row_offset
    data['full_frame_ncc']['column_offset']     = full_frame_column_offset


    ###########################################################################
    #  Calculating the interpolation curves and strip registered image size   #
    ###########################################################################

    strip_registration_required                 =  data['strip_registration_required'] and\
                                                  (data['save_strip_registered_image'] or \
                                                   data['save_strip_registered_sequence'])

    if strip_registration_required:

        # reading data from the dictionary
        if type(data['strip_n_frames_with_highest_ncc_value'])      == type(1):
            strip_n_frames_to_register      = [    data['strip_n_frames_with_highest_ncc_value']]
        else:
            strip_n_frames_to_register      = list(data['strip_n_frames_with_highest_ncc_value'])

        # the number of frames to register might be higher than the number of
        # acceptable frames. In order to take care of this, we clamp to the
        # maximum number of frames and remove the repeated elements
        strip_n_frames_to_register              = np.where(np.array(strip_n_frames_to_register) <= n_acceptable_frames,
                                                                    strip_n_frames_to_register,
                                                                    n_acceptable_frames)

        strip_n_frames_to_register              = list(set(strip_n_frames_to_register))

        strip_n_frames_to_register.sort()

        # getting data from the dictionary
        n_lines_per_strip                       = data['frame_strip_lines_per_strip']
        lines_between_strips_start              = data['frame_strip_lines_between_strips_start']

        # calculating interpolation curves for strip registration
        strip_interpolation_data                = __calculate_strip_interpolation_curves__(
                                                  acceptable_frames,
                                                  data['strip_ncc'],
                                                  data['full_frame_ncc'],
                                                  data['strip_max_displacement_threshold'],
                                                  data['frame_strip_ncc_threshold'],
                                                  fast_scanning_horizontal,
                                                  2,
                                                  data['strip_DCT_terms_retained_percentage'])

        # adding current frame intervals to the list (only acceptable frames)
        data['sequence_interval_data_list']     = strip_interpolation_data

        # Determining the size of the strip-registered image
        strip_n_rows_reg_img, strip_n_columns_reg_img,\
        strip_row_offset,     strip_column_offset = __determine_strip_registered_image_size__(
                                                    data['sequence_interval_data_list'],
                                                    fast_scanning_horizontal,
                                                    acceptable_frames,
                                                    n_rows_desinusoided,
                                                    n_columns_desinusoided)
        
        # returning an error if there is not at least a single valid interval
        if (strip_n_rows_reg_img == 0) or (strip_n_columns_reg_img == 0):
            return False, 'The size of the strip-registered image is empty. ' +\
                          'Try registering with different parameters.', data

        data['strip_ncc']['n_rows_reg_img']     = strip_n_rows_reg_img
        data['strip_ncc']['n_columns_reg_img']  = strip_n_columns_reg_img
        data['strip_ncc']['row_offset']         = strip_row_offset
        data['strip_ncc']['column_offset']      = strip_column_offset


    #######################################################################
    #   Creating matrices to store registered images                      #
    #######################################################################

    full_frame_registration_required            = data['save_full_frame_registered_image'] or\
                                                  data['save_full_frame_registered_sequence']
    
    # creating matrices for the full frame registered image and the sum map
    
    if full_frame_registration_required:
        full_frame_reg_img                      = np.zeros((full_frame_n_rows_reg_img,
                                                            full_frame_n_columns_reg_img),
                                                            dtype = np.float32)

        full_frame_sum_map                      = np.zeros((full_frame_n_rows_reg_img,
                                                            full_frame_n_columns_reg_img),
                                                            dtype = np.float32)

        full_frame_cropping_ROI_1               = []        
        full_frame_cropping_ROI_2               = []
        full_frame_cropping_values              = []

    # creating matrices for the strip registered image and the sum map
    if strip_registration_required:
        # this section is needed even if we do not need to produce a
        # registered image. We still need to generate the cropping ROI for
        # the registered sequences
       
        strip_reg_img                       = np.zeros((strip_n_rows_reg_img,
                                                        strip_n_columns_reg_img),
                                                        dtype = np.float32)

        strip_sum_map                       = np.zeros((strip_n_rows_reg_img,
                                                        strip_n_columns_reg_img),
                                                        dtype = np.float32)

        strip_cropping_ROI_1                = []        
        strip_cropping_ROI_2                = []
        strip_cropping_values               = []
   
        n_pixels_to_interpolate             = strip_n_rows_reg_img * strip_n_columns_reg_img

        current_frame_desired_columns       = np.zeros((n_pixels_to_interpolate), dtype = np.float32)
        current_frame_desired_rows          = np.zeros((n_pixels_to_interpolate), dtype = np.float32)
        reference_frame_desired_columns     = np.zeros((n_pixels_to_interpolate), dtype = np.int32)
        reference_frame_desired_rows        = np.zeros((n_pixels_to_interpolate), dtype = np.int32)

        # creating auxiliary vectors for interpolation calculations
        row_indices                         = np.arange(n_rows_desinusoided   , dtype = np.int32)
        column_indices                      = np.arange(n_columns_desinusoided, dtype = np.int32)


    #######################################################################
    #   Creating prefix for output file names                             #
    #######################################################################

    # creating first part of the filename (after removing the extension)
    output_files_prefix                     = '\\' +\
                                              data['image_sequence_file_name'][:len(data['image_sequence_file_name'])-4] +\
                                              data['user_defined_suffix']

    
    #######################################################################
    #  Iterating through acceptable frames to generate registered images  #
    #######################################################################

    for acceptable_index in range(n_acceptable_frames):

        # getting the index of the frame in the sequence
        frame_index                       = acceptable_frames[acceptable_index]

        if profile:
            start_time = time.clock()
    
        # reading and desinusoiding primary sequence current frame
        success, current_frame, error_msg = __read_an_image__(
                                              frame_index            = frame_index,
                                              image_reader           = image_reader,
                                              desinusoider           = desinusoider,
                                              desinudoiding_required = desinudoiding_required)

        if profile:
            timing_dictionary['file_reading'] += time.clock() - start_time
     
        ###################################################################
        #  Full frame image registration                                  #
        ###################################################################

        if full_frame_registration_required:

            # updating the frame sum map
            full_frame_sum_map[full_frame_row_offset    - full_frame_row_shifts   [frame_index] :                           \
                               full_frame_row_offset    - full_frame_row_shifts   [frame_index] + n_rows_desinusoided,      \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] :                           \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] + n_columns_desinusoided] +=\
                               1                

            # adding the desinusoided image to the registered image
            full_frame_reg_img[full_frame_row_offset    - full_frame_row_shifts   [frame_index] :                           \
                               full_frame_row_offset    - full_frame_row_shifts   [frame_index] + n_rows_desinusoided,      \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] :                           \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] + n_columns_desinusoided] +=\
                               current_frame


        ###################################################################
        #   Strip registration                                            #
        ###################################################################

        if strip_registration_required:

            # generate an interpolation object for this frame
            interpolation_method = ''
            if strip_interpolation_order == 1:
                interpolation_method = 'linear'
            elif strip_interpolation_order == 3:
                interpolation_method = 'cubic'
                
            interpolator = batch_processor_tool_bag.GenerateInterpolator(interpolation_method, current_frame.shape)

            # getting the current frame intervals
            current_frame_intervals                 = strip_interpolation_data[acceptable_index]
            
            # iterating through each interval
            for current_frame_interval in current_frame_intervals:

                # initializing values that will be modified in each interval
                n_reference_lines_slow_axis         = len(current_frame_interval['slow_axis_pixels_in_reference_frame'])
                n_valid_pixels                      = 0

                # calculatign the integer and fractional parts of the fast axis shift
                line_fast_axis_shifts               = current_frame_interval['fast_axis_pixels_in_reference_frame_interpolated']
                line_fast_axis_shifts_integer       = np.floor(line_fast_axis_shifts)
                line_fast_axis_shifts_fractional    = line_fast_axis_shifts - line_fast_axis_shifts_integer

                # iterating through every line in the interval               
                for line_index in range(n_reference_lines_slow_axis):

                    # finding which of the pixels to interpolate fall within the (current) image
                    if fast_scanning_horizontal:
                        # Taking care of fractional pixel shifts
                        if line_fast_axis_shifts_fractional  [line_index] == 0:
                            line_start_index        = 0 
                            line_end_index          = n_columns_desinusoided
                        elif line_fast_axis_shifts_fractional[line_index]  > 0:
                            line_start_index        = 1 
                            line_end_index          = n_columns_desinusoided
                        else:
                            line_start_index        = 0
                            line_end_index          = n_columns_desinusoided - 1
                            
                        # coordinates of the reference pixels to calculate over the current frame 
                        current_frame_desired_rows     [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               current_frame_interval  ['slow_axis_pixels_in_current_frame_interpolated'][line_index]

                        current_frame_desired_columns  [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         column_indices[                 line_start_index :                  line_end_index]  \
                                       - line_fast_axis_shifts_fractional[line_index]

                        reference_frame_desired_rows   [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               + strip_row_offset\
                               + current_frame_interval['slow_axis_pixels_in_reference_frame'][line_index]
                       
                        reference_frame_desired_columns[n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         column_indices[                 line_start_index :                  line_end_index]  \
                               + strip_column_offset\
                               + line_fast_axis_shifts_integer[line_index]

                    else:
                        # Making sure we only calculate pixels within the current frame
                        if line_fast_axis_shifts_fractional  [line_index] == 0:
                            line_start_index        = 0 
                            line_end_index          = n_rows_desinusoided
                        elif line_fast_axis_shifts_fractional[line_index] > 0:
                            line_start_index        = 1 
                            line_end_index          = n_rows_desinusoided
                        else:
                            line_start_index        = 0
                            line_end_index          = n_rows_desinusoided - 1                      

                           
                        # coordinates of the distorted reference frame grid points over the current frame
                        current_frame_desired_rows     [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         row_indices   [                 line_start_index :                  line_end_index]\
                                       - line_fast_axis_shifts_fractional[line_index]
                        
                        current_frame_desired_columns  [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               current_frame_interval  ['slow_axis_pixels_in_current_frame_interpolated'][line_index]

                        # coordinates of the reference frame grid points
                        reference_frame_desired_rows   [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         row_indices   [                 line_start_index :                  line_end_index]  \
                                       + strip_row_offset\
                                       + line_fast_axis_shifts_integer[line_index]
                       
                        reference_frame_desired_columns[n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               + current_frame_interval['slow_axis_pixels_in_reference_frame'][line_index]\
                               + strip_column_offset

                    # END of if fast_scanning_horizontal: #################

                   
                    # keeping track of the number of valid indices
                    n_valid_pixels                  = n_valid_pixels + line_end_index - line_start_index


                # END of for line_index loop ##############################
                       
                # interpolating all the pixels at once. If order is 1, then
                # the interpolation is bilinear, cval, the "clamp" value,
                # is the value outside the current frame. Just in case, we
                # set the prefilter option to False.

                if profile:
                    start_time = time.clock()

                (interpolated_intensity_values, success)  = interpolator.MapCoordinatesFromNumpyArray(
                                                                    np.float32(current_frame),
                                                                    current_frame_desired_rows   [:n_valid_pixels],
                                                                    current_frame_desired_columns[:n_valid_pixels],
                                                                    0)

                if profile:
                    timing_dictionary['interpolating'] += time.clock() - start_time

                # placing the interpolated intensity values in the registered image                
                strip_reg_img   [reference_frame_desired_rows   [:n_valid_pixels],
                                 reference_frame_desired_columns[:n_valid_pixels]] += interpolated_intensity_values

                strip_sum_map   [reference_frame_desired_rows   [:n_valid_pixels],
                                 reference_frame_desired_columns[:n_valid_pixels]] += 1

            # END of for interval_index in range(current_frame_n_intervals): ######


        # checking if any number of desired frames has been reached
        if full_frame_registration_required:
            if full_frame_n_frames_to_register.count(acceptable_index + 1) > 0:
            
                ###############################################################
                # First full frame coarse cropping: removing zeros            #
                ###############################################################

                # finding the limits of the ROI to crop
                cropped_row_indices            = np.nonzero(full_frame_sum_map.max(1))[0]
                min_row_crop                   = cropped_row_indices[0]
                max_row_crop                   = cropped_row_indices[len(cropped_row_indices)       - 1]

                cropped_column_indices         = np.nonzero(full_frame_sum_map.max(0))[0]
                min_column_crop                = cropped_column_indices[0]
                max_column_crop                = cropped_column_indices[len(cropped_column_indices) - 1]

               # keeping track of the ROI
                full_frame_cropping_ROI_1.append([min_row_crop,    max_row_crop,
                                                  min_column_crop, max_column_crop])

                # cropping the sum map to remove zero rows and columns
                full_frame_sum_map_cropped     = full_frame_sum_map[min_row_crop    : max_row_crop,
                                                                    min_column_crop : max_column_crop]

                # cropping the full frame registered image to remove zero rows and columns
                full_frame_reg_img_cropped     = full_frame_reg_img[min_row_crop    : max_row_crop,
                                                                    min_column_crop : max_column_crop]

                # dividing the image sum by the sum map to produce a registered image
                reg_image_avg                  = full_frame_reg_img_cropped /\
                                                (full_frame_sum_map_cropped + float32_eps)


                ###############################################################
                # Second full frame cropping: user entry                      #
                ###############################################################

                full_frame_cropping_value      = int(min(full_frame_sum_map_cropped.max(),
                                                         data['min_overlap_for_cropping_full_frame_image']))

                if data['min_overlap_for_cropping_full_frame_image']  > 1:
                        
                    # finding the rectangle with maximum area that has the minimum
                    # number of overlapping frames required The ROI coordinates
                    # are: min_row, max_row, min_column, max_column

                    

                    full_frame_binary_cropping_mask  = (full_frame_sum_map_cropped >= full_frame_cropping_value)

                    full_frame_success, cropping_ROI = __find_max_area_cropping_rectangle__(full_frame_binary_cropping_mask,
                                                                                            fast_scanning_horizontal)
                else:
                    full_frame_success               = True
                    cropping_ROI                     = [0, full_frame_sum_map_cropped.shape[0],
                                                        0, full_frame_sum_map_cropped.shape[1]]

                if full_frame_success:
                    
                    # cropping the sum map as specified by the user
                    full_frame_sum_map_cropped   = full_frame_sum_map_cropped[cropping_ROI[0] : cropping_ROI[1],
                                                                              cropping_ROI[2] : cropping_ROI[3]]

                    # keeping track of the ROI cropping
                    full_frame_cropping_ROI_2.append(cropping_ROI)
                    full_frame_cropping_values.append(full_frame_cropping_value)

                    if data['save_full_frame_registered_image']:
                        # cropping the images again as specified by the user
                        reg_image_avg_cropped        = reg_image_avg[cropping_ROI[0] : cropping_ROI[1],
                                                                     cropping_ROI[2] : cropping_ROI[3]]

                        # creating the name for the output files
                        temp_file_name               = output_files_prefix + '_ffr_n_' + str(acceptable_index + 1) +\
                                                      '_cropped_' + str(full_frame_cropping_value)

                        if profile:
                            start_time = time.clock()
                        
                        # saving the frame sum map data to an ASCII file
                        #__save_frame_sum_map__( full_frame_sum_map_cropped, temp_file_name)

                        # saving the the averaged image data to an ASCII file and the contrasted TIFF
                        __save_image_as_TIFF__( reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\FFR_TIFs' + temp_file_name)
                        __save_image_as_ASCII__(reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\FFR_DATs' + temp_file_name)

                        if profile:
                            timing_dictionary['file_writing'] += time.clock() - start_time
                else:
                    return False, 'Failed to find a cropping area in the full frame-registered image (cropping value ' +\
                           str(full_frame_cropping_value) + ')', data
                    


        # checking if any number of desired frames has been reached        
        if strip_registration_required:
            if strip_n_frames_to_register.count(acceptable_index + 1) > 0:
        
                ###############################################################
                # First full frame coarse cropping: removing zeros            #
                ###############################################################

                # finding the limits of the ROI to crop
                cropped_row_indices             = np.nonzero(strip_sum_map.max(1))[0]
                min_row_crop                    = cropped_row_indices[0]
                max_row_crop                    = cropped_row_indices[len(cropped_row_indices)       - 1]

                cropped_column_indices          = np.nonzero(strip_sum_map.max(0))[0]
                min_column_crop                 = cropped_column_indices[0]
                max_column_crop                 = cropped_column_indices[len(cropped_column_indices) - 1]

                # keeping track of the ROI cropping
                strip_cropping_ROI_1.append([min_row_crop,    max_row_crop,
                                             min_column_crop, max_column_crop])

                # cropping the sum map to remove zero rows and columns
                strip_sum_map_cropped           = strip_sum_map[min_row_crop    : max_row_crop,
                                                                min_column_crop : max_column_crop]

                # cropping the full frame registered image to remove zero rows and columns
                strip_reg_img_cropped           = strip_reg_img[min_row_crop    : max_row_crop,
                                                                min_column_crop : max_column_crop]

                # dividing the image sum by the sum map to produce a registered image
                strip_reg_image_avg             = strip_reg_img_cropped /\
                                                 (strip_sum_map_cropped + float32_eps)

                ###############################################################
                # Second full frame cropping: user entry                      #
                ###############################################################

                strip_cropping_value            = int(min(strip_sum_map_cropped.max(),
                                                          data['min_overlap_for_cropping_strip_image']))

                if data['min_overlap_for_cropping_strip_image']  > 1:
                    # finding the rectangle with maximum area that has the minimum
                    # number of overlapping frames required The ROI coordinates
                    # are: min_row, max_row, min_column, max_column

                    strip_binary_cropping_mask        = (strip_sum_map_cropped >= strip_cropping_value)
                    
                    strip_success, strip_cropping_ROI = __find_max_area_cropping_rectangle__(strip_binary_cropping_mask,
                                                                                             fast_scanning_horizontal)
                else:
                    strip_success                     = True
                    strip_cropping_ROI                = [0, strip_sum_map_cropped.shape[0],
                                                         0, strip_sum_map_cropped.shape[1]]

                if strip_success:
                    
                    # cropping the sum map as specified by the user
                    strip_sum_map_cropped             = strip_sum_map_cropped[strip_cropping_ROI[0] : strip_cropping_ROI[1],
                                                                              strip_cropping_ROI[2] : strip_cropping_ROI[3]]

                    # keeping track of the ROI cropping
                    strip_cropping_ROI_2.append(strip_cropping_ROI)
                    strip_cropping_values.append(strip_cropping_value)

                    if data['save_strip_registered_image']:

                        # creating the name for the output files
                        temp_file_name                    = output_files_prefix + '_sr_n_' + str(acceptable_index + 1) +\
                                                          '_cropped_' + str(strip_cropping_value)

                        # cropping the images again as specified by the user
                        strip_reg_image_avg_cropped   = strip_reg_image_avg[strip_cropping_ROI[0] : strip_cropping_ROI[1],
                                                                            strip_cropping_ROI[2] : strip_cropping_ROI[3]]

                        if profile:
                            start_time = time.clock()

                        # saving the frame sum map data to an ASCII file
                        #__save_frame_sum_map__( strip_sum_map_cropped, temp_file_name)

                        # saving the the averaged image data to an ASCII file and the contrasted TIFF
                        __save_image_as_TIFF__( strip_reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\SR_TIFs' + temp_file_name)
                        __save_image_as_ASCII__(strip_reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\SR_DATs' + temp_file_name)


                        if profile:
                            timing_dictionary['file_writing'] += time.clock() - start_time
                else:
                    return False, 'Failed to find a cropping area in the strip-registered image.', data
                    
                  

    
        # updating the progress bar every other frame
        if type(progress_bar) != type(None) and (acceptable_index % 2 == 0):
            wx.CallAfter(progress_bar.SetValue, int(100*(acceptable_index + 1)/n_acceptable_frames))

        # frame for loop END ##############################################


    # adding new data to the dictionary
    data['acceptable_frames']                              = acceptable_frames

    if full_frame_registration_required:
        data['full_frame_n_frames_with_highest_ncc_value'] = full_frame_n_frames_to_register
        data['full_frame_cropping_ROI_1']                  = full_frame_cropping_ROI_1
        data['full_frame_cropping_ROI_2']                  = full_frame_cropping_ROI_2
        data['full_frame_cropping_values']                 = full_frame_cropping_values

    if strip_registration_required:       
        data['strip_cropping_ROI_1']                       = strip_cropping_ROI_1
        data['strip_cropping_ROI_2']                       = strip_cropping_ROI_2
        data['strip_cropping_values']                      = strip_cropping_values
        data['strip_n_frames_with_highest_ncc_value']      = strip_n_frames_to_register

    if profile:
        data['register_sequence_timing']                   = timing_dictionary

    # returning dictionary
    return True, '', data

                        


###########################################################################
#                                                                         #
#                    REGISTERING SECONDARY SEQUENCES                      #
#                                                                         #
###########################################################################

def RegisterSecondaryImageSequence(sequence_path,
                                   sequence_name,
                                   batch_processor_tool_bag,
                                   data,
                                   progress_bar,
                                   profile):
    
    """This function takes a Python dictionary generated with the GUI
       wxDemotionCreateAndModifyBatchFile_settings, and produces the
       following outputs if required:

       - non-cropped registered images in 8-bit monochrome TIFF and
         single-precision ASCII files.

       - cropped registered images in 8-bit monochrome TIFF and
         single-precision ASCII files.

       - the corresponding frame sum maps in ASCII format using integers.

       Some of the calculation results, such as, ROI coordinates for
       cropping are added to the dictionary before returning it.
    """

    if profile:
        timing_dictionary = {}
        timing_dictionary['file_reading']  = 0
        timing_dictionary['file_writing']  = 0
        timing_dictionary['interpolating'] = 0

    #######################################################################
    #  Creating the desinusoider                                          #
    #######################################################################

    desinudoiding_required             = data['desinusoiding_required']
    fast_scanning_horizontal           = data['fast_scanning_horizontal']

    if desinudoiding_required:

        # initializing the desinusoider by passing the desinusoid matrix
        # and direction, rather than a Matlab desinusoid file. Note that
        # for desinusoiding single precision is more than enough.
        desinusoider                   = batch_processor_tool_bag.GenerateDeSinusoider(
                                         numpy_desinusoid_matrix = data['desinusoid_matrix'],
                                         horizontal_warping      = fast_scanning_horizontal,
                                         store_error             = True,
                                         precision               = 'single')

        # checking for errors when creating the desinusoider
        failed, error_msg, error_title = desinusoider.GetErrorMsg()
        if failed:
            return False, error_msg, data
    else:
        desinusoider                   = None
        

    #######################################################################
    #  Creating CUDA image readers (AVIs only for now)                    #
    #######################################################################

    # testing if the file can be found in the original path    
    success, correct_path               = __find_the_path__(sequence_path,
                                                            sequence_name,
                                                            data['batch_path'])

    if not success:
        return False, 'Could not find the AVI file in the original '    +\
                      'directory, the same directory but in the batch ' +\
                      'file drive or the batch file directory.', data

    # creating primary sequence reader 
    image_reader                       = batch_processor_tool_bag.GenerateImageReader(
                                         filename      = sequence_name,
                                         img_type      = 'avi',
                                         absolute_path = correct_path,
                                         precision     = 'single',
                                         store_error   = True)

    # checking for errors when creating the image reader
    failed, error_msg, error_title     = image_reader.GetErrorMsg()
    if failed:
        return False, error_msg, data

    # getting AVI info
    n_frames                           = image_reader.n_frames
    n_columns_raw                      = image_reader.n_columns
    n_rows_raw                         = image_reader.n_rows


    #######################################################################
    #   Getting full frame registration data from dictionary              #
    #######################################################################

    full_frame_registration_required        = data['save_full_frame_registered_image']
    
    strip_registration_required             = data['strip_registration_required'] and\
                                              data['save_strip_registered_image']

    # getting data from the dictionary
    full_frame_row_shifts                   = data['full_frame_ncc']['row_shifts']
    full_frame_column_shifts                = data['full_frame_ncc']['column_shifts']
    acceptable_frames                       = data['acceptable_frames']
    
    if full_frame_registration_required:
        full_frame_cropping_ROI_1           = data['full_frame_cropping_ROI_1']
        full_frame_cropping_ROI_2           = data['full_frame_cropping_ROI_2']
        full_frame_cropping_values          = data['full_frame_cropping_values']
        full_frame_n_frames_to_register     = data['full_frame_n_frames_with_highest_ncc_value']

    if strip_registration_required:
        strip_cropping_ROI_1                = data['strip_cropping_ROI_1']
        strip_cropping_ROI_2                = data['strip_cropping_ROI_2']
        strip_cropping_values               = data['strip_cropping_values']
        strip_n_frames_to_register          = data['strip_n_frames_with_highest_ncc_value']

    # sorting the list in increasing order
    full_frame_n_frames_to_register.sort()
    
    # exiting if there is only one frame to register (i.e. the reference)
    if type(acceptable_frames) == type(1):
        return False, 'Exiting the registration because there is only ' +\
                      'one acceptable frame.', data
    else:        
        n_acceptable_frames                 = len(acceptable_frames)


    #######################################################################
    #   Creating prefix for output file names                             #
    #######################################################################

    # creating first part of the filename (after removing the extension)
    output_files_prefix                     = '//' +\
                                              sequence_name[:len(sequence_name)-4] +\
                                              data['user_defined_suffix']

              
    #######################################################################
    #   Determining size of desinusoided registered uncropped image       #
    #######################################################################

    # getting the size of a single desinusoided single frame
    if desinudoiding_required:
        if fast_scanning_horizontal:
            initial_n_lines, final_n_lines = desinusoider.desinusoid_matrix.shape

            # defining the number of rows and columns values
            n_rows_desinusoided            = n_rows_raw
            n_columns_desinusoided         = final_n_lines
        else:
            final_n_lines, initial_n_lines = desinusoider.desinusoid_matrix.shape

            # defining the number of rows and columns values
            n_rows_desinusoided            = final_n_lines
            n_columns_desinusoided         = n_columns_raw
    else:
        # defining the number of rows and columns values
        n_rows_desinusoided                = n_rows_raw
        n_columns_desinusoided             = n_columns_raw

    # determining the size of the extended image
    full_frame_n_rows_reg_img              = n_rows_desinusoided                               +\
                                             max(full_frame_row_shifts    [acceptable_frames]) -\
                                             min(full_frame_row_shifts    [acceptable_frames])
    full_frame_n_columns_reg_img           = n_columns_desinusoided                            +\
                                             max(full_frame_column_shifts [acceptable_frames]) -\
                                             min(full_frame_column_shifts [acceptable_frames])

    # getting the offsets from the data structure
    full_frame_row_offset                  = data['full_frame_ncc']['row_offset']
    full_frame_column_offset               = data['full_frame_ncc']['column_offset']


    ###########################################################################
    #  Getting the interpolation curves and strip registered image size       #
    ###########################################################################

    strip_registration_required            = data['save_strip_registered_image'] and\
                                             data['strip_registration_required']

    # getting data from the dictionary
    if strip_registration_required:
        n_lines_per_strip                  = data['frame_strip_lines_per_strip']
        lines_between_strips_start         = data['frame_strip_lines_between_strips_start']
        strip_row_offset                   = data['strip_ncc']['row_offset']
        strip_column_offset                = data['strip_ncc']['column_offset']
        strip_interpolation_data           = data['sequence_interval_data_list']
        strip_n_rows_reg_img               = data['strip_ncc']['n_rows_reg_img']
        strip_n_columns_reg_img            = data['strip_ncc']['n_columns_reg_img']


    #######################################################################
    #   Creating matrices to store registered images                      #
    #######################################################################

    # creating matrices for the full frame registered image and the sum map
    if full_frame_registration_required:
        full_frame_reg_img                 = np.zeros((full_frame_n_rows_reg_img,
                                                       full_frame_n_columns_reg_img),
                                                       dtype = np.float32)

        full_frame_sum_map                 = np.zeros((full_frame_n_rows_reg_img,
                                                       full_frame_n_columns_reg_img),
                                                       dtype = np.float32)

    # creating matrices for the strip registered image and the sum map
    if strip_registration_required:

        strip_reg_img                      = np.zeros((strip_n_rows_reg_img,
                                                       strip_n_columns_reg_img),
                                                       dtype = np.float32)

        strip_sum_map                      = np.zeros((strip_n_rows_reg_img,
                                                       strip_n_columns_reg_img),
                                                      dtype = np.float32)

        n_pixels_to_interpolate            = strip_n_rows_reg_img * strip_n_columns_reg_img

        current_frame_desired_columns      = np.zeros((n_pixels_to_interpolate,), dtype = np.float32)
        current_frame_desired_rows         = np.zeros((n_pixels_to_interpolate,), dtype = np.float32)
        reference_frame_desired_columns    = np.zeros((n_pixels_to_interpolate,), dtype = np.int32)
        reference_frame_desired_rows       = np.zeros((n_pixels_to_interpolate,), dtype = np.int32)

        # creating auxiliary vectors for interpolation calculations
        row_indices                        = np.arange(n_rows_desinusoided   ,    dtype = np.int32)
        column_indices                     = np.arange(n_columns_desinusoided,    dtype = np.int32)


    #######################################################################
    #  Iterating through acceptable frames to generate registered images  #
    #######################################################################

    for acceptable_index in range(n_acceptable_frames):

        # getting the index of the frame in the sequence
        frame_index                       = acceptable_frames[acceptable_index]

        if profile:
            start_time = time.clock()

        # reading and desinusoiding primary sequence current frame
        success, current_frame, error_msg = __read_an_image__(
                                            frame_index            = frame_index,
                                            image_reader           = image_reader,
                                            desinusoider           = desinusoider,
                                            desinudoiding_required = desinudoiding_required)
        if profile:
            timing_dictionary['file_reading'] += time.clock() - start_time

        # exiting if finding any problems
        if not success:
            return success, error_msg, data


        ###############################################################
        #  Full frame image registration                              #
        ###############################################################

        if full_frame_registration_required:

            # updating the frame sum map
            full_frame_sum_map[full_frame_row_offset    - full_frame_row_shifts   [frame_index] :                           \
                               full_frame_row_offset    - full_frame_row_shifts   [frame_index] + n_rows_desinusoided,      \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] :                           \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] + n_columns_desinusoided] +=\
                               1                

            # adding the desinusoided image to the registered image
            full_frame_reg_img[full_frame_row_offset    - full_frame_row_shifts   [frame_index] :                           \
                               full_frame_row_offset    - full_frame_row_shifts   [frame_index] + n_rows_desinusoided,      \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] :                           \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] + n_columns_desinusoided] +=\
                               current_frame

        ###################################################################
        #   Strip registration                                            #
        ###################################################################

        if strip_registration_required:

            # generate an interpolation object for this frame
            interpolation_method = ''
            if strip_interpolation_order == 1:
                interpolation_method = 'linear'
            elif strip_interpolation_order == 3:
                interpolation_method = 'cubic'
                
            interpolator = batch_processor_tool_bag.GenerateInterpolator(interpolation_method, current_frame.shape)

            # getting the current frame intervals
            current_frame_intervals                 = strip_interpolation_data[acceptable_index]
            
            # iterating through each interval
            for current_frame_interval in current_frame_intervals:

                # initializing values that will be modified in each interval
                n_reference_lines_slow_axis         = len(current_frame_interval['slow_axis_pixels_in_reference_frame'])
                n_valid_pixels                      = 0

                # calculatign the integer and fractional parts of the fast axis shift
                line_fast_axis_shifts               = current_frame_interval['fast_axis_pixels_in_reference_frame_interpolated']
                line_fast_axis_shifts_integer       = np.floor(line_fast_axis_shifts)
                line_fast_axis_shifts_fractional    = line_fast_axis_shifts - line_fast_axis_shifts_integer

                # iterating through every line in the interval               
                for line_index in range(n_reference_lines_slow_axis):

                    # finding which of the pixels to interpolate fall within the (current) image
                    if fast_scanning_horizontal:
                        # Taking care of fractional pixel shifts
                        if line_fast_axis_shifts_fractional  [line_index] == 0:
                            line_start_index        = 0 
                            line_end_index          = n_columns_desinusoided
                        elif line_fast_axis_shifts_fractional[line_index]  > 0:
                            line_start_index        = 1 
                            line_end_index          = n_columns_desinusoided
                        else:
                            line_start_index        = 0
                            line_end_index          = n_columns_desinusoided - 1
                            
                        # coordinates of the reference pixels to calculate over the current frame 
                        current_frame_desired_rows     [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               current_frame_interval  ['slow_axis_pixels_in_current_frame_interpolated'][line_index]

                        current_frame_desired_columns  [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         column_indices[                 line_start_index :                  line_end_index]  \
                                       - line_fast_axis_shifts_fractional[line_index]

                        reference_frame_desired_rows   [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               + strip_row_offset\
                               + current_frame_interval['slow_axis_pixels_in_reference_frame'][line_index]
                       
                        reference_frame_desired_columns[n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         column_indices[                 line_start_index :                  line_end_index]  \
                               + strip_column_offset\
                               + line_fast_axis_shifts_integer[line_index]

                    else:
                        # Making sure we only calculate pixels within the current frame
                        if line_fast_axis_shifts_fractional  [line_index] == 0:
                            line_start_index        = 0 
                            line_end_index          = n_rows_desinusoided
                        elif line_fast_axis_shifts_fractional[line_index] > 0:
                            line_start_index        = 1 
                            line_end_index          = n_rows_desinusoided
                        else:
                            line_start_index        = 0
                            line_end_index          = n_rows_desinusoided - 1                          
                            
                        # coordinates of the distorted reference frame grid points over the current frame
                        current_frame_desired_rows     [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         row_indices   [                 line_start_index :                  line_end_index]\
                                       - line_fast_axis_shifts_fractional[line_index]
                        
                        current_frame_desired_columns  [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               current_frame_interval  ['slow_axis_pixels_in_current_frame_interpolated'][line_index]

                        # coordinates of the reference frame grid points
                        reference_frame_desired_rows   [n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                                         row_indices   [                 line_start_index :                  line_end_index]  \
                               + strip_row_offset\
                               + line_fast_axis_shifts_integer[line_index]
                       
                        reference_frame_desired_columns[n_valid_pixels + line_start_index : n_valid_pixels + line_end_index] =\
                               + current_frame_interval['slow_axis_pixels_in_reference_frame'][line_index]\
                               + strip_column_offset

                    # END of if fast_scanning_horizontal: #################

                   
                    # keeping track of the number of valid indices
                    n_valid_pixels                  = n_valid_pixels + line_end_index - line_start_index


                # END of for line_index loop ##############################

                if profile:
                    start_time = time.clock()

                # interpolating all the pixels at once. If order is 1, then
                # the interpolation is bilinear, cval, the "clamp" value,
                # is the value outside the current frame. Just in case, we
                # set the prefilter option to False.
                # linear interpolation using CUDA (~30x faster than scipy.ndimage.map_coordinates
                (interpolated_intensity_values, success)  = interpolator.MapCoordinatesFromNumpyArray(
                                                                    np.float32(current_frame),
                                                                    current_frame_desired_rows   [:n_valid_pixels],
                                                                    current_frame_desired_columns[:n_valid_pixels],
                                                                    0)
                if profile:
                    timing_dictionary['interpolating'] += time.clock() - start_time

                # placing the interpolated intensity values in the registered image                
                strip_reg_img   [reference_frame_desired_rows   [:n_valid_pixels],
                                 reference_frame_desired_columns[:n_valid_pixels]] += interpolated_intensity_values

                strip_sum_map   [reference_frame_desired_rows   [:n_valid_pixels],
                                 reference_frame_desired_columns[:n_valid_pixels]] += 1

            # END of for interval_index in range(current_frame_n_intervals): ######


        # checking if any number of desired frames has been reached
        if full_frame_registration_required and (full_frame_n_frames_to_register.count(acceptable_index + 1) > 0):

            full_frame_n_frames_to_save_index = full_frame_n_frames_to_register.index(acceptable_index + 1)

            ###############################################################
            # First full frame coarse cropping: removing zeros            #
            ###############################################################

            # recovering data from the dictionary
            min_row_crop, max_row_crop, min_column_crop, max_column_crop =\
                                          full_frame_cropping_ROI_1[full_frame_n_frames_to_save_index]

            # cropping the sum map to remove zero rows and columns
            full_frame_sum_map_cropped     = full_frame_sum_map[min_row_crop    : max_row_crop,
                                                                min_column_crop : max_column_crop]

            # cropping the full frame registered image to remove zero rows and columns
            full_frame_reg_img_cropped     = full_frame_reg_img[min_row_crop    : max_row_crop,
                                                                min_column_crop : max_column_crop]

            # dividing the image sum by the sum map to produce a registered image
            reg_image_avg                  = full_frame_reg_img_cropped /\
                                            (full_frame_sum_map_cropped + float32_eps)


            ###############################################################
            # Second full frame cropping: user entry                      #
            ###############################################################

            # recovering data from the dictionary
            min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                          full_frame_cropping_ROI_2[full_frame_n_frames_to_save_index]

            # cropping the sum map as specified by the user
            full_frame_sum_map_cropped   = full_frame_sum_map_cropped[min_row_crop2   : max_row_crop2,
                                                                      min_column_crop2: max_column_crop2]

            # cropping the images again as specified by the user
            reg_image_avg_cropped        = reg_image_avg[min_row_crop2   : max_row_crop2,
                                                         min_column_crop2: max_column_crop2]

            # creating the name for the output files
            temp_file_name               = output_files_prefix + '_ffr_n_' + str(acceptable_index + 1) +\
                                          '_cropped_' + str(full_frame_cropping_values[full_frame_n_frames_to_save_index])

            if profile:
                start_time = time.clock()

            # saving the the averaged image data to an ASCII file and the contrasted TIFF
            __save_image_as_TIFF__( reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\FFR_TIFs'+ temp_file_name)
            __save_image_as_ASCII__(reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\FFR_DATs'+ temp_file_name)

            if profile:
                timing_dictionary['file_writing'] += time.clock() - start_time

        # checking if any number of desired frames has been reached        
        if strip_registration_required and (strip_n_frames_to_register.count(acceptable_index + 1) > 0):

            strip_n_frames_to_save_index = strip_n_frames_to_register.index(acceptable_index + 1)

    
            ###############################################################
            # First full frame coarse cropping: removing zeros            #
            ###############################################################

            # recovering data from the dictionary
            min_row_crop, max_row_crop, min_column_crop, max_column_crop =\
                                          strip_cropping_ROI_1[strip_n_frames_to_save_index]

            # cropping the sum map to remove zero rows and columns
            strip_sum_map_cropped        = strip_sum_map[min_row_crop    : max_row_crop,
                                                         min_column_crop : max_column_crop]

            # cropping the full frame registered image to remove zero rows and columns
            strip_reg_img_cropped        = strip_reg_img[min_row_crop    : max_row_crop,
                                                         min_column_crop : max_column_crop]

            # dividing the image sum by the sum map to produce a registered image
            strip_reg_image_avg          = strip_reg_img_cropped /\
                                          (strip_sum_map_cropped + float32_eps)


            ###############################################################
            # Second full frame cropping: user entry                      #
            ###############################################################

            # recovering data from the dictionary
            min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                          strip_cropping_ROI_2[strip_n_frames_to_save_index]
                
            # creating the name for the output files
            temp_file_name               = output_files_prefix + '_sr_n_' + str(acceptable_index + 1) +\
                                         '_cropped_' + str(strip_cropping_values[strip_n_frames_to_save_index])

            # cropping the images again as specified by the user
            strip_reg_image_avg_cropped  = strip_reg_image_avg[min_row_crop2   : max_row_crop2,
                                                                  min_column_crop2: max_column_crop2]

            # saving the the averaged image data to an ASCII file and the contrasted TIFF
            __save_image_as_TIFF__( strip_reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\SR_TIFs'+  temp_file_name)
            __save_image_as_ASCII__(strip_reg_image_avg_cropped, os.path.dirname(correct_path) +'\\Processed\\SR_DATs'+ temp_file_name)

                      
        # updating the progress bar every other frame
        if type(progress_bar) != type(None) and (acceptable_index % 2 == 0):
            wx.CallAfter(progress_bar.SetValue, int(100*(acceptable_index + 1)/n_acceptable_frames))

            # frame for loop END ##############################################


    if profile:
        data['register_secondary_timing'] = timing_dictionary

    # returning dictionary
    return True, '', data




###########################################################################
#  reading and desinusoiding a single image                               #
###########################################################################

def __read_an_image__(frame_index,
                      image_reader,
                      desinusoider,
                      desinudoiding_required):

    """
    """

    if desinudoiding_required:

        # reading current AVI frame to a CUDA buffer
        image_reader.ReadImageToOutputBuffer(frame_index)

        # calculating the desinusoided matrix
        desinusoider.CalculateDeSinusoidedMatrix(image_reader.output_buffer)

        # checking for errors when desinusoiding the current frame
        failed, error_msg, error_title = desinusoider.GetErrorMsg()

        if failed:
            return False, None, error_msg

        # copying the desinusoided image in a numpy array
        current_frame = desinusoider.GetOutputMatrixAsNumpyArray()

    else:
        # reading the AVI frame directly to a numpy array
        current_frame = image_reader.ReadImageToNumpyBuffer(frame_index)

    # returning the image
    return True, current_frame, ''




###########################################################################
#  Determining acceptable frames                                          #
###########################################################################

def __determine_acceptable_frames__(full_frame_row_shifts,
                                    full_frame_column_shifts,
                                    full_frame_max_displacement_threshold,
                                    full_frame_ncc_max_values,
                                    max_n_full_frames_to_register):

    """Acceptable frames are those in which the estimated full frame motion
       is smaller than the maximum displacement threshold entered by the
       user. Within those frames, only the ones with highest normalized
       cross-correlation (ncc) values will be used in what follows.
    """

    # finding the maximum row/column displacement of every frame
    max_displacements                       = np.maximum(np.absolute(full_frame_row_shifts),
                                                         np.absolute(full_frame_column_shifts))

    # finding the frames with acceptable displacements. Note: the [0] is
    #  because the nonzero function returns a tuple with an array in it
    acceptable_frames_based_on_displacement = np.nonzero(max_displacements <=\
                                                 full_frame_max_displacement_threshold)[0]
            
    # finding the indices of the frames with higher ncc values within those
    # with acceptable displacements
    temp_frame_indices                      = (full_frame_ncc_max_values\
                                               [acceptable_frames_based_on_displacement]).argsort()

    # this is a bit confusing, but it does the job. First we only select
    # the frames with acceptable displacements, sorted based on increasing
    # ncc value (hence the [temp_indices]), then we invert the order, to
    # make is decreasing (hence the [::-1]), and finally, we select the
    # first N frames

    n_acceptable_frames                     = min(len(temp_frame_indices), max_n_full_frames_to_register)
    acceptable_frames                       = acceptable_frames_based_on_displacement\
                                                  [temp_frame_indices][ : : -1][ : n_acceptable_frames]

    return acceptable_frames




###########################################################################
#  Calculating the interpolation curves and strip registered image size   #
###########################################################################

def __calculate_strip_interpolation_curves__(acceptable_frames,
                                             data_strip_ncc,
                                             data_full_frame_ncc,
                                             data_strip_max_displacement_threshold,
                                             data_frame_strip_ncc_threshold,
                                             fast_scanning_horizontal,
                                             mininum_n_strips_per_group,
                                             strip_DCT_terms_retained_percentage):

    """
    """
    
    frame_interval_list                         = []

    for frame_index in acceptable_frames:

        # getting data from dictionary
        current_frame_ncc_values                = data_strip_ncc['ncc_max_values'][frame_index]

        if fast_scanning_horizontal:
            strip_shifts_along_slow_axis        = data_strip_ncc['row_shifts']   [frame_index]
            strip_shifts_along_fast_axis        = data_strip_ncc['column_shifts'][frame_index]
        else:
            strip_shifts_along_slow_axis        = data_strip_ncc['column_shifts'][frame_index]
            strip_shifts_along_fast_axis        = data_strip_ncc['row_shifts']   [frame_index]


        ###############################################################
        # creating groups of contiguous acceptable strips             #
        ###############################################################

        # determining indices of acceptable strips in current frame,
        # based on max NCC value and shift wrt reference frame
        current_frame_acceptable_strip_indices  = np.nonzero(
                                                 (abs(strip_shifts_along_slow_axis) <       data_strip_max_displacement_threshold) *\
                                                 (abs(strip_shifts_along_fast_axis) <       data_strip_max_displacement_threshold) *\
                                                     (current_frame_ncc_values      > float(data_frame_strip_ncc_threshold)))[0]

        current_frame_n_acceptable_strips       = len(current_frame_acceptable_strip_indices)

        # finding groups of consecutive strips
        if len(current_frame_acceptable_strip_indices) > mininum_n_strips_per_group:

             # getting strips coordinates along the strip narrow dimension
             # getting strips coordinates along the strip narrow dimension
            if fast_scanning_horizontal:
                current_frame_strip_starts      = 1.0 * data_strip_ncc['strip_top_rows']     [frame_index]
                current_frame_strip_ends        = 1.0 * data_strip_ncc['strip_bottom_rows']  [frame_index]
            else:
                current_frame_strip_starts      = 1.0 * data_strip_ncc['strip_left_columns'] [frame_index]
                current_frame_strip_ends        = 1.0 * data_strip_ncc['strip_right_columns'][frame_index]

            # averaging to get the strip centers    
            current_frame_strip_centers         = (current_frame_strip_starts + current_frame_strip_ends)/2.0

            # grouping the contiguous strips 
            current_frame_groups_of_strips      = __find_groups_of_consecutive_strips__(
                                                  strip_indices          = current_frame_acceptable_strip_indices,
                                                  min_n_strips_per_group = mininum_n_strips_per_group)

            # finding number of contiguous strip groups in the current frame
            current_frame_n_groups              = len(current_frame_groups_of_strips)


            ###############################################################
            #  Performing DCT interpolation over each monotonic interval  #
            ###############################################################

            current_frame_n_intervals                            =  0
            current_frame_interval_data_list                     = []
            figure_index                                         =  1

            # iterating through the strip groups
            for current_strip_group_indices in current_frame_groups_of_strips:
                
                # calculating the interpolation coefficients
                DCT_shift_interpolator_slow_axis                 = DCTInterpolator.DCTInterpolator()
                DCT_shift_interpolator_slow_axis.Calculate_DCT_coefficients(
                                                                   current_frame_strip_centers [current_strip_group_indices],
                                                                   strip_shifts_along_slow_axis[current_strip_group_indices])

                # generating vector with indices of lines required for interpolation
                slow_axis_pixels_in_current_frame                = np.arange(current_frame_strip_starts[current_strip_group_indices].min(),
                                                                             current_frame_strip_ends  [current_strip_group_indices].max())

                # deciding how many terms to retain in the interpolation
                n_strips_in_group                                = len(current_strip_group_indices)
                n_DCT_terms_retained                             = int(n_strips_in_group * strip_DCT_terms_retained_percentage/100.0)

                shifts_along_slow_axis_interpolated              = DCT_shift_interpolator_slow_axis.Interpolate(
                                                                   slow_axis_pixels_in_current_frame,
                                                                   n_DCT_terms_retained)

                # calculating where in the reference frame do the lines of the current frame fall
                slow_axis_pixels_in_reference_frame_interpolated = slow_axis_pixels_in_current_frame\
                                                                 - shifts_along_slow_axis_interpolated

                # finding limits of strictly increasing monotonic intervals in the interpolated values
                interval_start_indices, interval_end_indices     = FindExtremesOfMonotonicIntervals.\
                                                                   FindExtremesOfIncreasingMonotonicIntervals(
                                                                   slow_axis_pixels_in_reference_frame_interpolated)

                #####################################################################
                # TODO: we might want to reduce the intervals further by excluding  #
                #       points with very high or low slopes. These would correspond #
                #       to parts of the image that are too streched or compressed.  #
                #####################################################################

                current_group_n_monotonic_intervals              = len(interval_start_indices)


                #######################################################################    
                # separating the data in monotonic intervals                          #
                #######################################################################
                
                for interval_index in range(current_group_n_monotonic_intervals):

                    # calculating new set points, which is the inverted version of the
                    # we have just interpolated over the current interval. Note that
                    # this needs to be done within a monotonic interval so that the
                    # curve is invertible. This step would not be needed if 2D
                    # interpolation over an irregular grid was not so mathematically
                    # complex... This will not change any time soon, so don't try to be
                    # smart and keep this part of the code as is.

                    # note that we add one because the index will be the last of a range

                    # note that we add one because the index will be the last of a range
                    interval_first_pixel                     = interval_start_indices[interval_index]
                    interval_last_pixel                      = interval_end_indices  [interval_index] + 1

                    # generated using np.arange
                    interval_slow_axis_pixels_in_current_frame                = \
                                                   slow_axis_pixels_in_current_frame    \
                                                   [interval_first_pixel : interval_last_pixel]

                    # generated using the DCT interpolation
                    interval_shifts_along_slow_axis_interpolated              = \
                                                   shifts_along_slow_axis_interpolated  \
                                                   [interval_first_pixel : interval_last_pixel]

                    interval_slow_axis_pixels_in_reference_frame_interpolated =            \
                                                   slow_axis_pixels_in_reference_frame_interpolated\
                                                   [interval_first_pixel : interval_last_pixel]

                    # equally spaced points in the reference frame, over which the
                    # distorted current frame will be evaluated (must be Numpy array).
                    # The ceil and floor ensure that we remain within the current frame
                    interval_slow_axis_pixels_in_reference_frame              = np.arange(\
                                                   int(np.ceil( min(interval_slow_axis_pixels_in_reference_frame_interpolated))),
                                                   int(np.floor(max(interval_slow_axis_pixels_in_reference_frame_interpolated))))


                    linear_interpolator                                       = interpolate.interp1d(
                                                   interval_slow_axis_pixels_in_reference_frame_interpolated,
                                                   interval_slow_axis_pixels_in_current_frame,
                                                   kind = 'linear')
                    interval_slow_axis_pixels_in_current_frame_interpolated   =\
                                                   linear_interpolator(interval_slow_axis_pixels_in_reference_frame)

                    # interpolating along the fast axis
                    DCT_shift_interpolator_fast_axis                          = DCTInterpolator.DCTInterpolator()

                    DCT_coeffs_fast_axis                                      = DCT_shift_interpolator_fast_axis.\
                                                   Calculate_DCT_coefficients(
                                                   current_frame_strip_centers [current_strip_group_indices],
                                                 -  strip_shifts_along_fast_axis[current_strip_group_indices])

                    interval_fast_axis_pixels_in_reference_frame_interpolated = \
                                                   DCT_shift_interpolator_fast_axis.Interpolate(
                                                   interval_slow_axis_pixels_in_current_frame_interpolated,
                                                   n_DCT_terms_retained)

                    # creating a dictionary with the data
                    if len(interval_slow_axis_pixels_in_reference_frame) > 0:
                        monotonic_interval                                        = \
                                 {'frame_index'                                      : frame_index,                                               # frame
                                  'group_strip_indices'                              : current_strip_group_indices,                               # group of strips
                                  'slow_axis_pixels_in_current_frame_interpolated'   : interval_slow_axis_pixels_in_current_frame_interpolated,   # monotonic interval within group of strips
                                  'slow_axis_pixels_in_reference_frame'              : interval_slow_axis_pixels_in_reference_frame,              # monotonic interval within group of strips
                                  'fast_axis_pixels_in_reference_frame_interpolated' : interval_fast_axis_pixels_in_reference_frame_interpolated} # monotonic interval within group of strips

                        # adding the interval data to the list
                        current_frame_interval_data_list.append(dict(monotonic_interval))

                    # end of monotonic interval loop ##################
                # end of group of contiguous strips ###############

            # adding current frame intervals to the list (only acceptable frames)
            frame_interval_list.append(list(current_frame_interval_data_list))
        else:
            # adding empty list when the number of acceptable strips is below the minimum
            frame_interval_list.append([])
            

    return frame_interval_list
        



###########################################################################
#  Finding the largest rectangle within a binary cropping mask (arguably) #
###########################################################################

def __find_max_area_cropping_rectangle__(cropping_mask, fast_scanning_horizontal):

    """
    """

    if fast_scanning_horizontal:
        cropping_mask = cropping_mask.transpose()        
        

    # NOTE: this algorithm is based on the hypothesis that the cropping
    #       mask is formed by either a single large contiguous lump or by
    #       multiple vertical bands.

    #######################################################################
    # finding the ROI that does not have null rows or columns             #
    #######################################################################

    # NOTE: ignoring squares with less than 10 pixels in height, just to
    #       ignore those single pixel artifacts. TODO fix this!!!!
    # MOD:AES:20200310: Changed min_n_pixels from 10 to 2, haven't tested whether this fixes it or not, but I haven't
    # seen any issues yet
    min_n_pixels                   = 2

    # finding the limits of the ROI to crop
    cropped_row_indices            = np.nonzero(cropping_mask.sum(1) >= min_n_pixels)[0]
    cropped_column_indices         = np.nonzero(cropping_mask.sum(0) >= min_n_pixels)[0]

    # returning False if the ROI is empty or a line
    if (len(cropped_row_indices) <= min_n_pixels) or (len(cropped_column_indices) <= min_n_pixels):
        return False, []

    areas_left_columns             = [cropped_column_indices[0]]
    areas_right_columns            = []
    areas_n_pixels                 = []

    # finding contiguous areas
    for temp_index in range(1, len(cropped_column_indices)):

        if cropped_column_indices[temp_index] - cropped_column_indices[temp_index - 1] > 1:
            areas_right_columns.append(cropped_column_indices[temp_index - 1])
            areas_left_columns.append( cropped_column_indices[temp_index    ])

    # dealing with the last element            
    areas_right_columns.append(cropped_column_indices[len(cropped_column_indices) - 1])




    # calculating how many pixels in each
    for temp_index in range(len(areas_left_columns)):                                       
        areas_n_pixels.append(cropping_mask[:,areas_left_columns [temp_index] : \
                                              areas_right_columns[temp_index]].sum())
                                       
    # finding the index of the largest area
    largest_area_index             = np.array(areas_n_pixels).argmax()
                                       
    min_row_crop                   = cropped_row_indices[0]
    max_row_crop                   = cropped_row_indices[len(cropped_row_indices)    - 1]
    min_column_crop                = areas_left_columns [largest_area_index]
    max_column_crop                = areas_right_columns[largest_area_index]

    cropping_mask                  = cropping_mask[min_row_crop    : max_row_crop,
                                                   min_column_crop : max_column_crop]

    # finding the mask dimensions
    n_rows, n_columns              = cropping_mask.shape

    if (n_rows == 0) or (n_columns == 0):
        return False, []

    # creating empty arrays
    ROI_1                          = np.zeros((n_columns, 4), dtype = np.int32)
    ROI_2                          = np.zeros((n_columns, 4), dtype = np.int32)
    ROI_1_areas                    = np.zeros((n_columns,),   dtype = np.int32)
    ROI_2_areas                    = np.zeros((n_columns,),   dtype = np.int32)

    # casting the cropping mask to uint8 (it does not work with booleans)
    cropping_mask                  = np.uint8(cropping_mask)
    
    # iterating through all the columns
    for column_index in range(n_columns):
        
        # step 1: finding the "top" perimeter        
        temp_indices               = np.nonzero(cropping_mask[:,column_index])[0]
        top_row                    = temp_indices[0]

        # step 2: estimating the area of the rectangles fully contained
        #         in the > 0 area of the frame sum map.
        
        # finding the bottom of the left side
        temp_indices_2             = np.nonzero(cropping_mask[top_row : n_rows,
                                                              column_index] == 0)[0]
        if len(temp_indices_2) > 0:
            bottom_row             = top_row + temp_indices_2[0] - 1
        else:
            bottom_row             = n_rows - 1
            
        # finding the top right corner
        temp_indices_3             = np.nonzero(cropping_mask[top_row,
                                                              column_index : n_columns] == 0)[0]
        if len(temp_indices_3) > 0:
            right_column           = column_index + temp_indices_3[0] - 1
        else:
            right_column           = n_columns - 1
                   
       # finding the bottom right corner: starting fromt the bottom left corner
        temp_indices_4             = np.nonzero(cropping_mask[bottom_row,
                                                              column_index : n_columns] == 0)[0]
        if len(temp_indices_4) > 0:
            right_column_from_left = column_index + temp_indices_4[0] - 1
        else:
            right_column_from_left = n_columns - 1

       # finding the bottom right corner: starting fromt the top right corner
        temp_indices_5             = np.nonzero(cropping_mask[top_row : bottom_row,
                                                              right_column] == 0)[0]
        if len(temp_indices_5) > 0:
            bottom_row_from_top    = top_row + temp_indices_5[0] - 1
        else:
            bottom_row_from_top    = bottom_row - 1

        # the coords are as follows: min_row, max_row, min_column, max_column
        ROI_1[column_index,:]      = [min_row_crop    + top_row      + 1, min_row_crop    + bottom_row,
                                      min_column_crop + column_index + 1, min_column_crop + min(right_column, right_column_from_left)]
        ROI_2[column_index,:]      = [min_row_crop    + top_row      + 1, min_row_crop    + min(bottom_row,   bottom_row_from_top),
                                      min_column_crop + column_index + 1, min_column_crop + right_column]

        ROI_1_areas[column_index]  = abs(ROI_1[column_index, 1] - ROI_1[column_index, 0]) \
                                   * abs(ROI_1[column_index, 2] - ROI_1[column_index, 3])
        ROI_2_areas[column_index]  = abs(ROI_2[column_index, 1] - ROI_2[column_index, 0]) \
                                   * abs(ROI_2[column_index, 2] - ROI_2[column_index, 3])

        # end of for loop #################################################

    # finding the index of the ROI with the maximum area
    max_index_1                    = ROI_1_areas.argmax()
    max_index_2                    = ROI_2_areas.argmax()


    if ROI_1_areas[max_index_1] > ROI_2_areas[max_index_2]:
        ROI_output = ROI_1[max_index_1, :].tolist()
    else:
        ROI_output = ROI_2[max_index_2, :].tolist()
    

    # returning the ROI coordinates
    if fast_scanning_horizontal:
        # "transposing the ROI
        return True, [ROI_output[2], ROI_output[3], ROI_output[0], ROI_output[1]]
    else:
        return True, ROI_output



    
###########################################################################
#  Saving an image as a constrast stretched TIFF and as ASCII file        #
###########################################################################

def __save_image_as_ASCII__(reg_image_np_array, temp_file_name):

    """Internal function for saving an image in TIFF and ASCII formats. The
       input must be a numpy array. 
    """
    # First check to see if the dir exists- for new version, I would make this
    # a function...
    d = os.path.dirname(temp_file_name)
    if not os.path.exists(d):
        os.makedirs(d)
    
    # saving registered image to an ASCII file
    f                            = open(temp_file_name + '.dat' , 'w')

    for row_index in range(reg_image_np_array.shape[0]):
        reg_image_np_array[row_index,:].tofile(f, sep = "\t", format = "%s")
        f.write('\n')
    f.close()



###########################################################################
#  Saving an image as a constrast stretched TIFF and as ASCII file        #
###########################################################################

def __save_image_as_TIFF__(reg_image_np_array, temp_file_name):

    """Internal function for saving an image in TIFF and ASCII formats. The
       input must be a numpy array. 
    """
    # First check to see if the dir exists- for new version, I would make this
    # a function...
    d = os.path.dirname(temp_file_name)
    if not os.path.exists(d):
        os.makedirs(d)
    
    # stretching contrast just enough to avoid saturation
    reg_image_np_array      -= reg_image_np_array.min()
    reg_image_np_array       = 255 * (1.0 * reg_image_np_array) / reg_image_np_array.max()
    
    # converting to a Python Image Library (PIL) object
    reg_img_tiff             = Image.fromarray(np.uint8(reg_image_np_array))

    # saving the image
    reg_img_tiff.save(temp_file_name + '.tif')


    
###########################################################################
#  Saving a frame sum map as an ASCII file                                #
###########################################################################

def __save_frame_sum_map__(sum_map_np_array, temp_file_name):

    """Internal function for saving a frame sum map and an image in TIFF
       and ASCII formats.
    """
    # First check to see if the dir exists- for new version, I would make this
    # a function...
    d = os.path.dirname(temp_file_name)
    if not os.path.exists(d):
        os.makedirs(d)
    
    # saving frame sum map to an ascii file
    f                            = open(temp_file_name + '_sum_map.dat', 'w')

    for row_index in range(sum_map_np_array.shape[0]):
        sum_map_np_array[row_index,:].tofile(f, sep = "\t", format = "%s")
        f.write('\n')
    f.close()



###########################################################################
#  Finding groups of consecutive strips                                   #
###########################################################################

def __find_groups_of_consecutive_strips__(strip_indices, min_n_strips_per_group):

    """This function returns a list of lists each of which contains
       a group of consecutive indices in increasing order. It is assumed
       that there are no repeated indices.
    """

    # sorting the list in increasing order (in principle this is not
    # needed, but just in case)
    strip_indices.sort()
    
    # getting the number of strips
    n_strips                 = len(strip_indices)
    
    # initializing list of groups
    strip_groups             = []
    current_group            = []
    
    # initializing current group with first index
    current_group            = [strip_indices[0]]

    # iterating through the remaining strips         
    for strip_index in range(1, n_strips):
        
        # reading strip indices
        previous_strip_index = strip_indices[strip_index - 1]
        current_strip_index  = strip_indices[strip_index]

        # is this strip contiguous with the previous one?
        contiguous           = (current_strip_index - previous_strip_index == 1)

        # if not, we have reached the end of a group
        if not contiguous:
            
            # only keeping groups with adequate number of strips
            if len(current_group) >= min_n_strips_per_group:
                strip_groups.append(current_group)

            # reinitializing the current group
            current_group    = []

       # adding the previous strip index to the sub-frame
        current_group.append(current_strip_index)

    # dealing with the last sub-frame    
    if len(current_group) >= min_n_strips_per_group:
        strip_groups.append(current_group)

    # returning the list of strip groups
    return strip_groups



###########################################################################
#  Auxiliary class for determining the size of the strip-registered image #
###########################################################################

def __determine_strip_registered_image_size__(sequence_interval_data_list,
                                              fast_scanning_horizontal,
                                              acceptable_frames,
                                              n_rows_desinusoided,
                                              n_columns_desinusoided):

    """
    """

    # initializing lists
    slow_axis_min                  = []
    slow_axis_max                  = []
    fast_axis_min                  = []
    fast_axis_max                  = []

    # iterating through acceptable frames
    for acceptable_frame_index in range(len(acceptable_frames)):

        # iterating through all the intervals in the current frame
        for current_interval in sequence_interval_data_list[acceptable_frame_index]:
            
            slow_axis_min.append(min(current_interval['slow_axis_pixels_in_reference_frame']))
            slow_axis_max.append(max(current_interval['slow_axis_pixels_in_reference_frame']))
            fast_axis_min.append(min(current_interval['fast_axis_pixels_in_reference_frame_interpolated']))
            fast_axis_max.append(max(current_interval['fast_axis_pixels_in_reference_frame_interpolated']))

    # returning zero size if there is not at least one valid interval
    if len(slow_axis_min) == 0:
        return 0, 0, 0, 0
    
    slow_axis_min                  =   min(slow_axis_min)
    slow_axis_max                  =   max(slow_axis_max)
    fast_axis_min                  =   min(fast_axis_min)
    fast_axis_max                  =   max(fast_axis_max)

    if fast_scanning_horizontal:
        # getting the offsets
        row_offset                 = - int(slow_axis_min)
        column_offset              = - int(fast_axis_min)

        # finding the image size                    
        n_rows_stabilized_image    =   int(np.floor(slow_axis_max) - np.ceil(slow_axis_min)) + 1
        n_columns_stabilized_image =   int(np.floor(fast_axis_max) - np.ceil(fast_axis_min)) + n_columns_desinusoided

    else:            
        # getting the offsets
        row_offset                 = - int(fast_axis_min)
        column_offset              = - int(slow_axis_min)

        # finding the image size                    
        n_rows_stabilized_image    =   int(np.floor(fast_axis_max) - np.ceil(fast_axis_min)) + n_rows_desinusoided 
        n_columns_stabilized_image =   int(np.floor(slow_axis_max) - np.ceil(slow_axis_min)) + 1

    # returning image size and offsets
    return n_rows_stabilized_image, n_columns_stabilized_image, row_offset, column_offset



###########################################################################
#  Auxiliary function for finding the path                                #
###########################################################################

def __find_the_path__(original_path, original_file_name, batch_path):

    """
    """

    # is the file in the original location?
    file_in_original_location        = os.path.exists(original_path + '\\' + original_file_name)

    if file_in_original_location:

        # if so, return the original path
        return True, original_path

    else:
        # if not, try the batch file drive
        batch_file_drive, not_used   = os.path.splitdrive(batch_path)
        not_used, tail_original_file = os.path.splitdrive(original_path + '\\' + original_file_name)
        file_in_batch_drive          = os.path.exists(batch_file_drive + tail_original_file)

        if file_in_batch_drive:
            image_sequence_absolute_path, image_sequence_file_name =\
                                          os.path.split(batch_file_drive + tail_original_file)

            return True, image_sequence_absolute_path
        else:
            # finally, trying the directory where the batch file currently is
            if os.path.exists(batch_path + '\\' + original_file_name):
                return True, batch_path
            else:
                return False, ''

