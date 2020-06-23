# DeMotion: registration module that outputs cropped and uncroppend
#           registered sequences in uncompressed monochrome AVI format.
#
#
# Alf Dubra (adubra@cvs.rochester.edu) and Zach Harvey (zgh7555@gmail.com)
# University of Rochester
# March 2010
# MOD:AES:20200310:RegisterImageSequenceOutputSequence: Changed order of frames added to sequence to match the order
# added to the image


# loading general modules
import cPickle, wx, os
import numpy as np
import time

# loading our modules
import  AVIReaderWriter

# creating global variables
strip_interpolation_order = 3

# only loading module if needed
if strip_interpolation_order > 1:
    from scipy import ndimage



def RegisterImageSequenceOutputSequence(sequence_path,
                                        sequence_name,
                                        data,
                                        batch_processor_tool_bag,
                                        progress_bar,
                                        profile):
    
    """This function takes a Python dictionary generated with the GUI
       wxDemotionCreateAndModifyBatchFile_settings, and then processed
       RegisterImageSequenceOutputImages function from the
       DemotionRegistrationOutputImages module. The function outputs are
       registered image sequences.
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

    # TODO: if we were to modify this to process data from the backscanning,
    # then most likely the only required change would be to use a  different
    # desinusoiding file. But it probably requires more than just that...

    desinudoiding_required                 = data['desinusoiding_required']
    fast_scanning_horizontal               = data['fast_scanning_horizontal']

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
        failed, error_msg, error_title     = desinusoider.GetErrorMsg()
        if failed:
            return False, error_msg, data
    else:
        desinusoider                       = None
        

    #######################################################################
    #  Creating CUDA image (AVI) reader(s)                                # 
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
    image_reader                              = batch_processor_tool_bag.GenerateImageReader(
                                                  filename      = sequence_name,
                                                  img_type      = 'avi',
                                                  absolute_path = correct_path,
                                                  precision     = 'single',
                                                  store_error   = True)

    # checking for errors when creating the image reader
    failed, error_msg, error_title         = image_reader.GetErrorMsg()
    if failed:
        return False, error_msg, data

    # getting AVI info
    n_frames                               = image_reader.n_frames
    n_columns_raw                          = image_reader.n_columns
    n_rows_raw                             = image_reader.n_rows


    #######################################################################
    #   Getting full frame registration data from dictionary              #
    #######################################################################

    full_frame_registration_required        = data['save_full_frame_registered_sequence']
    
    strip_registration_required             = data['strip_registration_required'] and\
                                              data['save_strip_registered_sequence']

    # getting data from the dictionary
    full_frame_row_shifts                   = data['full_frame_ncc']['row_shifts']
    full_frame_column_shifts                = data['full_frame_ncc']['column_shifts']
    acceptable_frames                       = data['acceptable_frames']

    if full_frame_registration_required:
        full_frame_cropping_ROI_1           = data['full_frame_cropping_ROI_1']
        full_frame_cropping_ROI_2           = data['full_frame_cropping_ROI_2']
        full_frame_cropping_values          = data['full_frame_cropping_values']
        full_frame_n_frames_to_register     = data['full_frame_n_frames_with_highest_ncc_value']

        # sorting the list in increasing order
        full_frame_n_frames_to_register.sort()

    if strip_registration_required:
        strip_cropping_ROI_1                = data['strip_cropping_ROI_1']
        strip_cropping_ROI_2                = data['strip_cropping_ROI_2']
        strip_cropping_values               = data['strip_cropping_values']
        strip_n_frames_to_register          = data['strip_n_frames_with_highest_ncc_value']

    
    # exiting if there is only one frame to register (i.e. the reference)
    if type(acceptable_frames) == type(1):
        return False, 'Exiting the registration because there is only ' +\
                      'one acceptable frame.', data
    else:        
        n_acceptable_frames                 = len(acceptable_frames)


    #######################################################################
    #   Creating output file names                                        #
    #######################################################################

       
    # creating first part of the filename (after removing the extension)
    output_files_prefix           = '\\' +\
                                    sequence_name[:len(sequence_name) - 4] +\
                                    data['user_defined_suffix']


    ########################################################################
    #   Determining size of desinusoided image                             #
    ########################################################################

    # getting the size of a single desinusoided single frame
    if desinudoiding_required:
    
        # priming the desinusoider
        success, current_frame, error_msg = __read_an_image__(
                                    frame_index            = 0,
                                    image_reader           = image_reader,
                                    desinusoider           = desinusoider,
                                    desinudoiding_required = desinudoiding_required)
    
        if fast_scanning_horizontal:
            initial_n_lines, final_n_lines = desinusoider.GetOutputMatrixShape()

            # defining the number of rows and columns values
            n_rows_desinusoided            = n_rows_raw
            n_columns_desinusoided         = final_n_lines
        else:
            final_n_lines, initial_n_lines = desinusoider.GetOutputMatrixShape()

            # defining the number of rows and columns values
            n_rows_desinusoided            = final_n_lines
            n_columns_desinusoided         = n_columns_raw
    else:
        # defining the number of rows and columns values
        n_rows_desinusoided                = n_rows_raw
        n_columns_desinusoided             = n_columns_raw


    # determining the size of the extended image
    n_rows_full_frame_reg_img              = n_rows_desinusoided                               +\
                                             max(full_frame_row_shifts    [acceptable_frames]) -\
                                             min(full_frame_row_shifts    [acceptable_frames])
    n_columns_full_frame_reg_img           = n_columns_desinusoided                            +\
                                             max(full_frame_column_shifts [acceptable_frames]) -\
                                             min(full_frame_column_shifts [acceptable_frames])

    # calculating fixed offsets for all frames   
    full_frame_row_offset                  = data['full_frame_ncc']['row_offset']
    full_frame_column_offset               = data['full_frame_ncc']['column_offset']


    ###########################################################################
    #  Getting the interpolation curves and strip registered image size       #
    ###########################################################################

    # getting data from the dictionary
    if strip_registration_required:
        n_lines_per_strip                  = data['frame_strip_lines_per_strip']
        lines_between_strips_start         = data['frame_strip_lines_between_strips_start']
        strip_row_offset                   = data['strip_ncc']['row_offset']
        strip_column_offset                = data['strip_ncc']['column_offset']
        strip_interpolation_data           = data['sequence_interval_data_list']

        # TODO: recalculate when dealing with back scan images
        strip_n_rows_reg_img               = data['strip_ncc']['n_rows_reg_img']
        strip_n_columns_reg_img            = data['strip_ncc']['n_columns_reg_img']


    ########################################################################
    #   Creating full frame registration AVI writers                       #
    ########################################################################

    if full_frame_registration_required:

        # creating extended frame for full frame registered movie
        full_frame_reg_seq                 = np.zeros((n_rows_full_frame_reg_img,
                                                       n_columns_full_frame_reg_img),
                                                       dtype = np.float32)

        # creating an empty list of avi writers
        list_of_full_frame_reg_avi_writers = []

        # initializing the AVI writers
        for avi_index in range(len(full_frame_n_frames_to_register)):
            
            # getting the size of the cropped frame
            min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                            full_frame_cropping_ROI_2[avi_index]
            
            # First check to see if the dir exists- for new version, I would make this
            # a function...
            d = os.path.dirname(correct_path) +'\\Processed\\FFR_AVIs'
            if not os.path.exists(d):
                os.makedirs(d)
                
            # creating a new AVI file and appending it to the list. Note
            # the conversion from from Numpy integers to Python integers...
            list_of_full_frame_reg_avi_writers.append(AVIReaderWriter.AVIWriter(
                                               str(os.path.dirname(correct_path) +'\\Processed\\FFR_AVIs' + output_files_prefix + '_ffr_n_' +\
                                               str(full_frame_n_frames_to_register[avi_index]) + '_cropped_' +\
                                               str(data['min_overlap_for_cropping_full_frame_image'])+ '.avi'),
                                               int(max_column_crop2 - min_column_crop2),
                                               int(max_row_crop2    - min_row_crop2),
                                               8,
                                               image_reader.GetFrameRate(),
                                               None))


    if strip_registration_required:

        # creating extended frame for strip registered movie
        strip_reg_seq                   = np.zeros((strip_n_rows_reg_img,
                                                    strip_n_columns_reg_img),
                                                    dtype = np.float32)

        n_pixels_to_interpolate         = strip_n_rows_reg_img * strip_n_columns_reg_img

        current_frame_desired_columns   = np.zeros((n_pixels_to_interpolate,), dtype = np.float32)
        current_frame_desired_rows      = np.zeros((n_pixels_to_interpolate,), dtype = np.float32)
        reference_frame_desired_columns = np.zeros((n_pixels_to_interpolate,), dtype = np.int32)
        reference_frame_desired_rows    = np.zeros((n_pixels_to_interpolate,), dtype = np.int32)

        # creating auxiliary vectors for interpolation calculations
        row_indices                     = np.arange(n_rows_desinusoided   ,    dtype = np.int32)
        column_indices                  = np.arange(n_columns_desinusoided,    dtype = np.int32)


        list_of_strip_reg_avi_writers   = []

        # initializing the AVI writers
        for avi_index in range(len(strip_n_frames_to_register)):
            
            # getting the size of the cropped frame
            min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                            strip_cropping_ROI_2[avi_index]
            
            # First check to see if the dir exists- for new version, I would make this
            # a function...
            d = os.path.dirname(correct_path) +'\\Processed\\SR_AVIs'
            if not os.path.exists(d):
                os.makedirs(d)
            
            # creating a new AVI file and appending it to the list. Note
            # the conversion from from Numpy integers to Python integers...
            list_of_strip_reg_avi_writers.append(AVIReaderWriter.AVIWriter(
                                          str(os.path.dirname(correct_path) +'\\Processed\\SR_AVIs' + output_files_prefix + '_sr_n_' +\
                                          str(strip_n_frames_to_register[avi_index]) + '_cropped_' +\
                                          str(data['min_overlap_for_cropping_strip_image'])+ '.avi'),
                                          int(max_column_crop2 - min_column_crop2),
                                          int(max_row_crop2    - min_row_crop2),
                                          8,
                                          image_reader.GetFrameRate(),
                                          None))



    ########################################################################
    # Iterating through acceptable frames to generate registered sequences #
    ########################################################################

    # up to here, the acceptable frames were sorted in decreasing  order of
    # NCC max value (i.e. in decreasing order of NCC). In order to create
    # the movies, let's sort them out temporally (i.e. based on their
    # position on the image sequence)

    # MOD:AES:20200310:Re-ordering these temporally is useful for functional imaging, but not for assessing the quality
    # of the registration. Keep the order of descending NCC because this will match the output image
    # Look below for more MOD:AES tags
    #acceptable_frames = np.array(acceptable_frames)
    #sorting_indices   = acceptable_frames.argsort()
    acceptable_frames = np.array(acceptable_frames)
    temporal_acceptable_frames = acceptable_frames.copy()
    # limit to the number of frames requested; WARNING this will not work correctly if more than one number of frames are requested

    if full_frame_registration_required:
        n_frames_to_output = max(full_frame_n_frames_to_register)
    if strip_registration_required:
        n_frames_to_output = max(strip_n_frames_to_register)

    n_acceptable_frames = n_frames_to_output
    temporal_acceptable_frames = temporal_acceptable_frames[:n_frames_to_output]
    sorting_indices = temporal_acceptable_frames.argsort()
    temporal_acceptable_frames.sort()

    #sorting_indices = acceptable_frames.argsort()
    #sorting_indices = range(n_acceptable_frames)
    for acceptable_index in range(n_acceptable_frames):

        # getting the index of the frame in the sequence
        frame_index                       = temporal_acceptable_frames[acceptable_index]

        if profile:
            start_time = time.clock()

        # reading and desinusoiding current frame
        success, current_frame, error_msg = __read_an_image__(
                                            frame_index            = frame_index,
                                            image_reader           = image_reader,
                                            desinusoider           = desinusoider,
                                            desinudoiding_required = desinudoiding_required)

        # exiting if finding any problems
        if not success:
            return success, error_msg, data

        if profile:
            timing_dictionary['file_reading'] += time.clock() - start_time
            
        ###############################################################
        #  Full frame registration                                    #
        ###############################################################

        # erasing the previous frame and adding the current one
        if full_frame_registration_required:

            # erasing previous image
            full_frame_reg_seq  = 0 * full_frame_reg_seq

            # adding current image (shifted)            
            full_frame_reg_seq[full_frame_row_offset    - full_frame_row_shifts   [frame_index] :                          \
                               full_frame_row_offset    - full_frame_row_shifts   [frame_index] + n_rows_desinusoided,     \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] :                          \
                               full_frame_column_offset - full_frame_column_shifts[frame_index] + n_columns_desinusoided] =\
                               current_frame

            # adding the frame to all the AVI files    
            for avi_index in range(len(list_of_full_frame_reg_avi_writers)):

                # cropping the image (1st time)
                min_row_crop, max_row_crop, min_column_crop, max_column_crop =\
                                                                full_frame_cropping_ROI_1[avi_index]

                full_frame_reg_seq_cropped  = full_frame_reg_seq[min_row_crop    : max_row_crop,
                                                                 min_column_crop : max_column_crop]
                
                # cropping the image (2nd time)
                min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                                                full_frame_cropping_ROI_2[avi_index]

                # Note that we PURPOSELY create a new array using copy(),
                # just to be sure that the resulting array is stored in 
                # contiguous memory, otherwise the function Write Frame
                # From Numpy Array might fail. 
                full_frame_reg_seq_cropped2 = full_frame_reg_seq_cropped[min_row_crop2    : max_row_crop2,
                                                                         min_column_crop2 : max_column_crop2].copy()

                if profile:
                    start_time = time.clock()
            
                # writing to the current AVI writer
                if acceptable_index < full_frame_n_frames_to_register[avi_index]:
                    if not list_of_full_frame_reg_avi_writers[avi_index].\
                               WriteFrameFromNumpyArray(full_frame_reg_seq_cropped2):
                        
                        return False, 'Failed to add current frame to registered ' + \
                                      'primary image sequence' + str(avi_index), data

                if profile:
                    timing_dictionary['file_writing'] += time.clock() - start_time

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

            # resetting the extended image
            strip_reg_seq                           = 0 * strip_reg_seq

            # getting the current frame intervals

            # MOD:AES:20200310: strip_interpolation_data is already sorted by decreasing NCC
            #current_frame_intervals                 = strip_interpolation_data[acceptable_frames[sorting_indices[acceptable_index]]]
            current_frame_intervals = strip_interpolation_data[sorting_indices[acceptable_index]]

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
                
                (interpolated_intensity_values, success)  = interpolator.MapCoordinatesFromNumpyArray(
                                                                    np.float32(current_frame),
                                                                    current_frame_desired_rows   [:n_valid_pixels],
                                                                    current_frame_desired_columns[:n_valid_pixels],
                                                                    0)

                if profile:
                    timing_dictionary['interpolating'] += time.clock() - start_time

                # placing the interpolated intensity values in the registered image
                strip_reg_seq   [reference_frame_desired_rows   [:n_valid_pixels],
                                 reference_frame_desired_columns[:n_valid_pixels]] = interpolated_intensity_values

            # END of for interval_index in range(current_frame_n_intervals): ######


            # adding the frame to all the AVI files if there is at least an interval in it
            if len(current_frame_intervals) > 0:
                for avi_index in range(len(list_of_strip_reg_avi_writers)):

                    # cropping the image (1st time)
                    min_row_crop, max_row_crop, min_column_crop, max_column_crop =\
                                                                    strip_cropping_ROI_1[avi_index]

                    strip_reg_seq_cropped  = strip_reg_seq[min_row_crop    : max_row_crop,
                                                           min_column_crop : max_column_crop]
                    
                    # cropping the image (2nd time)
                    min_row_crop2, max_row_crop2, min_column_crop2, max_column_crop2 =\
                                                                    strip_cropping_ROI_2[avi_index]

                    # Note that we PURPOSELY create a new array using copy(),
                    # just to be sure that the resulting array is stored in 
                    # contiguous memory, otherwise the function Write Frame
                    # From Numpy Array might fail. 
                    strip_reg_seq_cropped2 = strip_reg_seq_cropped[min_row_crop2    : max_row_crop2,
                                                                   min_column_crop2 : max_column_crop2].copy()

                    # writing to the current AVI writer
                    if acceptable_index < strip_n_frames_to_register[avi_index]:

                        if profile:
                            start_time = time.clock()
                            
                        if not list_of_strip_reg_avi_writers[avi_index].\
                                   WriteFrameFromNumpyArray(strip_reg_seq_cropped2):
                            
                            return False, 'Failed to add current frame to registered ' + \
                                          'primary image sequence' + str(avi_index), data

                        if profile:
                            timing_dictionary['file_writing'] += time.clock() - start_time
                            
        # updating the progress bar every other frame
        if type(progress_bar) != type(None) and (acceptable_index % 2 == 0):
            wx.CallAfter(progress_bar.SetValue, int(100*(acceptable_index + 1)/n_acceptable_frames))

        # frame for loop END ##############################################

    if profile:
        data['create_ouput_sequence_timing'] = timing_dictionary

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

    # Silly bug fix: AVIReader seems to have a problem reading the first
    # frame the first time, but can be circumvented by reading other frames
    # and circling back
    if frame_index == 0:
        current_frame = image_reader.ReadImageToNumpyBuffer(0)
        current_frame = image_reader.ReadImageToNumpyBuffer(1)
    
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
