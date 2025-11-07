function sensingResults = livePresenceDetection(rxsim,net,classNames,numCaptures,plotCapture)
% livePresenceDetection Captures and visualizes CSI and makes live predictions about human presence
%   SENSINGRESULTS =
%   livePresenceDetection(RXSIM,NET,CLASSNAMES,NUMCAPTURES,PLOTCAPTURE)
%   performs (NUMCAPTURES) over-the-air WLAN waveform captures using the
%   SDR object (RXSIM) and extracts CSI from the beacon frames. The CSI is
%   then used to make inferences about human presence using the trained
%   network (NET) and the sensing class labels (CLASSNAMES). The captured
%   CSIs and the human presence inference results are plotted if the
%   visualization option (PLOTCAPTURE) is set to true. The default value
%   for visualization is true. The function returns the categorical
%   prediction vector and timestamps in a cell array (SENSINGRESULTS).

%   Copyright 2022-2024 The MathWorks, Inc.
arguments
    rxsim (1,1) struct;
    net (1,1);
    classNames;
    numCaptures (1,1);
    plotCapture (1,1) = true;
end

predictionVec = []; % Initialization of the prediction vector for CNN inference
plotWindow = 10; % Number of latest CNN inferences that will be plotted

% Capture, extract, and visualize CSI of the beacon frames
figure;
visualizeCSIFcn = @(data,timestamps,i) plotLiveInference(data,timestamps,i);
[~,timestamps] = captureVisualizeCSI(rxsim,numCaptures,visualizeCSIFcn,plotCapture);
sensingResults = {predictionVec timestamps};

% Plot live captured samples
    function plotLiveInference(data,timestamps,i)
        inputCSI = abs(data(:,:,i)); % Visualize only the magnitude of CSI
        T = tiledlayout(2,2,'TileSpacing','compact');

        % Plot 1 - CSI magnitude response
        nexttile
        imagesc(inputCSI);
        colorbar;
        xlabel('Frames');
        ylabel('Subcarriers');
        xlim tight;

        % Plot 2 - Normalized CSI periodogram
        nexttile
        imagesc(csi2periodogram(inputCSI));
        colorbar;
        clim([0 1]);
        xlabel('Temporal Index');
        ylabel('Spatial Index');

        % Plot 3 - Live capture based inference plot
        % Predict live presence using CNN
        predictionVec = cat(1,predictionVec,scores2label(predict(net,csi2periodogram(inputCSI)),classNames));

        if size(timestamps,1)<plotWindow
            nexttile([1 2])
            plot(timestamps,predictionVec,'b:o','MarkerFaceColor','b');
            xticks(timestamps);
            xtickformat('HH:mm:ss');
            xlim tight;
        else
            nexttile([1 2])
            plot(timestamps(size(timestamps,1)-plotWindow+1:size(timestamps,1)),...
                predictionVec(size(timestamps,1)-plotWindow+1:size(timestamps,1)),'b:o','MarkerFaceColor','b','MarkerSize',4);
            xticks(timestamps);
            xtickformat('HH:mm:ss');
            xlim([timestamps(size(timestamps,1)-plotWindow+1) timestamps(size(timestamps,1))]);
        end
        ylim tight;
        ylabel('Prediction');
        xlabel('Timestamp');
        title(T,['Capture ' num2str(i) ' - Prediction: ' '{\color{red}' upper(char(predictionVec(end))) '}'],'FontWeight','bold');
        set(gcf,'Position',[0 0 600 400]);
        drawnow;
    end
end