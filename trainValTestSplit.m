function [trainData,valData,testData,imageSize,classNames] = ...
    trainValTestSplit(useSDR,trainRatio,dataNoPresence,labelNoPresence,dataPresence,labelPresence)
% trainValTestSplit Splits the data into training, validation, and test datasets
%   trainValTestSplit(useSDR, trainRatio, dataNoPresence, labelNoPresence,
%   dataPresence, labelPresence) takes the SDR captured or pre-recorded CSI
%   captures (DATANOPRESENCE) and (DATAPRESENCE) and their associated
%   labels (LABELNOPRESENCE) and (labelPresence), randomly splits them into
%   training (TRAINDATA), validation (VALDATA), and test (TESTDATA)
%   datasets based on SDR hardware availability (USESDR) and user-defined
%   training ratio (TRAINRATIO). The unique "no-presence" and "presence"
%   labels set is returned in (CLASSNAMES), and the CSI image size is
%   returned in (IMAGESIZE). The returned datasets are arrayDatastore
%   objects.
%
%   dataNoPresence and dataPresence are single complex
%   numSubcarriers-by-rxsim.NumPacketsPerCapture-by-rxsim.NumCaptures
%   arrays that contain the extracted CSI for "no-presence" and "presence"
%   labels, respectively.
%
%   labelNoPresence and labelPresence are rxsim.NumCaptures-by-1
%   categorical vectors that contain the labels corresponding to
%   "no-presence" and "presence" data, respectively.

%   Copyright 2022-2024 The MathWorks, Inc.

% Train/test data split
% size xData: [numTimeFrames, numSubcarriers, numSnapshots]
% size yData: [numSnapshots, 1]
xData = cat(3,dataNoPresence,dataPresence);
yData = cat(1,labelNoPresence,labelPresence);
classNames = categories(yData); % Set of unique sensing class names

% Obtain the CSI periodogram
xData = csi2periodogram(abs(xData));

imageSize = size(xData,1:ndims(xData)-1); % The last dimension is the batch dimension

if useSDR
    % Cannot perform testing using live captures if SDR is enabled
    valRatio = 1-trainRatio;
    testRatio = 0;
else
    % If a pre-recorded dataset is used, the sizes of the validation and
    % test sets are equal
    valRatio = (1-trainRatio)/2;
    testRatio = valRatio;
end

% Generate random indices for train/validation/test set splits
[trainInd,valInd,testInd] = dividerand(size(xData,3),trainRatio,valRatio,testRatio);

% Split dataset into training, validation, and test sets
xTrain = xData(:,:,trainInd);
xValid = xData(:,:,valInd);
xTest = xData(:,:,testInd);

% Split labels into training, validation, and test sets
yTrain = yData(trainInd);
yValid = yData(valInd);
yTest = yData(testInd);

% Convert the training dataset into a datastore
arrds = arrayDatastore(xTrain, "IterationDimension", 3);
labelds = arrayDatastore(yTrain, "IterationDimension", 1);
trainData = combine(arrds, labelds);

% Display information about the training data
disp(['CSI image size: [',num2str(imageSize),']'])
disp(['Number of training images: ', num2str(numpartitions(trainData))])

% Convert the validation dataset into a datastore
if ~isempty(valInd)
    arrds2 = arrayDatastore(xValid, "IterationDimension", 3);
    labelds2 = arrayDatastore(yValid, "IterationDimension", 1);
    valData = combine(arrds2, labelds2);
    disp(['Number of validation images: ', num2str(numpartitions(valData))])
else
    valData = []; % No validation data
end

% Convert the test dataset into a datastore
arrds3 = arrayDatastore(xTest, "IterationDimension", 3);
labelds3 = arrayDatastore(yTest, "IterationDimension", 1);
testData = combine(arrds3, labelds3);
disp(['Number of test images: ', num2str(numpartitions(testData))])
end