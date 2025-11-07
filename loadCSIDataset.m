function [data,labelsVec,timestamps] = loadCSIDataset(fileName,label,visualizeData)
% loadCSIDataset Loads and visualizes the pre-recorded CSI dataset
%   [DATA,LABELSVEC,TIMESTAMPS] =
%   loadCSIDataset(FILENAME,LABEL,VISUALIZEDATA) loads the dataset that
%   contains the data with the label (LABEL). Pre-recorded CSIs are
%   visualized if (VISUALIZEDATA) is true. The function returns the
%   pre-recorded beacon frame CSI (DATA), related timestamps (TIMESTAMPS),
%   and the categorical labels vector (LABELSVEC).

%   Copyright 2022-2024 The MathWorks, Inc.
arguments
    fileName {char,string}
    label (1,1) string
    visualizeData = true;
end

% Load the pre-recorded dataset
datasetDir = which(fileName);
loadedData = load(datasetDir);
data = loadedData.data;
labelsVec = categorical(repmat(label,size(data,ndims(data)),1));
timestamps = loadedData.timestamps;
disp(['Dimensions of the ' char(label) ' dataset (numSubcarriers x numPackets x numCaptures): ' '['  num2str(size(data)) ']'])

% Visualize the dataset
if visualizeData
    plotSamplesFromDataset(data,label);
end

% Plot samples from the pre-recorded dataset
    function plotSamplesFromDataset(data,mode)
        % Plot at most three random samples of the dataset
        inputData = abs(data); % Visualize only the magnitude of the CSI
        numTotalCaptures = size(inputData,ndims(inputData));
        numPlots = min(3,numTotalCaptures);
        idxSelected = sort(randperm(numTotalCaptures,numPlots));

        figure;
        T = tiledlayout(2,numPlots,'TileSpacing','compact');

        % Plot 1 - CSI image
        for i = 1:numPlots
            nexttile
            imagesc(inputData(:,:,idxSelected(i)));
            colorbar;
            xlabel('Packets');
            ylabel('Subcarriers');
            title(['Raw CSI (#' num2str(idxSelected(i)),')']);
        end

        % Plot 2 - Normalized CSI periodogram
        for j = 1:numPlots
            nexttile
            imagesc(csi2periodogram(inputData(:,:,idxSelected(j))));
            colorbar;
            clim([0 1]);
            xlabel('Temporal Index');
            ylabel('Spatial Index');
            title(['CSI Periodogram (#' num2str(idxSelected(j)),')']);
            title(T,['Randomly Selected Samples of "', char(mode) '" Data']);
            set(gcf,'Position',[0 0 650 450]);
        end
    end
end