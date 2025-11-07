%% section1
clc
clear
close all

useSDR = true; % You can skip this section if unchecked

if useSDR
    % User-defined parameters
    rxsim.DeviceName    = "B210";
    rxsim.RadioGain     = 15; % Can be 'AGC Slow Attack', 'AGC Fast Attack', or an integer value. See relevant documentation for selected radio for valid values of radio gain.
    rxsim.ChannelNumber = 36; % Valid values for 5 GHz band are integers in range [1, 200]
    rxsim.FrequencyBand = 5; % in GHz

    % Set up SDR receiver object
    rx = hSDRReceiver(rxsim.DeviceName);
    rx.SampleRate = 20e6; % Configured for 20 MHz since this is beacon transmission bandwidth
    rx.Gain = rxsim.RadioGain;
    rx.CenterFrequency = wlanChannelFrequency(rxsim.ChannelNumber,rxsim.FrequencyBand);
    rx.ChannelMapping = 1;
    rx.OutputDataType = 'single';

    rxsim.SDRObj = rx;
end

if useSDR %#ok<*UNRCH>
    % User defined parameters
    rxsim.NumCaptures          = 10;
    rxsim.NumPacketsPerCapture = 8;
    rxsim.BeaconInterval       = 100; % in time units (TUs). The default value in typical APs is 100.
    rxsim.BeaconSSID           = ""; % Optional

    % Calculated parameters
    rxsim.CaptureDuration = rxsim.BeaconInterval*milliseconds(1.024)*rxsim.NumPacketsPerCapture + milliseconds(5.5); % Add 5.5 ms for beacons located at the end of the waveform

    % SDR setup is complete
    msgbox("SDR object configuration is complete! Run steps 1 and 2 to capture data.")
    return % Stop execution
end


%% section2
if useSDR % Capture live CSI with SDR
    [dataNoPresence,labelNoPresence,timestampNoPresence] = captureCSIDataset(rxsim,"no-presence");
else % No SDR hardware, load CSI dataset
    [dataNoPresence,labelNoPresence,timestampNoPresence] = loadCSIDataset("dataset-no-presence.mat","no-presence");
end
%%
if useSDR % Capture CSI with SDR
    [dataPresence,labelPresence,timestampPresence] = captureCSIDataset(rxsim,"presence");
else % No SDR hardware, load CSI dataset
    [dataPresence,labelPresence,timestampPresence] = loadCSIDataset("dataset-presence.mat","presence");
end

%% section 3
trainingRatio =  0.8;
numEpochs = 10;
sizeMiniBatch = 8;
[trainingData,validationData,testData,imgInputSize,uniqueClassLabels] = trainValTestSplit(useSDR,trainingRatio,dataNoPresence,labelNoPresence,dataPresence,labelPresence);
% --- 디버깅 및 numClasses 수정 시작 ---
fprintf('Value of uniqueClassLabels (from trainValTestSplit): \n');
disp(uniqueClassLabels);
fprintf('Type of uniqueClassLabels: %s\n', class(uniqueClassLabels));

if iscell(uniqueClassLabels)
    numClasses = numel(uniqueClassLabels);
else
    error('trainValTestSplit did not return a cell array');
end

cnn = [
    imageInputLayer(imgInputSize,'Normalization','none')
    convolution2dLayer(3,8,'Padding','same')
    batchNormalizationLayer
    reluLayer

    maxPooling2dLayer(2,'Stride',2)
    
    convolution2dLayer(3,16,'Padding','same')
    batchNormalizationLayer
    reluLayer

    maxPooling2dLayer(2,'Stride',2)

    convolution2dLayer(3,32,'Padding','same')
    batchNormalizationLayer
    reluLayer
    
    dropoutLayer(0.1)
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer];

cnn = layerGraph(cnn);
disp(cnn.Layers)

% Definition of the training options
options = trainingOptions('adam', ...
    LearnRateSchedule='piecewise', ...
    InitialLearnRate=0.001, ... % learning rate
    MaxEpochs=numEpochs, ...
    MiniBatchSize=sizeMiniBatch, ...
    ValidationData=validationData, ...
    Shuffle='every-epoch', ...
    ExecutionEnvironment='auto',...
    Verbose=true);

%% section 4
% Train the network
trainedCNN = trainNetwork(trainingData,cnn,options);

if useSDR % Predict movement from the live SDR captures
    sensingResults = livePresenceDetection(rxsim, trainedCNN, uniqueClassLabels, 20);
else % Predict movement by using the test set
    sensingResults = testPresenceDetection(testData,trainedCNN);
end