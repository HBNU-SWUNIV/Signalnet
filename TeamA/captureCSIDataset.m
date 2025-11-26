function [data,labelsVec,timestamps] = captureCSIDataset(rxsim,label,visualizeCapture,dispStatus)
% captureCSIDataset Generates CSI dataset based on the SDR captures
%   [DATA,LABELSVEC,TIMESTAMPS] =
%   captureCSIDataset(RXSIM,LABEL,VISUALIZECAPTURE,DISPSTATUS) captures
%   over-the-air WLAN waveforms using the SDR object (RXSIM) and filters
%   them based on the beacon frames. Captured CSIs are visualized if the
%   visualization option (VISUALIZECAPTURE) is set to true, and the capture
%   status is printed if the display option (DISPSTATUS) is set to true.
%   The default for both options is true. The function returns the beacon
%   frame CSI (DATA), related timestamps vector (TIMESTAMPS), and
%   categorical labels vector (LABELSVEC) based on the user input (LABEL).

%   Copyright 2022-2024 The MathWorks, Inc.
arguments
    rxsim (1,1) struct;
    label(1,1) string;
    visualizeCapture (1,1) = true;
    dispStatus (1,1) = true;
end

% Capture, extract and visualize CSI of the beacon frames
figure;
visualizeCSIFcn = @(data,timestamps,i) plotCapture(data,rxsim,i);
[data,timestamps] = captureVisualizeCSI(rxsim,rxsim.NumCaptures,visualizeCSIFcn,visualizeCapture,dispStatus);

% Create the labels vector that matches the data and timestamps
labelsVec = categorical(repmat(label,size(data,ndims(data)),1));

    function plotCapture(data,rxsim,i)
        inputCSI = abs(data(:,:,i)); % Visualize only the magnitude of CSI
        T = tiledlayout(1,2,'TileSpacing','compact');

        % Create plots
        % Plot 1 - CSI Magnitude Response Image
        nexttile
        imagesc(inputCSI);
        colorbar;
        xlabel('Packets');
        ylabel('Subcarriers');
        title('Raw CSI Magnitude');
        
        % Plot 2 - Normalized CSI Periodogram
        nexttile
        imagesc(csi2periodogram(inputCSI));
        colorbar;
        clim([0 1]);
        xlabel('Temporal Index');
        ylabel('Spatial Index');
        title('Normalized CSI Periodogram');
        title(T,['Capture ' num2str(i) '/' num2str(rxsim.NumCaptures) ' (' char(label) ')']);
        set(gcf,'Position',[0 0 450 250]);
        drawnow;
    end
end
