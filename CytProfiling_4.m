function CytProfiling_4(varargin)
%% Bacterial Cytological Profiler
% Using fluorescent images and contours generated by morphometrics,
% calculate morphological properties
%
%
%
%
%
% Parse input arguments
if nargin>0
    warning('bcp:inputArgStyle','Explicity inputs are not yet supported. Please contact the developer.');
end

%%

%Channel 0 is Phase
%Channel 1 is Sytox green (or any GFP channel)
%Channel 2 is fm4-64 (or other membrane stain)
%Channel 3 is Dapi
%/Users/mzwilson/Documents/Science/Image Analysis/
%
%
%
%


%% Default display parameters
displayFlags.labeledMask = false;
displayFlags.fluorescentImage1 = false;

%% Default parameters
BACKGROUND_QUANTILE = 0.05;

%% Initialize All Arrays
C = cell(0,18);

%% Load Sample Key spreadsheet
isExternalConditionKey = questdlg('Do you have an alternate key for condition labels?',...
    'Condition label key','Yes','No','Cancel','Yes');

switch isExternalConditionKey
    case 'Yes'
        [conditionKeyFilename,conditionKeyFilepath] = uigetfile('.xlsx','Please select file with labeling key.');
        fullpathConditionKeyFile = fullfile(conditionKeyFilepath,conditionKeyFilename);
        
        % Specify the filepath for the spreadsheet key here:
        [~, ~, alldata] = xlsread(fullpathConditionKeyFile);
        keyT_raw = cell2table(alldata);
        keyT = keyT_raw(2:end,:);
        keyT.Properties.VariableNames = alldata(1,:);
        RowCol_array = table2array(keyT(:,{'RowCol_ID'}));
        Drug_array = table2array(keyT(:,{'Drug'}));
    case 'No'
        disp('Using the parent foldername as a label');
    case 'Cancel'
        return
    otherwise
        return
end

%% Prompt user for files to process
inputFolderPaths = uipickfiles('Prompt',...
    'Please select the folders containing matched *CONTOURS.mat and *.tif to be analyzed.');

[outputFilename,outputFilepath] = uiputfile('BcpOutput.txt');
fullpathOutputFile = fullfile(outputFilepath,outputFilename);

if isfile(fullpathOutputFile)
    isOverwriteOutputFile = questdlg('Output file already exists. Do you want to overwrite it?',...
        'Overwrite output','Yes','No','Cancel','Yes');
    
    switch isOverwriteOutputFile
        case 'Yes'
            % continue with the overwrite process
        otherwise
            % if the user does not want to overwrite, simply abort and return
            % to calling workspace
            return
    end
end

progressbar('Conditions/Folders','Reading and processing files within folder.');
progressbarDelta(1) = 1./numel(inputFolderPaths);

contour_channel_name = [];
for iiCondition = 1:numel(inputFolderPaths)
    % update progressbar for folder level
    progressbar((iiCondition-0.5).*progressbarDelta(1),100*eps);
    
    % find all the contours files in this folder
    contourFileList = dir([inputFolderPaths{iiCondition}, filesep, '*CONTOURS.mat']);
    
    for iiFile = 1:numel(contourFileList)
        % find the color channel specific name
        contourFileName = contourFileList(iiFile).name;
        
        if isempty(contour_channel_name);
            splitNameAtColor = strsplit(contourFileName,'c=');
            splitNameAtColor = strsplit(splitNameAtColor{2});
            contour_channel_name = ['c=',splitNameAtColor{1}];
        end
        matchesContourChannel = strfind(contourFileName,contour_channel_name);
        if isempty(matchesContourChannel)
        	error('cytoProfiling:mismatchContourName',[[contourFileName],...
                ' does not match expected name of ''',contour_channel_name,'''']);
        end
        
        %%
        tempLoad = load(fullfile(inputFolderPaths{iiCondition}, contourFileName));
        %%
        tifStemSplit = strsplit(contourFileName,'_');
        tifStem = tifStemSplit{1};
        for kk = 2:length(tifStemSplit)-2
            tifStem = [tifStem,'_',tifStemSplit{kk}];
        end
        tifStem = [tifStem,'.tif'];
        %% Get folderpath and file of each tif
        c0TifFile = fullfile(inputFolderPaths{iiCondition},strrep(tifStem,contour_channel_name,'c=0'));
        c1TifFile = fullfile(inputFolderPaths{iiCondition},strrep(tifStem,contour_channel_name,'c=1'));
        c2TifFile = fullfile(inputFolderPaths{iiCondition},strrep(tifStem,contour_channel_name,'c=2'));
        c3TifFile = fullfile(inputFolderPaths{iiCondition},strrep(tifStem,contour_channel_name,'c=3'));

        %% from contours to mask via inpolygon
        %Load image Size and initailize mask variable
        c0 = imread(c0TifFile);
        mask = zeros(size(c0));
        
        % from contours to mask via inpolygon
        [xx, yy] = meshgrid(1:size(c0,2), 1:size(c0,1));
        
        for iObject = 1:numel(tempLoad.frame(1).object)

            imask = inpolygon(xx, yy, [tempLoad.frame.object(iObject).Xcont;...
                tempLoad.frame.object(iObject).Xcont(1)],...
                [tempLoad.frame.object(iObject).Ycont;...
                tempLoad.frame.object(iObject).Ycont(1)]);
            mask = iObject*imask + mask;
        end
        
        mask = bwlabel(mask);
        
        %% gather cell properties from c0-derived mask
        
        % calculate region props
        c0CC = bwconncomp(mask, 4);
        
        STATS = regionprops(c0CC,c0,'Perimeter', 'Area', 'MajorAxisLength',...
            'MinorAxisLength','Eccentricity');
        
        if displayFlags.labeledMask
            RGB = label2rgb(mask);
            imshow(RGB)
        end
        
        %% c1 mean & total intensity per cell
        % background subtraction of channel 2
        c1 = double(imread(c1TifFile));
        q = quantile(c1(:),BACKGROUND_QUANTILE);
        c1 = c1 - q;
        
        % mean cell intensity calculation
        c1STATS = regionprops(c0CC, c1, 'PixelValues', 'MeanIntensity');
        
        % index values into STATS structured array
        for iObject = 1:c0CC.NumObjects
            STATS(iObject).c1PixelValues = c1STATS(iObject).PixelValues;
            STATS(iObject).c1TotalIntensity = sum(c1STATS(iObject).PixelValues);
            STATS(iObject).c1MeanIntensity = c1STATS(iObject).MeanIntensity;
        end
        
        %% c2 mean & total intensity per cell
        
        % background subtraction of channel 3
        c2 = double(imread(c2TifFile));
        q = quantile(c2(:),BACKGROUND_QUANTILE);
        c2 = c2 - q;
        
        % mean cell intensity calculation
        c2STATS = regionprops(c0CC, c2, 'PixelValues','MeanIntensity');
        
        % index values into STATS structured array
        for iObject = 1:c0CC.NumObjects
            STATS(iObject).c2PixelValues = c2STATS(iObject).PixelValues;
            STATS(iObject).c2TotalIntensity = sum(c2STATS(iObject).PixelValues);
            STATS(iObject).c2MeanIntensity = c2STATS(iObject).MeanIntensity;
        end
        
        
        %% c4 mean & total intensity per cell
        
        % background subtraction of channel 4
        c3 = double(imread(c3TifFile));
        q = quantile(c3(:),BACKGROUND_QUANTILE);
        c3 = c3 - q;
        
        % mean cell intensity calculation
        c3STATS = regionprops(c0CC, c3, 'PixelValues','MeanIntensity');
        if displayFlags.fluorescentImage1
            imshow(c3,[],'initialmagnification', 'fit')
        end
        
        % index values into STATS structured array
        for iObject = 1:c0CC.NumObjects
            STATS(iObject).c3PixelValues = c3STATS(iObject).PixelValues;
            STATS(iObject).c3MeanIntensity = c3STATS(iObject).MeanIntensity;
            STATS(iObject).c3TotalIntensity = sum(c3STATS(iObject).PixelValues);
        end
        %% c4 object analysis
        
        % Create Binary Mask from c0 for c3 analysis
        c0BinaryMask = zeros(size(mask));
        
        for iObject = 1:c0CC.NumObjects
            iBinaryMask = mask == iObject;
            c0BinaryMask = iBinaryMask + c0BinaryMask;
        end
        
        % Create c3 mask by thresholding
        % scale c3 between 0 & 1
        c3 = c3.*(c3 > 0);
        c3 = c3/max(c3(:));
        
        % Threshold and Mask
        c3Mask = c0BinaryMask.*c3;
        filter = c3Mask(:);
        filter = filter(filter ~= 0);
        c3Mask = c3Mask > 1.5*median(filter);
        
        % clean up Mask
        c3Mask = bwmorph(c3Mask,'clean', 'open');
        c3Mask = bwlabel(c3Mask, 4);
        
        %%  calculate and index nucleoid area, nucleoidarea:cellarea ratio,...
        %  and nucleoid eccentricity
        for iObject = 1:c0CC.NumObjects
            STATS(iObject).nucleoidArea = nnz(and(c3Mask, mask == iObject));
            
            if STATS(iObject).nucleoidArea == 0
                STATS(iObject).nucleoidArea = NaN;
                STATS(iObject).nucleoidToCellRatio = NaN;
                continue
            end
            
            STATS(iObject).nucleoidToCellRatio = (STATS(iObject).nucleoidArea)...
                /(STATS(iObject).Area);
        end
        
        %Nucleoid Eccentricity calculataed on a per-cell basis
        % if No Nucleoid is measured, NaN is inserted into structure
        for iObject = 1:c0CC.NumObjects
            c3TempCC = bwconncomp(and(c3Mask, mask == iObject));
            c3TempSTATS = regionprops(c3TempCC, 'Eccentricity', 'MajorAxisLength',...
                'MinorAxisLength', 'Perimeter');
            
            if c3TempCC.NumObjects == 0
                STATS(iObject).nucleoidEccentricity = NaN;
                STATS(iObject).DNALength = NaN;
                STATS(iObject).DNAWidth = NaN;
                STATS(iObject).DNAPerimeter = NaN;
                continue
            end
            
            STATS(iObject).nucleoidEccentricity = c3TempSTATS.Eccentricity;
            STATS(iObject).DNALength = c3TempSTATS.MajorAxisLength;
            STATS(iObject).DNAWidth = c3TempSTATS.MinorAxisLength;
            STATS(iObject).DNAPerimeter = c3TempSTATS.Perimeter;
            
        end
        
        
        
        %% Extract all relavant data into arrays encompassing each property for statistics
        if size(STATS,1)==0
            warning('bcp:cellCountZero',['No objects loaded in file: ', contourFileName]);
           continue 
        end
        AreaTemp = [STATS.Area];
        LengthTemp = [STATS.MajorAxisLength];
        WidthTemp = [STATS.MinorAxisLength];
        EccentricityTemp = [STATS.Eccentricity];
        PerimeterTemp = [STATS.Perimeter];
        nucleoidAreaTemp = [STATS.nucleoidArea];
        nucleoidToCellRatioTemp = [STATS.nucleoidToCellRatio];
        nucleoidEccentricityTemp = [STATS.nucleoidEccentricity];
        DNAWidthTemp = [STATS.DNAWidth];
        DNALengthTemp = [STATS.DNALength];
        DNAPerimeterTemp = [STATS.DNAPerimeter];
        c1TotalIntensityTemp = [STATS.c1TotalIntensity];
        c1MeanIntensityTemp = [STATS.c1MeanIntensity];
        c2TotalIntensityTemp = [STATS.c2TotalIntensity];
        c2MeanIntensityTemp = [STATS.c2MeanIntensity];
        c3TotalIntensityTemp = [STATS.c3TotalIntensity];
        c3MeanIntensityTemp = [STATS.c3MeanIntensity];
        
        
        % Concatenate all Temp Arrays with all previously concatenated arrays
        AreaArray = [];
        LengthArray = [];
        WidthArray = [];
        EccentricityArray = [];
        PerimeterArray = [];
        DNAAreaArray = [];
        DNAToCellRatioArray = [];
        DNAEccentricityArray = [];
        DNAWidthArray = [];
        DNALengthArray = [];
        DNAPerimeterArray = [];
        c1TotalIntensityArray = [];
        c1MeanIntensityArray = [];
        c2TotalIntensityArray = [];
        c2MeanIntensityArray = [];
        c3TotalIntensityArray = [];
        c3MeanIntensityArray = [];
        
        AreaArray = cat(2, AreaArray, AreaTemp);
        LengthArray = cat(2, LengthArray, LengthTemp);
        WidthArray = cat(2, WidthArray, WidthTemp);
        EccentricityArray = cat(2, EccentricityArray, EccentricityTemp);
        PerimeterArray = cat(2, PerimeterArray, PerimeterTemp);
        DNAAreaArray = cat(2, DNAAreaArray, nucleoidAreaTemp);
        DNAToCellRatioArray = cat(2, DNAToCellRatioArray,...
            nucleoidToCellRatioTemp);
        DNAEccentricityArray = cat(2, DNAEccentricityArray, ...
            nucleoidEccentricityTemp);
        DNALengthArray = cat(2, DNALengthArray, DNALengthTemp);
        DNAWidthArray = cat(2, DNAWidthArray, DNAWidthTemp);
        DNAPerimeterArray = cat(2, DNAPerimeterArray, DNAPerimeterTemp);
        c1TotalIntensityArray = cat(2, c1TotalIntensityArray, c1TotalIntensityTemp);
        c1MeanIntensityArray = cat(2, c1MeanIntensityArray, c1MeanIntensityTemp);
        c2TotalIntensityArray = cat(2, c2TotalIntensityArray, c2TotalIntensityTemp);
        c2MeanIntensityArray = cat(2, c2MeanIntensityArray, c2MeanIntensityTemp);
        c3TotalIntensityArray = cat(2, c3TotalIntensityArray, c3TotalIntensityTemp);
        c3MeanIntensityArray = cat(2, c3MeanIntensityArray, c3MeanIntensityTemp);
        
        % Clear all Temp Arrays
        
        clear AreaTemp
        clear LengthTemp
        clear WidthTemp
        clear PerimeterTemp
        clear EccentricityTemp
        clear nucleoidAreaTemp
        clear nucleoidToCellRatioTemp
        clear nucleoidEccentricityTemp
        clear DNALengthArrayTemp
        clear DNAWidthArrayTemp
        clear DNAPerimeterArrayTemp
        clear c1TotalIntensityTemp
        clear c1MeanIntensityTemp
        clear c2TotalIntensityTemp
        clear c2MeanIntensityTemp
        clear c3TotalIntensityTemp
        clear c3MeanIntensityTemp

        %% Put all collected Data into a single matrix
        
        % Transpose
        AreaArray = transpose(AreaArray);
        LengthArray = transpose(LengthArray);
        WidthArray = transpose(WidthArray);
        EccentricityArray = transpose(EccentricityArray);
        PerimeterArray = transpose(PerimeterArray);
        DNAAreaArray = transpose(DNAAreaArray);
        DNAToCellRatioArray = transpose(DNAToCellRatioArray);
        DNAEccentricityArray = transpose(DNAEccentricityArray);
        DNALengthArray = transpose(DNALengthArray);
        DNAWidthArray = transpose(DNAWidthArray);
        DNAPerimeterArray = transpose(DNAPerimeterArray);
        c1TotalIntensityArray = transpose(c1TotalIntensityArray);
        c1MeanIntensityArray = transpose(c1MeanIntensityArray);
        c2TotalIntensityArray = transpose(c2TotalIntensityArray);
        c2MeanIntensityArray = transpose(c2MeanIntensityArray);
        c3TotalIntensityArray = transpose(c3TotalIntensityArray);
        c3MeanIntensityArray = transpose(c3MeanIntensityArray);
        
        % Concatenate Arrays
        CatArrays = cat(2, AreaArray, LengthArray, WidthArray, EccentricityArray,...
            PerimeterArray, DNAAreaArray, DNAToCellRatioArray,...
            DNAEccentricityArray, DNALengthArray, DNAWidthArray, DNAPerimeterArray,...
            c1TotalIntensityArray, c1MeanIntensityArray, c2TotalIntensityArray,...
            c2MeanIntensityArray, c3TotalIntensityArray, c3MeanIntensityArray);
        
        clear AreaArray;
        clear LengthArray;
        clear WidthArray;
        clear EccentricityArray;
        clear PerimeterArray;
        clear DNAAreaArray;
        clear DNAToCellRatioArray;
        clear DNAEccentricityArray;
        clear DNALengthArray;
        clear DNAWidthArray;
        clear DNAPerimeterArray;
        clear c1TotalIntensityArray;
        clear c1MeanIntensityArray;
        clear c2TotalIntensityArray;
        clear c2MeanIntensityArray;
        clear c3TotalIntensityArray;
        clear c3MeanIntensityArray;
        
        
        %% Create Data Table
        % if counter equals 1 creat array with names, else cat to the bottom of T
       
        T_temp = array2table(CatArrays,'VariableNames', {'Area', 'Length', 'Width',...
            'Eccentricity', 'Perimeter', 'NucleoidArea', 'NucleoidToCellRatio',...
            'NucleoidEccentricity', 'DNALengthArray', 'DNAWidthArray',...
            'DNAPerimeterArray', 'TotalSytox', 'MeanSytox','TotalFM464', 'MeanFM464',...
            'TotalDapi', 'MeanDapi'} );
        [pathstr,filename,ext] = fileparts(inputFolderPaths{iiCondition});
        RCtemp = strsplit(filename, {'_', '0'});
        RowColID = RCtemp{1};
        switch isExternalConditionKey
            case 'Yes'
                
                for ii = 1:numel(RowCol_array)
                    if strfind(RowCol_array{ii}, RowColID) == 1
                        treatmentName = Drug_array{ii};
                        for iii = 1:size(CatArrays, 1)
                            treatmentArray_temp(iii,:) = char(treatmentName);
                        end
                        T_treat = table(treatmentArray_temp,'VariableName',{'Treatment'});
                        clear treatmentArray_temp
                    end
                end
                
            case 'No'
                treatmentName = filename;
                for iii = 1:size(CatArrays, 1)
                    treatmentArray_temp(iii,:) = char(treatmentName);
                end
                
                if size(CatArrays,1)==1
                    treatmentArray_temp = {treatmentArray_temp};
                end
                T_treat = table(treatmentArray_temp,'VariableName',{'Treatment'});
                clear treatmentArray_temp

            otherwise
                warning('bcp:conditionKey:unknownStyle','Condition key labels missing. Please contact the developer.');
                return
        end
        
        % Join the Tables
        T_temp = horzcat(T_temp,T_treat);
        C_temp = table2cell(T_temp);
        clear T_treat
        
        C = vertcat(C, C_temp);
    end
end
% close the progressbar
progressbar(1);

%% Create Table and Save
T = cell2table(C, 'VariableName',{'Area', 'Length', 'Width',...
    'Eccentricity', 'Perimeter', 'NucleoidArea', 'NucleoidToCellRatio',...
    'NucleoidEccentricity', 'DNALengthArray', 'DNAWidthArray',...
    'DNAPerimeterArray', 'TotalSytox', 'MeanSytox','TotalFM464', 'MeanFM464',...
    'TotalDapi', 'MeanDapi','Drug'});
writetable(T, fullpathOutputFile);

%% Statistics

% Readtable takes a text file and reads it into a matlab table
T = readtable(fullpathOutputFile);
C2 = table2cell(T);
%%
X = cell2mat(C2(:,1:14));
[d,p,stats] = manova1(X, T.Drug);

H = manovacluster(stats);
set(gca,'XTickLabelRotation',90,'TickLabelInterpreter','none');

%%
% For calculating intensity of fm4064, sytox, and dapi its worthwhile to
% take the sum of the 'pixelvals' in regionprops instead of the mean
% intensity
% You need to extract the numbers from the STATS structure and populate
% some sort of matrix/spreadsheet that does not go away inbetween runs.
%
% Also, you should Wrap all of this code into a for loop and try to compile
% all of the data into the same set of structures each time it goes around
% the loop
% After all data are colected you need to do statistics on the results and
% generate bargraphs.