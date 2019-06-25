# Created - Alex Salmon - 2019.05.10
# The goal of this program is to constantly copy the current state of folders and files in the acquisition computer to
# the processing computer

# Imports
import os
import time
from shutil import copyfile

# Constants
WAIT = 10  # seconds, average time per video is 10


def recursive_file_copy(in_path, out_path):
    print 'Searching for files in ' + in_path

    in_root, in_dir = os.path.split(in_path)
    out_root = os.path.join(out_path, in_dir)

    for root, directories, file_names in os.walk(in_path):
        # Copy any new directories
        for directory in directories:
            out_dir = out_root + root[str.find(root, in_dir) + len(in_dir):] + os.sep + directory

            if not os.path.isdir(out_dir):
                print 'Creating ' + out_dir
                os.makedirs(out_dir)

        # Copy any new files that are finished writing
        for file_name in file_names:
            in_file = os.path.join(root, file_name)
            out_file = out_root + in_file[str.find(in_file, in_dir)+len(in_dir):]

            if not os.path.isfile(out_file):
                file_is_ready = False
                try:
                    open(in_file, 'r')
                    file_is_ready = True
                except IOError:
                    print file_name + ' is being written.'

                if file_is_ready:
                    try:
                        copyfile(in_file, out_file)
                        print 'Copying ' + in_file + ' to ' + out_file
                    except IOError:
                        print 'Something went wrong'
            else:
                # Get time stamps for in_file and out_file and overwrite out_file if in_file is newer
                if os.path.getmtime(in_file) > os.path.getmtime(out_file):
                    try:
                        copyfile(in_file, out_file)
                        print in_file + ' has been updated, overwriting ' + out_file
                    except IOError:
                        print 'Something went wrong'


def validate_path(path_str):
    return os.path.isdir(path_str)


def get_path(message):
    # Asks the user for a path and makes sure it exists

    in_path = ""
    first_iteration = True
    while not validate_path(in_path):
        if not first_iteration:
            print("Directory not found")

        in_path = raw_input(message)
        first_iteration = False

    return in_path


def main():
    debug_mode = False

    # Get src and trg path
    src_path = get_path("Enter directory to send to processing PC: ")
    trg_path = get_path("Enter processing PC destination directory: ")

    print "Remember to collect grid videos first or processing will stall."

    # Start infinite loop looking for new files
    k = 0
    while k == 0:
        recursive_file_copy(src_path, trg_path)

        if debug_mode:
            k += 1
        else:
            # Wait
            time.sleep(WAIT)


# Run script
main()

