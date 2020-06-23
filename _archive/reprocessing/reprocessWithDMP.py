import CreateRegisteredImages, CreateRegisteredSequences
import CUDABatchProcessorToolBag
import cPickle

argList = ["dmpFFname="]

try:
    opts, args = getopt.getopt(sys.argv[1:], 'p:n:', argList)
    #print opts
    #print args
except getopt.GetoptError:
    print 'Failure'
    print getopt.GetoptError.message
    sys.exit(2)
for opt, arg in opts:
    # Major parameters ###################
    if opt in ('-p', "--dmpFFname"):
        dmp_full_file_name = arg
    else:
        print 'unknown input'

# Read .dmp
#dmp_full_file_name = 'C:\\Users\DevLab_811\\workspace\\pipe_test\\BL_12063\\AO_2_3_SLO\\2019_07_11_OS\\Processed\\FULL\\13_L1C1\\tmp\\BL_12063_775nm_OS_confocal_0013_13_L1C1_ref_1_lps_6_lbss_6.dmp'
fid = open(dmp_full_file_name, 'r')
data = cPickle.load(fid)
fid.close()

# Re-process
tool_bag = CUDABatchProcessorToolBag.CUDABatchProcessorToolBag()
print 'Generating images'
#data['frame_strip_ncc_threshold'] = 0.7
success, error_msg, data = CreateRegisteredImages.RegisterPrimaryImageSequence(data, tool_bag, None)
if success:
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
    f = open(dmp_full_file_name, 'w')
    cPickle.dump(data, f)
    f.close()

print success
print error_msg