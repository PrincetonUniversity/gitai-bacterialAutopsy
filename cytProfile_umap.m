
%% Read in cytological profiling data and run umap
fullPathInputFile = uipickfiles();

% Readtable takes a text file and reads it into a matlab table
T = readtable(fullPathInputFile{1});
C2 = table2cell(T);

X = cell2mat(C2(:,1:14));

% normalize by subtracting off mean and dividing by standard deviation
x2 = X-mean(X);
x2 = x2./std(X);

% run umap for dimensionality reduction with defaults
[reduction2, umap2, clusterIdentifiers2] = run_umap(x2);
%% Visualize results, highlighting a specific treatment group

% list of treatments
drugNames = unique(T.Drug);

% create simple GUI to prompt the user for which condition they would like
% to highlight
figHand1 = figure();
listbox1 = uicontrol(figHand1,'Style','listbox',...
    'units','normalized','position',[0.15,0.15,0.7,0.65],...
    'FontSize',14);
set(listbox1,'String',drugNames);
% kludgy single line way of grabbing the selection
set(listbox1,'Callback',...
    'assignin(''caller'',''cytprofile_umap_selection'',get(gcbo,''value''));');
% use a default of the first element if th user doesn't select anything
assignin('caller','cytprofile_umap_selection',get(listbox1,'value'));

questionText = uicontrol(figHand1,'Style','text',...
        'units','normalized','position',[0.1,0.8,0.8,0.1],...
    'FontSize',18);
set(questionText,'String','Please select the condition to highlight');

confirmButton = uicontrol(figHand1,'Style','pushbutton',...
    'Units','normalized','position',[0.4,0.05,0.2,0.075]);

set(confirmButton,'string','Continue');

set(confirmButton,'Callback',...
    'close(get(gcbo,''Parent''));');

waitfor(figHand1);

%
% select a specific group of interest to highlight
drugOfInterest = drugNames{cytprofile_umap_selection};
idxOfInterest = ismember(T.Drug,drugOfInterest);

% visualization settings
edges2 = linspace(-9,9,800);

% calculate densities
density2 = histcn(reduction2(idxOfInterest,:),edges2,edges2);
density3 = histcn(reduction2(~idxOfInterest,:),edges2,edges2);

figure();
% gentle smoothing
kern2 = exp(-(-32:32).^2./(2*10^2));
kern2 = kern2.*kern2';
kern2 = kern2./sum(kern2(:));

density2b = conv2(density2,kern2,'same');
density3b = conv2(density3,kern2,'same');

density3b = density3b./max(density3b(:));
density2b = density2b./max(density2b(:));

colorbarNums = linspace(0,1,size(density2b,1));
colorbarNums = repmat(colorbarNums',1,32);

% build up RGB image
highlightedColorCoeffs = [0.6,0.1,0.6];
highlightedColorCoeffs = highlightedColorCoeffs./sqrt(sum(highlightedColorCoeffs.^2));

otherTreatmentColorCoeffs = [0.8,0.6,0.1];
otherTreatmentColorCoeffs = otherTreatmentColorCoeffs./sqrt(sum(otherTreatmentColorCoeffs.^2));

colorizedImage = zeros(size(density2,1),size(density2,2)+64,3);

for ii = 1:3
    colorizedImage(:,:,ii) = colorizedImage(:,:,ii)+highlightedColorCoeffs(ii).*(cat(2,density2b,colorbarNums-colorbarNums,colorbarNums));
    colorizedImage(:,:,ii) = colorizedImage(:,:,ii)+otherTreatmentColorCoeffs(ii).*(cat(2,density3b,colorbarNums,colorbarNums-colorbarNums));
end

% display colorized image
imshow(colorizedImage,[]);
title(['Highlighting: ',drugOfInterest],'Interpreter','none');
