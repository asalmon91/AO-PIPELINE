# Imports
import getopt
import os
import sys
import math
import cPickle
import DeSinusoider as dsin
import numpy as np

## Defaults
# Desinusoiding
calPath         = ''
calFname        = ''
# Video
vidPath         = ''
vidFname        = ''
# RF
refFrame        = 1
# Reg params
srPrecision     = 'single'
ffrPrecision    = 'single'
lps             = ''
lbss            = ''
stripRegReq     = ''
srDisp          = ''  # W/3
ffrDisp         = ''  # W/3
dct             = 50
# Cropping
srCropNccCols   = ''  # W/4
srCropNccRows   = ''  # LPS/2
ffrCropNccLines = ''  # W/4
# n Frames
srMinFrames     = 1
ffrMinFrames    = 1
srMaxFrames     = ''  # All, set below
ffrMaxFrames    = ''  # All, set below
# Secondary sequence names
secondVidFnames = []
# Output
ffrSaveSeq      = True
ffrSaveImg      = True
srSaveSeq       = True
srSaveImg       = True
append          = ''

# todo: learn how to call python functions from matlab https://www.mathworks.com/help/matlab/call-python-libraries.html
# Command line arguments, if you know a better way, please share
argList = [
    # Major parameters
    "dsinReq=", "calPath=", "calFname=", "vidPath=", "vidFname=", "refFrame=",
    # Video information
    "nRowsRaw=", "nColsRaw=", "vidNFrames=",
    # Strip reg
    "stripRegReq=", "lps=", "lbss=", "srPrecision=", "srCropNccRows=", "srCropNccCols=", "nccThr=", "srDisp=", "dct=",
    # Full frame reg
    "ffrDisp=", "ffrPrecision=", "ffrCropNccLines=",
    # n Frames
    "ffrMaxFrames=", "srMaxFrames=", "ffrMinFrames=", "srMinFrames=",
    # Secondary sequence file names
    'secondVidFnames=',
    # Output
    "srSaveImg=", "srSaveSeq=", "ffrSaveImg=", "ffrSaveSeq=", "append="]


def translate_boolean(matlab_input):
    if matlab_input == "true" or matlab_input == '1' or matlab_input == 1:
        return True
    else:
        return False


try:
    opts, args = getopt.getopt(sys.argv[1:], '', argList)
    #print opts
    #print args
except getopt.GetoptError:
    print 'Failure'
    print getopt.GetoptError.message
    sys.exit(2)
for opt, arg in opts:
    # Major parameters ###################
    if opt in "--dsinReq":
        dsinReq = translate_boolean(arg)
    elif opt in "--calPath":
        calPath = arg
    elif opt in "--calFname":
        calFname = arg
    elif opt in "--vidPath":
        vidPath = arg
    elif opt in "--vidFname":
        vidFname = arg
    elif opt in "--refFrame":  # Optional, def: 1
        refFrame = int(arg)
    # Video Information ###################
    elif opt in "--nRowsRaw":
        nRowsRaw = int(arg)
    elif opt in "--nColsRaw":
        nColsRaw = int(arg)
    elif opt in "--vidNFrames":
        vidNFrames = int(arg)
    # Strip reg ###################
    elif opt in "--stripRegReq":
        stripRegReq = translate_boolean(arg)
    elif opt in "--lps":
        lps = int(arg)
    elif opt in "--lbss":
        lbss = int(arg)
    elif opt in "--srPrecision":  # Optional, def: 'single'
        srPrecision = arg
        # todo: Check if either single or double
    elif opt in "--srCropNccRows":
        srCropNccRows = int(arg)
    elif opt in "--srCropNccCols":
        srCropNccCols = int(arg)
    elif opt in "--nccThr":
        nccThr = float(arg)
    elif opt in "--srDisp":
        srDisp = int(arg)
    elif opt in "--dct":
        dct = int(arg)
    # Full frame reg ###################
    elif opt in "--ffrDisp":
        ffrDisp = int(arg)
    elif opt in "--ffrPrecision":  # Optional, def: 'single'
        ffrPrecision = arg
        # todo: Check if either single or double
    elif opt in "--ffrCropNccLines":
        ffrCropNccLines = int(arg)
    # n Frames ###################
    elif opt in "--ffrMaxFrames":
        ffrMaxFrames = [int(x) for x in arg.split(', ')]
    elif opt in "--srMaxFrames":
        srMaxFrames = [int(x) for x in arg.split(', ')]
    elif opt in "--ffrMinFrames":
        ffrMinFrames = int(arg)
    elif opt in "--srMinFrames":
        srMinFrames = int(arg)
    # 2nd videos ###################
    elif opt in "--secondVidFnames":
        secondVidFnames = arg
    # Output ###################
    elif opt in "--srSaveImg":
        srSaveImg = translate_boolean(arg)
    elif opt in "--srSaveSeq":
        srSaveSeq = translate_boolean(arg)
    elif opt in "--ffrSaveImg":
        ffrSaveImg = translate_boolean(arg)
    elif opt in "--ffrSaveSeq":
        ffrSaveSeq = translate_boolean(arg)
    elif opt in "--append":
        append = arg

# todo: a lot of human error handling

if calPath != '' and calFname != '':
    dsinReq = True
else:
    dsinReq = False


if lps != '' or lbss != '':
    stripRegReq = True
else:
    stripRegReq = False

if srMaxFrames == '':
    srMaxFrames = vidNFrames

if ffrMaxFrames == '':
    ffrMaxFrames = vidNFrames


# Video information
data = {'clinical_version':             False,
        'image_sequence_file_name':     vidFname,
        'image_sequence_absolute_path': vidPath,
        'fast_scanning_horizontal':     True,
        'reference_frame':              refFrame-1,
        'n_rows_raw_sequence':          nRowsRaw,
        'n_columns_raw_sequence':       nColsRaw,
        'n_frames':                     vidNFrames,
        'desinusoiding_required':       dsinReq}


# Desinusoiding
if dsinReq:
    data['desinusoid_data_filename']      = calFname
    data['desinusoid_data_absolute_path'] = calPath
    data['desinusoid_matrix']             = np.float32(dsin.DeSinusoider(
            filename=calFname, absolute_path=calPath, store_error=True).GetDesinusoidMatrix())
    dim1, new_col = data['desinusoid_matrix'].shape
    data['n_rows_desinusoided']           = data['n_rows_raw_sequence']
    data['n_columns_desinusoided']        = new_col
else:
    new_col = nColsRaw


# NCC parameter defaults based on desinusoided dimensions
if srCropNccCols == '':
    srCropNccCols = int(math.floor(float(new_col)/4))
if ffrCropNccLines == '':
    ffrCropNccLines = int(math.floor(float(new_col)/4))
if srDisp == '':
    srDisp = int(math.floor(float(new_col)/3))
if ffrDisp == '':
    ffrDisp = int(math.floor(float(new_col)/3))
if srCropNccRows == '':
    srCropNccRows = int(math.floor(float(lps)/2))


# SR motion estimation parameters ##############################
data['strip_registration_required'] = stripRegReq
data['frame_strip_lines_per_strip'] = lps
data['frame_strip_calculation_precision'] = ffrPrecision
data['frame_strip_lines_between_strips_start'] = lbss
data['frame_strip_ncc_n_rows_to_ignore'] = srCropNccRows
data['frame_strip_ncc_n_columns_to_ignore'] = srCropNccCols
data['frame_strip_ncc_threshold'] = nccThr
data['strip_max_displacement_threshold'] = srDisp
data['strip_DCT_terms_retained_percentage'] = dct


# FFR motion estimation parameters ##############################
data['full_frame_max_displacement_threshold']   = ffrDisp
data['full_frame_calculation_precision']        = ffrPrecision
data['full_frame_ncc_n_lines_to_ignore']        = ffrCropNccLines


# N frames to register
data['full_frame_n_frames_with_highest_ncc_value']  = ffrMaxFrames
data['min_overlap_for_cropping_full_frame_image']   = ffrMinFrames
data['strip_n_frames_with_highest_ncc_value']       = srMaxFrames
data['min_overlap_for_cropping_strip_image']        = srMinFrames


# FFR/SR save image and/or sequence
data['save_strip_registered_image']         = srSaveImg
data['save_strip_registered_sequence']      = srSaveSeq
data['save_full_frame_registered_image']    = ffrSaveImg
data['save_full_frame_registered_sequence'] = ffrSaveSeq



# todo: implement secondary sequence handling
# Secondaries
data['secondary_sequences_absolute_paths'] = vidPath
if len(secondVidFnames) != 0:
    # Construct a list of video file names
    data['secondary_sequences_file_names'] = secondVidFnames.split(', ')


# File name generation
if append != '':
    append = '_' + append

lpsTxt = '_lps_' + str(lps)
lbssTxt = '_lbss_' + str(lbss)

name_root = append + '_ref_' + str(refFrame) + lpsTxt + lbssTxt
batch_file_name = vidFname[:len(vidFname)-4] + name_root + '.dmb'
data['user_defined_suffix'] = name_root

# Write file
f = open(vidPath + os.sep + batch_file_name, 'w')
cPickle.dump(data, f)
f.close()

# Output file name
print batch_file_name
