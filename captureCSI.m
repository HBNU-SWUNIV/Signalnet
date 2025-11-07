function [csi, timestamp, packetSize] = captureCSI(i,numCaptures,sdrObj,captureDuration,numPackets,opts)
%captureCSI Captures and extracts CSI from the WLAN waveform
%   captureCSI(i,numCaptures,sdrObj,captureDuration,numPackets,opts)
%   captures over-the-air WLAN waveforms using the SDR object (SDROBJECT)
%   that is configured using (OPTS). The current capture number (I), total
%   number of captures that will be taken (NUMCAPTURES), duration of
%   each capture (CAPTUREDURATION) and number of beacon packets we would
%   like to capture in each burst (NUMPACKETS) are inputs of the function.
%   The extracted CSI matrix (CSI) and capture timestamp (TIMESTAMP) are
%   returned.

%   Copyright 2022-2024 The MathWorks, Inc.
    arguments
        i
        numCaptures
        sdrObj
        captureDuration (1,1) {mustBeA(captureDuration,'duration')}
        numPackets
        % Use this to see information about other non-HT captured packets
        opts.DisplayAdditionalInfo (1,1) {mustBeNumericOrLogical} = false
        % Only extract CSI data for a specific non-HT packet frame type
        opts.ExtractOnlySpecificPacket (1,1) {mustBeNumericOrLogical} = true
        % Specific packet frame type to extract. Values must match
        % FrameType in wlanMACFrameConfig (e.g. ["Beacon", "QoS Data"])
        opts.PacketTypeToExtract {mustBeText} = "Beacon"
        % Filter beacons based on SSID
        opts.SSIDFilter (1,1) {mustBeText} = "";
        % Use this to see information about the captures
        opts.DisplayCaptureStatus (1,1) logical = true;
        % Use this to vary the capture size when using the preamble detector
        opts.PacketSize (1,1) double = 5.5e-3*20e6;
    end

    isPDObj = isa(sdrObj,'preambleDetector');

    % Variable initialization
    nextCSIDataPoint = 1;
    if isPDObj
        datatype = sdrObj.CaptureDataType;
    else
        datatype = sdrObj.OutputDataType;
    end
    csi = zeros(52,numPackets,datatype);
    packetSize = zeros(numPackets,1,datatype);
    osf = sdrObj.SampleRate/20e6;
    cbw = 'CBW20';

    % Non-HT config for waveform processing
    cfg = wlanNonHTConfig(ChannelBandwidth=cbw);
    ind = wlanFieldIndices(cfg);

    % Max non-HT packet transmission time is 5.5 ms at 20 MHz
    if isPDObj
        nonHTPacketSize = opts.PacketSize;
        chunkSize = 1;
    else
        maxDurationNonHT = 5.5e-3;
        nonHTPacketSize = ceil(maxDurationNonHT*sdrObj.SampleRate/osf);
        chunkSize = nonHTPacketSize;
    end

    % Initilize capture with SDR
    if numCaptures < Inf
        dispMsg(['Initiating capture ',num2str(i) '/' num2str(numCaptures), ' '],opts.DisplayCaptureStatus)
    else
        dispMsg(['Initiating capture ',num2str(i), ' '],opts.DisplayCaptureStatus)
    end

    % Capture signature different depending on if using preambleDetector object
    if isPDObj
        minNumCaptures = ceil(seconds(captureDuration)*sdrObj.SampleRate/nonHTPacketSize);
        timeout = captureDuration*(1+1/numPackets);
        [capturedData, timestamps] = capture(sdrObj,nonHTPacketSize,timeout,NumCaptures=minNumCaptures);
        if isempty(capturedData)
            csi = [];
            timestamp = [];
            packetSize = [];
            dispMsg(' | Capture complete - No packets detected.\n',opts.DisplayCaptureStatus)
            return;
        end
        timestamp = timestamps(1);
        idxsFullCaptures = cellfun(@(x)isequal(length(x),nonHTPacketSize),capturedData);
        capturedData = [capturedData{idxsFullCaptures}];
    else
        [capturedData, timestamp] = capture(sdrObj,captureDuration);
    end
    dispMsg([' | Capture complete - ' char(timestamp) ' | Processing waveform...'],opts.DisplayCaptureStatus)

    % Resample the captured data to 20 MHz for beacon processing
    if osf ~= 1
        capturedData = resample(capturedData,20e6,sdrObj.SampleRate);
    end

    % Append zeros to capturedData if captureData cannot be split evenly
    % into chunkSize
    if ~isPDObj
        if mod(length(capturedData),chunkSize) ~= 0
            capturedData = [capturedData;zeros(chunkSize-mod(length(capturedData),chunkSize),1)];
        end
        capturedData = reshape(capturedData,chunkSize,[]);
    end

    % Configure recoverPreamble options
    cfgAlg = struct;
    cfgAlg.PacketDetectionThreshold = 0.5;
    cfgAlg.EnergyDetection = false;
    cfgAlg.EnergyDetectionThreshold = 0;
    cfgAlg.EnergyDetectionWindow = 20;
    cfgAlg.LLTFChannelEstimateSmoothingSpan = 1;
    cfgAlg.DetectCarrierLoss = true;
    cfgAlg.DetectPowerFluctuation = true;
    cfgAlg.DetectLLTFSNRTooLow = false;
    cfgAlg.LLTFSNRDetectionThreshold = 0;
    cfgAlg.SkipPacketDetection = isPDObj;


    for j = 1:size(capturedData,2)
        % Exit for loop once the number of specified packets is acquired
        if nextCSIDataPoint>numPackets
            break
        end
        dataForAnalysis = capturedData(:,j);

        searchOffset = 0;
        while searchOffset<chunkSize && nextCSIDataPoint<=numPackets

            % recoverPreamble detects a packet and performs analysis of the
            % non-HT preamble.
            [preambleStatus,res] = recoverPreamble(dataForAnalysis,cbw,searchOffset,cfgAlg);

            if matches(preambleStatus,"No packet detected")
                break;
            end

            % Retrieve synchronized data and scale it with LSTF power
            % as done in the recoverPreamble function
            if ~isPDObj && (res.PacketOffset+nonHTPacketSize) > length(dataForAnalysis)
                % Only extended dataForAnalysis if there is another
                % waveform chunk to extend to.
                if j ~= size(capturedData,2)
                    dataForAnalysisExtended = [dataForAnalysis; capturedData(:,j+1)];
                    syncData = dataForAnalysisExtended(res.PacketOffset+(1:nonHTPacketSize))./sqrt(res.LSTFPower);
                else
                    break;
                end
            else
                syncData = dataForAnalysis((res.PacketOffset+1):end)./sqrt(res.LSTFPower);
            end

            syncData = frequencyOffset(syncData,sdrObj.SampleRate/osf,-res.CFOEstimate);


            fmtDetect = double(syncData(ind.LSIG(1):(ind.LSIG(2)+4e-6*sdrObj.SampleRate/osf*3)));
            chanEst = double(res.ChanEstNonHT);
            noiseEst = double(res.NoiseEstNonHT);

            [LSIGBits, failcheck] = wlanLSIGRecover(fmtDetect(1:4e-6*sdrObj.SampleRate/osf*1),chanEst,noiseEst,cbw);
            if failcheck
                % L-SIG recovery failed; shift packet search offset by
                % 10 OFDM symbols (minimum packet length of non-HT) for
                % next iteration of while loop.
                searchOffset = res.PacketOffset + 4e-6*sdrObj.SampleRate/osf*10;
                continue
            end

            format = wlanFormatDetect(fmtDetect,chanEst,noiseEst,cbw);
            if ~matches(format,"Non-HT")
                % Packet is NOT non-HT; shift packet search offset by 10
                % OFDM symbols (minimum packet length of non-HT) for next
                % iteration of while loop.
                searchOffset = res.PacketOffset + 4e-6*sdrObj.SampleRate/osf*10;
                continue
            end

            if ~opts.ExtractOnlySpecificPacket
                % Return CSI for any non-HT packet
                csi(:,nextCSIDataPoint) = res.ChanEstNonHT;
                nextCSIDataPoint = nextCSIDataPoint + 1;
            end

            if (opts.DisplayAdditionalInfo || opts.ExtractOnlySpecificPacket)
                % Extract MCS from first 3 bits of L-SIG.
                rate = double(bit2int(LSIGBits(1:3),3));
                if rate <= 1
                    cfg.MCS = rate + 6;
                else
                    cfg.MCS = mod(rate,6);
                end

                % Determine PSDU length from L-SIG.
                cfg.PSDULength = double(bit2int(LSIGBits(6:17),12,0));
                ind.NonHTData = wlanFieldIndices(cfg,"NonHT-Data");

                % Extract data field and attempt decode
                if isPDObj && ind.NonHTData(2) > length(syncData)
                    % Exit if not enough samples to fully decode; this should
                    % only happen with the preambleDetector
                    break;
                end

                nonHTData = double(syncData(ind.NonHTData(1):ind.NonHTData(2)));
                bitsData = wlanNonHTDataRecover(nonHTData,chanEst,noiseEst,cfg);
                [cfgMAC, ~, decodeStatus] = wlanMPDUDecode(bitsData,cfg,SuppressWarnings=true);

                if decodeStatus==wlanMACDecodeStatus.Success
                    if opts.DisplayAdditionalInfo
                        % Print additional information on all successfully
                        % decoded packets
                        payloadSize = floor(length(bitsData)/8);
                        [modulation,coderate] = getRateInfo(cfg.MCS);

                        fprintf('Payload Size: %d | Modulation: %s | Code Rate: %s \n',payloadSize,modulation,coderate);
                        fprintf('Type: %s | Sub-Type: %s \n',cfgMAC.getType,cfgMAC.getSubtype);
                    end

                    if (opts.ExtractOnlySpecificPacket && matches(cfgMAC.FrameType,opts.PacketTypeToExtract)) && ...
                            ((~isempty(char(opts.SSIDFilter)) && matches(cfgMAC.FrameType,"Beacon") && matches(cfgMAC.ManagementConfig.SSID,opts.SSIDFilter)) || ...
                             isempty(char(opts.SSIDFilter)) || ...
                             ~matches(cfgMAC.FrameType,"Beacon"))
                        % Extract a specific packet:
                        % * A beacon with an SSID which matches that requested
                        % * A beacon with no SSID requested
                        % * Any other requested type
                        csi(:,nextCSIDataPoint) = res.ChanEstNonHT;
                        packetSize(nextCSIDataPoint) = ind.NonHTData(2);
                        nextCSIDataPoint = nextCSIDataPoint + 1;
                    end
                end
            end

            % Shift packet search offset for next iteration of while loop
            if isPDObj
                break; % Exit while loop and go to next iteration of for loop
            else
                searchOffset = res.PacketOffset + double(ind.NonHTData(2));
            end
        end
    end
    % Remove zero-entires
    zeroEntries = ~any(csi,1);
    csi(:,zeroEntries) = [];
    packetSize(zeroEntries) = [];
    dispMsg(' | Waveform processing complete.\n',opts.DisplayCaptureStatus)

end

function [modulation,coderate] = getRateInfo(mcs)
% GETRATEINFO returns the modulation scheme as a character array and the
% code rate of a packet given a scalar integer representing the modulation
% coding scheme
    switch mcs
      case 0 % BPSK
        modulation = 'BPSK';
        coderate = '1/2';
      case 1 % BPSK
        modulation = 'BPSK';
        coderate = '3/4';
      case 2 % QPSK
        modulation = 'QPSK';
        coderate = '1/2';
      case 3 % QPSK
        modulation = 'QPSK';
        coderate = '3/4';
      case 4 % 16QAM
        modulation = '16QAM';
        coderate = '1/2';
      case 5 % 16QAM
        modulation = '16QAM';
        coderate = '3/4';
      case 6 % 64QAM
        modulation = '64QAM';
        coderate = '2/3';
      otherwise % 64QAM
        modulation = '64QAM';
        coderate = '3/4';
    end
end

function dispMsg(msg,d)
% DISPMSG prints the message (MSG) using fprintf if the display flag (D)
% is true
    if d
        fprintf(msg);
    end
end
