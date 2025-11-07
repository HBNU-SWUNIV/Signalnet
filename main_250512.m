%% section1: 초기 설정 및 SDR 객체 생성
clc; clear; close all;

useSDR = true; % true: SDR 하드웨어 캡처, false: 저장된 데이터 로드

% 항상 저장 경로 선행 정의
saveFileSupine  = fullfile(pwd, "dataset-Supine.mat");
saveFileLateral = fullfile(pwd, "dataset-Lateral.mat");

% SDR 관련 기본 설정
rxsim.DeviceName           = "B210";
rxsim.RadioGain            = 15;
rxsim.ChannelNumber        = 128;
rxsim.FrequencyBand        = 5;
rxsim.NumPacketsPerCapture = 20;
rxsim.BeaconInterval       = 150;
rxsim.BeaconSSID           = "";

rx = hSDRReceiver(rxsim.DeviceName);
rx.SampleRate       = 20e6;
rx.Gain             = 75;
rx.CenterFrequency  = wlanChannelFrequency(rxsim.ChannelNumber, rxsim.FrequencyBand);
rx.ChannelMapping   = 1;
rx.OutputDataType   = 'single';
rxsim.SDRObj        = rx;

rxsim.CaptureDuration = rxsim.BeaconInterval*milliseconds(1.024)*rxsim.NumPacketsPerCapture + milliseconds(5.5);

msgbox("SDR 설정 완료. 다음 단계 실행하세요.");

%% section2: 캡처 및 저장 설정
maxRetries      = 5;
capturePerBatch = 10; % 한 배치당 캡처 개수
numBatches      = 50; % 반복 횟수 (총 capturePerBatch*numBatches 장)

%% ---------- Supine 데이터 캡처 ----------
if useSDR
    for batchIdx = 1:numBatches
        tempDataSupine     = [];
        tempLabelSupine    = [];
        tempTimestampSupine= [];
        fprintf("Supine Batch %d 시작\n", batchIdx);

        for i = 1:capturePerBatch
            retryCount = 0; success = false;
            while ~success && retryCount < maxRetries
                try
                    rxsimTmp = rxsim; rxsimTmp.NumCaptures = 1;
                    [d,l,t] = captureCSIDataset(rxsimTmp, "Supine");
                    if ndims(d) == 2
                        d = reshape(d, size(d,1), size(d,2), 1);
                    end
                    if isempty(tempDataSupine)
                        tempDataSupine = d;
                    elseif isequal(size(tempDataSupine(:,:,1)), size(d))
                        tempDataSupine = cat(3, tempDataSupine, d);
                    else
                        warning("Supine 데이터 차원 불일치 - 무시"); break;
                    end
                    tempLabelSupine    = [tempLabelSupine; l];
                    tempTimestampSupine= [tempTimestampSupine; t];
                    success = true;
                catch ME
                    warning("Supine capture failed: %s. 재시도 (%d/%d)...", ME.message, retryCount+1, maxRetries);
                    retryCount = retryCount + 1; pause(0.5);
                end
            end
            if ~success
                warning("Supine capture 실패 - 최대 재시도 초과, 이번 샘플 건너뜀"); continue;
            end
        end

        if isfile(saveFileSupine)
            S = load(saveFileSupine);
            dataSupine     = cat(3, S.dataSupine, tempDataSupine);
            labelSupine    = [S.labelSupine; tempLabelSupine];
            timestampSupine= [S.timestampSupine; tempTimestampSupine];
        else
            dataSupine     = tempDataSupine;
            labelSupine    = tempLabelSupine;
            timestampSupine= tempTimestampSupine;
        end
        save(saveFileSupine, "dataSupine", "labelSupine", "timestampSupine", "-v7.3");
        fprintf("Supine Batch %d 저장 완료 (총 %d개)\n", batchIdx, size(dataSupine,3));
    end
else
    [dataSupine, labelSupine, timestampSupine] = loadCSIDataset(saveFileSupine, "Supine");
end

%% ---------- Lateral 데이터 캡처 ----------
if useSDR
    for batchIdx = 1:numBatches
        tempDataLateral     = [];
        tempLabelLateral    = [];
        tempTimestampLateral= [];
        fprintf("Lateral Batch %d 시작\n", batchIdx);

        for i = 1:capturePerBatch
            retryCount = 0; success = false;
            while ~success && retryCount < maxRetries
                try
                    rxsimTmp = rxsim; rxsimTmp.NumCaptures = 1;
                    [d,l,t] = captureCSIDataset(rxsimTmp, "Lateral");
                    if ndims(d) == 2
                        d = reshape(d, size(d,1), size(d,2), 1);
                    end
                    if isempty(tempDataLateral)
                        tempDataLateral = d;
                    elseif isequal(size(tempDataLateral(:,:,1)), size(d))
                        tempDataLateral = cat(3, tempDataLateral, d);
                    else
                        warning("Lateral 데이터 차원 불일치 - 무시"); break;
                    end
                    tempLabelLateral    = [tempLabelLateral; l];
                    tempTimestampLateral= [tempTimestampLateral; t];
                    success = true;
                catch ME
                    warning("Lateral capture failed: %s. 재시도 (%d/%d)...", ME.message, retryCount+1, maxRetries);
                    retryCount = retryCount + 1; pause(0.5);
                end
            end
            if ~success
                warning("Lateral capture 실패 - 최대 재시도 초과, 이번 샘플 건너뜀"); continue;
            end
        end

        if isfile(saveFileLateral)
            S = load(saveFileLateral);
            dataLateral     = cat(3, S.dataLateral, tempDataLateral);
            labelLateral    = [S.labelLateral; tempLabelLateral];
            timestampLateral= [S.timestampLateral; tempTimestampLateral];
        else
            dataLateral     = tempDataLateral;
            labelLateral    = tempLabelLateral;
            timestampLateral= tempTimestampLateral;
        end
        save(saveFileLateral, "dataLateral", "labelLateral", "timestampLateral", "-v7.3");
        fprintf("Lateral Batch %d 저장 완료 (총 %d개)\n", batchIdx, size(dataLateral,3));
    end
else
    [dataLateral, labelLateral, timestampLateral] = loadCSIDataset(saveFileLateral, "Lateral");
end

%% section3: 데이터셋 불러오기, 전처리, 분할 및 강화된 CNN 구성
[dataSupine, labelSupine, timestampSupine]   = loadCSIDatasetWrapper("dataset-Supine.mat", "Supine", false);
[dataLateral, labelLateral, timestampLateral]= loadCSIDatasetWrapper("dataset-Lateral.mat", "Lateral", false);

normalizeCSI = @(x) (abs(x) - mean(abs(x),'all')) / std(abs(x),0,'all');
dataSupine   = normalizeCSI(dataSupine);
dataLateral  = normalizeCSI(dataLateral);
disp('데이터 정규화 완료');

trainingRatio = 0.8;
[trainingData, validationData, testData, imgInputSize, uniqueClassLabels] = ...
    trainValTestSplit(false, trainingRatio, dataSupine, labelSupine, dataLateral, labelLateral);

numClasses = numel(uniqueClassLabels);
disp('학습/검증/테스트 데이터 분할 완료');

cnnLayers = [
    imageInputLayer(imgInputSize,'Normalization','none')
    convolution2dLayer(3,16,'Padding','same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2,'Stride',2)

    convolution2dLayer(3,32,'Padding','same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2,'Stride',2)

    convolution2dLayer(3,64,'Padding','same')
    batchNormalizationLayer
    reluLayer
    dropoutLayer(0.2)

    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer
];
disp('강화된 CNN 구조 생성 완료');

options = trainingOptions('adam', ...
    'InitialLearnRate', 0.001, ...
    'MaxEpochs', 20, ...
    'MiniBatchSize', 16, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', validationData, ...
    'ValidationFrequency', 30, ...
    'ExecutionEnvironment', 'auto', ...
    'Verbose', true, ...
    'Plots', 'training-progress');
disp('CNN 학습 옵션 설정 완료');

%% section4: CNN 학습 및 예측
trainedCNN = trainNetwork(trainingData, cnnLayers, options);

if useSDR
    sensingResults = livePresenceDetection(rxsim, trainedCNN, uniqueClassLabels, 20);
else
    sensingResults = testPresenceDetection(testData, trainedCNN);
end
