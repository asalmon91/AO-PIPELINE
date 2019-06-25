import os
import sys
import AVIReaderUncompressedMonochrome
import numpy as np
from matplotlib import pyplot as plt


def get_user_input():
    # Get path
    prompt = "Enter calibration path: "
    calibration_path = ""
    while not os.path.isdir(calibration_path):
        calibration_path = raw_input(prompt)
        prompt = "Enter VALID calibration path: "

    # Get file name
    calibration_ffname = ""
    prompt = "Enter slow scanned grid video file name: "
    while not os.path.isfile(calibration_ffname):
        calibration_name = raw_input(prompt)

        calibration_ffname = calibration_path + os.sep + calibration_name
        prompt = "Enter a VALID grid video file name: "

    return calibration_ffname


def read_video(video_ffname):
    # Create .avi reader
    reader = AVIReaderUncompressedMonochrome.AVIReaderUncompressedMonochrome(video_ffname)
    wd = reader.GetFrameWidth()
    ht = reader.GetFrameHeight()
    nf = reader.GetNumberOfFrames()
    # Must have more than one frame to avoid the bug below
    if nf == 1:
        sys.exit("This program requires > 1 frame")
    # Read first two frames (known bug in AVIReaderUncompressedMonochrome, first read attempt is distorted)
    frame = np.float64(reader.ReadFrameToNumpyArray(0))
    frame = np.float64(reader.ReadFrameToNumpyArray(1))
    # Preallocate np array
    grid = np.zeros((ht, wd, nf))
    # Read frames and add to grid
    for ii in range(0, nf - 1):
        frame = np.float64(reader.ReadFrameToNumpyArray(ii))
        grid[:, :, ii] = np.copy(frame)

    return grid


def display_profile(profile):
    # Plot results
    plt.plot(profile, '-k')
    plt.xlim([0, len(profile)])
    plt.tick_params('both', direction='out')
    # ax = plt.gca()
    # ax.axis_bg = 'k'
    plt.ylabel("Intensity")
    plt.xlabel("Row index (px)")
    plt.show()


def check_if_done():
    valid_input = False
    prompt = "Check another file? y or n: "
    while not valid_input:
        re = raw_input(prompt)
        if re == 'y' or re == 'n':
            valid_input = True
            if re == 'n':
                return True
            else:
                return False
        prompt = "Input not recognized, check another file? y or n: "


def main():
    # Get full file name of grid video from user
    calibration_ffname = get_user_input()

    # Read video, return as 3D np array
    grid = read_video(calibration_ffname)

    # Average frames then columns to get the grid profile
    grid_profile = np.mean(np.mean(grid, axis=2), axis=1)

    # Display results
    display_profile(grid_profile)

    return check_if_done()


if __name__ == "__main__":
    done = False
    while not done:
        done = main()
    sys.exit(0)
