function sensingAccuracy = testPresenceDetection(testData, net, classNames)
% testPresenceDetection Visualizes the human presence detection performance of the trained network
%   SENSINGACCURACY = testPresenceDetection(TESTDATA,NET,CLASSNAMES)
%   predicts human presence from unseen test data (TESTDATA) using the
%   trained network (NET) and the sensing class labels (CLASSNAMES). The
%   detection accuracy is calculated and returned as a scalar parameter
%   (SENSINGACCURACY).

% Generate prediction vector using classify (batch 처리)
predictionVec = classify(net, testData);

% Read ground truth labels from datastore
groundTruthTbl = readall(testData);
groundTruthVec = cat(1, groundTruthTbl{:, 2});

% Plot confusion matrix
figure;
cm = confusionchart(groundTruthVec, predictionVec, Normalization='row-normalized');

% Calculate accuracy
sensingAccuracy = sum(diag(cm.NormalizedValues)) / sum(cm.NormalizedValues(:)) * 100;
cm.Title = ['Sensing Accuracy = ' num2str(sensingAccuracy) '%'];

end
