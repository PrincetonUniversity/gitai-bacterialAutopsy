This is a set of MATLAB routines used to analyze fluorescent microscopy images of individual bacterial cells to determine a 'cause of death'. Cells are subjected to a bacterial autotopsy by co-staining with FM4-64, Sytox Green, and DAPI to reveal changes in cell size, shape, nucleoid morphology, membrane permeability, etc.

# Bacterial cytological profiling code
## Required toolboxes (other versions likely work)

MATLAB R2018b (version 9.5)

Image Processing Toolbox (version 10.3)

Statistics and Machine Learning Toolbox (version 11.4)

## Required accessory files (from mathworks file exchange)
progressbar (fileexchange/6922-progressbar)

uipickfiles (fileexchange/10867-uipickfiles-uigetfile-on-steroids)

## Required pre-processing
0. Contours outlining individual cells should be in a format consistent with the output of [Morphometrics] (https://simtk.org/projects/morphometrics).

## Basic operation
1. Run the program CytProfiling_4
2. Respond to the prompt for an alternate key, for example if sample labeled 'A1' corresponds to treatment with 'Vinegar' and sample labeled 'B7' corresponds to treatment with 'Honey'. To use the folder names as the labels, select 'No'.
3. Select each folder of images to include. These folders should have the CONTOURS.mat file and the raw #.tif files in them.
4. Respond to the prompt for where to save the text output file. This file will be a comma separated table of the cytological properties for each individual bacterial cell.
5. The program will then process those folders to extract the cytological values for each bacterial cell. This process can take a moderate amount of time (5-15 minutes), especially for large images and/or large numbers of images.
6. The default graphical output is a hierarchical clustering of input treatments using the single-linkage method with MANOVA.

# (optional) UMAP dimensionality reduction
## Required toolboxes (other versions likely work)
Statistics and Machine Learning Toolbox (version 11.4)

Curve Fitting Toolbox (version 3.5.8)

Bioinformatics Toolbox (version 4.11)

## Required accessory files (from mathworks file exchange)
histcn (fileexchange/23897-n-dimensional-histogram)

umap (fileexchange/71902-uniform-manifold-approximation-and-projection-umap)

uipickfiles (fileexchange/10867-uipickfiles-uigetfile-on-steroids)

uiinspect (fileexchange/17935-uiinspect-display-methods-properties-callbacks-of-an-object)

## Basic operation
7. To choose UMAP for dimensionality reduction instead, use the script cytProfile_umap
8. Select the file with the output from CytProfiling_4
9. Choose which specific treatment to highlight in a second color
10. One may choose to adjust umap settings, or the colors used to represent different treatment groups. The location of those settings are labeled in comments in the script.
