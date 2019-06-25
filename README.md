# AO-PIPE
Fully automated image processing pipeline for AOSLO images
The current state is pretty raw and rigid, the goal is to become much more modular so that processing modules can be swapped out with the development of proper adapters.

Current Requirements:

Python 2.7, preferably at C:\Python27

Python 3.7, preferably at C:\Python37

Adobe Photoshop CS6, preferably at C:\Program Files\Adobe\Adobe Photoshop CS6 (64 Bit)

DubraLab software, including a version of DeMotion that outputs .dmp files

May need to uncomment lines 662-664 in wxBatchProcessor.pyw. If these line numbers don't make sense, search for these lines:
f = open(current_filename_and_path[:len(current_filename_and_path) - 1] + 'p', 'w')
cPickle.dump(data, f)
f.close()
