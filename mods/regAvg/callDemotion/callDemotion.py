# Imports
import getopt
import sys
import os
import MotionEstimation, CreateRegisteredImages, CreateRegisteredSequences
import CUDABatchProcessorToolBag
import cPickle

argList = ["dmbPath=", "dmbFname=", "output="]

try:
    opts, args = getopt.getopt(sys.argv[1:], 'p:n:o:', argList)
    #print opts
    #print args
except getopt.GetoptError:
    print 'Failure'
    print getopt.GetoptError.message
    sys.exit(2)
for opt, arg in opts:
    # Major parameters ###################
    if opt in ('-p', "--dmbPath"):
        dmb_path = arg
    elif opt in ('-n', "--dmbFname"):
        dmb_fname = arg
    elif opt in ('-o', "--output"):
        if arg == '0':
            output = False
        else:
            output = True


# Test constants
#dmb_fname = 'JC_0616_790nm_OD_confocal_0111_ref_53_lps_20_lbss_10.dmb'
#dmb_path = 'E:\\datasets\\demotion\\test\\JC_0616-20171222-OD\\Raw\\'
dmb_ffname = os.path.join(dmb_path, dmb_fname)
tool_bag = CUDABatchProcessorToolBag.CUDABatchProcessorToolBag()

# todo figure out how to create a progress bar
print 'registering ' + dmb_fname
success, error_msg, data = MotionEstimation.EstimateMotion(dmb_ffname, tool_bag)
print 'Generating images'
if output:
    success, error_msg, data = CreateRegisteredImages.RegisterPrimaryImageSequence(data, tool_bag, None)

if output and success:
    n_secondary_sequences = len(data['secondary_sequences_file_names'])

    # only performing the movie registration if needed
    if (data['save_full_frame_registered_image'] or
        (data['strip_registration_required'] and data['save_strip_registered_image'])) and \
            (n_secondary_sequences > 0):

        # letting the user know that the image registration is taking place
        #temp_size = self.current_action_label.GetSize()
        #wx.CallAfter(self.current_action_label.SetLabel, 'Generating secondary sequence registered images')
        #wx.CallAfter(self.current_action_label.SetSize, temp_size)

        # registering secondary sequences
        for sequence_index in range(n_secondary_sequences):

            #if run_profiling:
                #start_time = time.clock()

            success, error_msg, data = CreateRegisteredImages. \
                RegisterSecondaryImageSequence(
                data['secondary_sequences_absolute_paths'][sequence_index],
                data['secondary_sequences_file_names'][sequence_index],
                tool_bag,
                data, None, False)
                #self.progress_bar,
                #run_profiling)
            if not success:
                failed_at_stage = 'generating secondary sequence registered images'

            #if run_profiling:
                #total_time = time.clock() - start_time
                #data['register_secondary_timing']['total'] = total_time
                #self.profiling_data[file_name]['register_secondary_timing'] = data['register_secondary_timing']

    if success and (data['save_full_frame_registered_sequence'] or (
            data['strip_registration_required'] and data['save_strip_registered_sequence'])):

        # letting the user know that the image registration is taking place
        #temp_size = self.current_action_label.GetSize()
        #wx.CallAfter(self.current_action_label.SetLabel, 'Generating primary sequence registered movie')
        #wx.CallAfter(self.current_action_label.SetSize, temp_size)

        #if run_profiling:
            #start_time = time.clock()

        # registering primary sequence
        success, error_msg, data = CreateRegisteredSequences. \
            RegisterImageSequenceOutputSequence(
            data['image_sequence_absolute_path'],
            data['image_sequence_file_name'],
            data,
            tool_bag, None, False)
            #self.progress_bar,
            #run_profiling)
        #if run_profiling:
            #total_time = time.clock() - start_time
            #data['create_ouput_sequence_timing']['total'] = total_time
            #self.profiling_data[file_name]['create_ouput_sequence_timing'] = data['create_ouput_sequence_timing']

        if success and (n_secondary_sequences > 0):

            # letting the user know that the image registration is taking place
            #temp_size = self.current_action_label.GetSize()
            #wx.CallAfter(self.current_action_label.SetLabel, 'Generating secondary sequence registered movie')
            #wx.CallAfter(self.current_action_label.SetSize, temp_size)

            # registering secondary sequences
            for sequence_index in range(len(data['secondary_sequences_file_names'])):

                success, error_msg, data = CreateRegisteredSequences. \
                    RegisterImageSequenceOutputSequence(
                    data['secondary_sequences_absolute_paths'][sequence_index],
                    data['secondary_sequences_file_names'][sequence_index],
                    data,
                    tool_bag, None, False)
                    #self.progress_bar,
                    #False)
                if not success:
                    failed_at_stage = 'generating secondary sequence registered movie'
        else:
            failed_at_stage = 'generating primary sequence registered movie'
else:
    failed_at_stage = 'generating primary sequence registered images'

if success:
    # getting rid of the desinusoid matrix in the interest of hard-drive space!
    # Modified:AES:20200229:Keep desinusoid matrix for fast re-processing
    '''
    if data.has_key('desinusoid_matrix'):
        not_used = data.pop('desinusoid_matrix')
    '''
    # saving data to a file with "Demotion processed" extension (dmp)
    f = open(dmb_ffname[:len(dmb_ffname) - 1] + 'p', 'w')
    cPickle.dump(data, f)
    f.close()
