# AO-PIPELINE
Contains a quick-and-dirty "live" mode for running during acquisition to facilitate complete montage collection and a more robust but slow "full" mode for producing analysis-ready montages.

The current state is pretty raw and rigid, the goal is to become much more modular so that processing modules can be swapped out with the development of proper adapters.

## Basic operation for running Full-AO-pipe on an existing dataset:
1. Run "launch_ao_pipe.m"
2. Adjust input, output, and calibration settings for your AOSLO system using the "AO System" tab of the GUI
3. Select the Session tab, adjust the #CPU Cores (4 is recommended for most machines), de-select "Run LIVE PIPE", adjust Min # Frames (5 is usually good for most subjects)
4. Select Start at the bottom.

## Current Requirements:
- For both modes:
  - Python 2.7, preferably at C:\Python27
  - Matlab ≥ 2017
- For "live" mode (can easily be disabled in the GUI):
  - Python 3.7, preferably at C:\Python37
- For "full" mode
  - Adobe Photoshop CS6, preferably at C:\Program Files\Adobe\Adobe Photoshop CS6 (64 Bit); though Full-AO-pipe will output a .jsx file containing information for building the montage if PS is not available on the machine running Full-AO-pipe

### Citation
See manuscript: https://doi.org/10.1364/BOE.418079

Alexander E. Salmon, Robert F. Cooper, Min Chen, Brian Higgins, Jenna A. Cava, Nickolas Chen, Hannah M. Follett, Mina Gaffney, Heather Heitkotter, Elizabeth Heffernan, Taly Gilat Schmidt, and Joseph Carroll, "Automated image processing pipeline for adaptive optics scanning light ophthalmoscopy," Biomed. Opt. Express 12, 3142-3168 (2021)
