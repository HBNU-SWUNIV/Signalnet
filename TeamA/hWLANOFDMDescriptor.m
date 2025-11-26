classdef hWLANOFDMDescriptor < wt.internal.WirelessSignalDescriptor
%hWLANOFDMDescriptor - Describe a WLAN OFDM signal
%   ds = hWLANOFDMDescriptor creates a WLAN OFDM descriptor object used to
%   configure a preambleDetector object or energyDetector object for WLAN
%   OFDM signal detection and capture. The object contains properties that
%   describes a WLAN signal at the default channel bandwidth and center
%   frequency.
%
%   ds = hWLANOFDMDescriptor(Band=X) creates an array of WLAN OFDM
%   descriptor objects where the total number of objects created depends on
%   the operating band X and the channel bandwidth. If an operating band is
%   specified, the center frequency input is ignored.
%
%   ds = hWLANOFDMDescriptor(Name=Value) creates an object with the
%   specified property Name set to the specified Value. You can specify
%   additional name-value pair arguments in any order as
%   (Name1=Value1,...,NameN=ValueN).
%
%   ds = hWLANOFDMDescriptor(Name=[Value1,...ValueN]) creates an array of
%   objects where the total number of objects created is N. You can specify
%   additional name-value pair arguments in any order as
%   (Name1=[Value1,...,ValueN], Name2=[Value1,...,ValueN]). If only a
%   single Value is specified for a property Name, then scalar expansion is
%   applied to that Value. This syntax applies only to the CenterFrequency
%   Band, and Channel properties.
%
%   hWLANOFDMDescriptor methods:
%
%   configureDetector - Configure a preambleDetector or energyDetector
%   object for WLAN OFDM signal capture
%
%   hWLANOFDMDescriptor properties:
%
%   Band             - Operating band in GHz
%   Channel          - Channel number for band of interest 
%   CenterFrequency  - Center frequency in Hz
%   ChannelBandwidth - Bandwidth of channel
%
%   Example 1:
%       % Create an array of descriptors to search for 20 MHz signals in
%       % the 5 GHz band
%       ds = hWLANOFDMDescriptor(Band=5,ChannelBandwidth="CBW20")
%
%   Example 2:
%       % Create an array of descriptors to search for 80 MHz signals in
%       % all the channels of the 5 GHz band
%       ds = hWLANOFDMDescriptor(Band=5,Channel=1:200, ...
%                                ChannelBandwidth="CBW80")
%
%   Example 3:
%       % Create a single descriptor to search for a 20 MHz signal at
%       % 2437 MHz
%       ds = hWLANOFDMDescriptor(CenterFrequency=2437e6, ...
%                                ChannelBandwidth="CBW20")

%   Copyright 2023 The MathWorks, Inc.

    properties (Dependent)
        %BAND - Operating band in GHz
        %   Specify BAND as one of 2.4, 5, or 6. The default is 5. If you
        %   change the value of CenterFrequency, BAND may also change.
        Band(1,1) {mustBeMember(Band,[2.4 5 6])};

        %CHANNEL - Channel number for band of interest
        %   Specify CHANNEL as 1-14 for band 2.4, 1-200 for band 5, or
        %   1-233 for band 6. The default is 1. If you change the value of
        %   CenterFrequency, CHANNEL will also change.
        Channel(1,1) {mustBeInteger,mustBePositive};

        %CenterFrequency - Center frequency in Hz
        %   Specify CenterFrequency as a positive numeric scalar. The
        %   default is 5005e6. If BAND or CHANNEL changes, CenterFrequency
        %   will also change. If you set CenterFrequency to a value that is
        %   not within a valid BAND and CHANNEL combination set out in
        %   Annex E of IEEE Std 802.11-2020, IEEE Std 802.11ax-2021 and
        %   IEEE P802.11be/D3.0, these properties are set to "Unknown".
        CenterFrequency(1,1) {mustBePositive};
    end

    properties
        %ChannelBandwidth - Bandwidth of channel
        %   Specify ChannelBandwidth as one of "CBW5" | "CBW10" | "CBW20" |
        %   "CBW40" | "CBW80" | "CBW160" | "CBW320". The default is
        %   "CBW20".
        ChannelBandwidth(1,1) {mustBeMember(ChannelBandwidth,["CBW5" "CBW10" "CBW20" "CBW40" "CBW80" "CBW160" "CBW320"])} = "CBW20";
    end

    properties (Access=private)
        pBand;
        pChannel;
        pCenterFrequency;
    end

    properties(Hidden,Constant)
        MaxChannelValues = dictionary([2.4 5 6],[14 200 233]);
    end

    properties(Hidden,Dependent)
        hSubcarrierSpacing;
        hChannelBandwidthNumeric;
    end

    methods
        function obj = hWLANOFDMDescriptor(opts)
            arguments
                opts.Band {mustBeMember(opts.Band,[2.4 5 6])} = [];
                opts.Channel {mustBePositive} = [];
                opts.ChannelBandwidth {mustBeMember(opts.ChannelBandwidth, ...
                    ["CBW5" "CBW10" "CBW20" "CBW40" "CBW80" "CBW160" "CBW320"])} = "CBW20";
                opts.CenterFrequency {mustBeVector,mustBePositive} = 5.005e9;
            end

            % Convert to string in case of char array or cell array of
            % chars
            opts.ChannelBandwidth = string(opts.ChannelBandwidth);

            % Use user supplied center frequencies only if user didn't
            % supply Band and Channel inputs
            if isempty(opts.Band) && isempty(opts.Channel)
                frequencies = opts.CenterFrequency;
                numDescriptors = length(frequencies);
                bandChannel = @(x)getBandChannelValues(frequencies(x));
            else
                % Specify default channels for channel bandwidth if
                % opts.Channel is not supplied
                if isempty(opts.Channel)
                    if ~isscalar(opts.Band)
                        error("hWLANOFDMDescriptor:nonScalarBand","Band " + ...
                            "must be a scalar value if CHANNEL is not supplied.")
                    end
                    channels = getChannelsFromBandwidth(opts.Band,opts.ChannelBandwidth);
                else
                    if isempty(opts.Band)
                        % Default value if Band is not specified
                        opts.Band = 5;
                    end
                    channels = opts.Channel;
                end
                numDescriptors = length(channels);
                band = scalarExpandInput(opts.Band,numDescriptors,"BAND");
                frequencies = @(x)getWLANFrequency(band(x),channels(x));
                bandChannel = @(x)deal(band(x),channels(x));
            end

            cbw = scalarExpandInput(opts.ChannelBandwidth,numDescriptors,"CHANNELBANDWIDTH");

            % Create a descriptor for each frequency value and populate
            % necessary properties.
            obj = repmat(obj,1,numDescriptors);
            for i = 1:numDescriptors
                obj(i).pCenterFrequency = frequencies(i);
                [obj(i).pBand,obj(i).pChannel] = bandChannel(i);
                obj(i).ChannelBandwidth = cbw(i);
            end
        end

        % Property Set/Get methods (Maybe better way to have properties
        % Depend on each other?) CenterFrequency
        function obj = set.CenterFrequency(obj,val)
            obj.pCenterFrequency = val;
            % Update Band and Channel property values when CenterFrequency
            % is changed
            [obj.pBand,obj.pChannel] = getBandChannelValues(val);
        end

        function val = get.CenterFrequency(obj)
            val = obj.pCenterFrequency;
        end

        % Band
        function obj = set.Band(obj,val)
            obj.pBand = val;
            % Update channel value to 1 if it is currently unknown or if it
            % is outside the range of channel values for the new band value
            if isstring(obj.pChannel) || obj.pChannel>obj.MaxChannelValues(val)
                obj.pChannel = 1;
            end
            obj.pCenterFrequency = getWLANFrequency(obj.pBand,obj.pChannel);
        end

        function val = get.Band(obj)
            val = obj.pBand;
        end

        % Channel
        function obj = set.Channel(obj,val)
            obj.pChannel = val;
            if isstring(obj.pBand)
                obj.pBand = 5;
            end
            obj.pCenterFrequency = getWLANFrequency(obj.pBand,obj.pChannel);
        end

        function val = get.Channel(obj)
            val = obj.pChannel;
        end

        % hSubcarrierSpacing
        function val = get.hSubcarrierSpacing(obj)
            switch obj.hChannelBandwidthNumeric
                case 5
                    val = 78.125;
                case 10
                    val = 156.25;
                case {20, 40, 80, 160, 320}
                    val = 312.5;
                otherwise
                    error("hWLANOFDMDescriptor:unknownChannelBandwidthValue", ...
                        "obj.ChannelBandwidth was set to an unknown value (%s). This " + ...
                        "should not happen.", obj.ChannelBandwidth);
            end
        end

        % hChannelBandwidthNumeric
        function val = get.hChannelBandwidthNumeric(obj)
            val = double(extractAfter(obj.ChannelBandwidth,"CBW"));
        end
    end

    methods(Access=?wt.internal.WirelessSignalDescriptor)
        function configurePreambleDetector(obj,pd,sampleRate,~)
            %configurePreambleDetector - Configre a preambleDetector object
            %for WLAN signal detection and capture
            %
            %   configurePreambleDetector(obj,pd,sampleRate) calculates one
            %   training symbol of the legacy long training field (L-LTF)
            %   for the Preamble property of the preamble detector object.
            %   This function also sets the CenterFrequency, Preamble, and
            %   TriggerOffset properties of the preamble detector object.
            %   The L-LTF preamble calculation is based off of the
            %   ChannelBandwidth property and sampleRate input.
            %   
            cbw = obj.wirelessSignalBandwidth;

            if sampleRate < cbw
                error("hWLANOFDMDescriptor:smallSampleRate","Specified sample rate " + ...
                    "(%.2f MHz) is too small for specified channel bandwidth (%s)", ...
                    sampleRate/1e6,obj.ChannelBandwidth);
            end

            % Construct preamble for 1 subchannel. The sequence is based on
            % a 20 MHz L-LTF: equation 19-11 in IEEE Std 802.11-2020.
            lltfLower = [1; 1;-1;-1; ...
                1; 1;-1; 1; ...
                -1; 1; 1; 1; ...
                1; 1; 1;-1; ...
                -1; 1; 1;-1; ...
                1;-1; 1; 1; ...
                1; 1;];
            lltfUpper = [1; ...
                -1;-1; 1; 1; ...
                -1; 1;-1; 1; ...
                -1;-1;-1;-1; ...
                -1; 1; 1;-1; ...
                -1; 1;-1; 1; ...
                -1; 1; 1; 1; 1];

            LLTF = [zeros(6,1); lltfLower; 0; lltfUpper; zeros(5,1)];

            % Determine number of subchannels and repeat preamble on each
            % subchannel
            scs = obj.hSubcarrierSpacing*1e3;
            nfft = cbw/scs;
            nsc = nfft/64;
            lltf = repmat(LLTF,nsc,1);

            % Gamma rotation defined in 802.11-2016 Section 21.3.7.5
            switch obj.hChannelBandwidthNumeric
                case {5, 10, 20}
                    gamma = 1;
                case 40
                    gamma = [1 1i];
                case 80
                    gamma = [1 -1 -1 -1];
                case 160
                    gamma = [1 -1 -1 -1 1 -1 -1 -1];
                case 320
                    gamma = [1 -1 -1 -1 1 -1 -1 -1 -1 1 1 1 -1 1 1 1];
                otherwise
                    error("hWLANOFDMDescriptor:unknownChannelBandwidthValue", ...
                        "obj.ChannelBandwidth was set to an unknown value (%s). This " + ...
                        "should not happen.", obj.ChannelBandwidth);
            end

            % Apply gamma rotation
            gamma = reshape(repmat(gamma,64,1),[],1);
            lltf = lltf.*gamma;

            % Switch to time domain
            preamble = ifft(fftshift(lltf));

            % Upsample preamble if necessary
            if sampleRate > cbw
                preamble = resample(preamble,sampleRate,cbw);
            end

            % Normalize
            preamble = preamble/sqrt(preamble'*preamble);

            % Set preamble detector properties
            pd.CenterFrequency = obj.CenterFrequency;
            pd.Preamble = preamble;

            % Calculate trigger offset
            preambleLength = obj.getPreambleLength(sampleRate);
            lltfSymbolLength = (1/scs)*sampleRate;
            numLSIGSamples = (1.25/scs)*sampleRate;
            % Packet triggered on first L-LTF symbol so remove L-SIG and
            % 1 L-LTF symbol from trigger offset.
            triggerOffset = ceil(preambleLength - lltfSymbolLength - numLSIGSamples);
            if triggerOffset <= 3096 % Max offset achievable with Preamble Detector
                % Set to negative value as required by WT preamble detector
                pd.TriggerOffset = -triggerOffset;
            else
                warning("hWLANOFDMDescriptor:maxTriggerOffset","Unable to set a trigger offset of " + string(-triggerOffset) + ...
                    " on Preamble Detector. The maximum trigger offset of -3096 has been " + ...
                    "set. Consider reducing the sample rate.");
                pd.TriggerOffset = -3096;
            end
        end

        function configureEnergyDetector(obj,ed,sampleRate,~)
            %configreEnergyDetector - Configure an energyDetector object
            %for signal detection and capture
            %
            %   configureEnergyDetector(obj,ed,sampleRate) calculates a
            %   window length 1.25 times the length of the WLAN legacy
            %   preamble and then sets the WindowLength property of the
            %   energyDetector object. The function also configures the
            %   CenterFrequency and TriggerOffset properties of the
            %   energyDetector object.


            % Get WLAN legacy preamble length
            preambleLengthSamples = obj.getPreambleLength(sampleRate);
            
            % Add 25% to length for stability
            windowLength = floor(preambleLengthSamples * 1.25);
            if windowLength > 4096
                windowLength = 4096;
            end

            % configure energyDetector object properties
            ed.WindowLength = windowLength;
            ed.CenterFrequency = obj.CenterFrequency;
            ed.TriggerOffset = 0;
        end

        % Returns number of samples of legacy WLAN preamble
        function pLen = getPreambleLength(obj,sampleRate)
            scs = obj.hSubcarrierSpacing*1e3;
            numLSTFSamples = (2.5/scs)*sampleRate;
            numLLTFSamples = numLSTFSamples;
            numLSIGSamples = (1.25/scs)*sampleRate;
            pLen = ceil(numLSTFSamples + numLLTFSamples + numLSIGSamples);
        end
    end

    methods(Access=protected)
        function bandwidth = wirelessSignalBandwidth(obj)
            bandwidth = obj.hChannelBandwidthNumeric*1e6;
        end
    end
end

function fc = getWLANFrequency(band,channel)

    switch band
        case 2.4
            maxChannelValue = 14;
            % IEEE Std 802.11-2020, December 2020, Section 19.3.15.2,
            % Equation 19-87
            getFreq = @(c) 2407e6 + 5e6.*c;
        case 5
            maxChannelValue = 200;
            % IEEE Std 802.11-2020, December 2020, Section 17.3.8.4.2,
            % Equation 17-27
            getFreq = @(c) 5e9 + 5e6.*c;
        case 6
            maxChannelValue = 233;
            % IEEE Std 802.11-2020, December 2020, Section 27.3.23.2,
            % Equation 27-135
            getFreq = @(c) 5950e6 + 5e6.*c;
        otherwise
            error("hWLANOFDMDescriptor:invalidBand","The specified band " + ...
                "value (%.1f) is not valid. Band value should be one of these values: " + ...
                "2.4, 5, or 6.",band);
    end

    if all(channel<=maxChannelValue)
        fc = getFreq(channel);
        if band == 2.4
            % Channel 14 is valid only for DSSS and CCK modes in Japan
            fc(channel == 14) = 2484e6;
        end
    else
        error("hWLANOFDMDescriptor:invalidChannel","The specified " + ...
            "channel value (%d) is not valid for the specified band (%.1f). " + ...
            "For the %.1f GHz band, the channel value must be between 1 and %d.", ...
            channel,band,band,maxChannelValue);
    end
end

function [band,channel] = getBandChannelValues(fc)

    if fc == 2484e6
        band = 2.4;
        channel = 14;
        return
    end

    c = (fc - [2407e6 5e9 5950e6])./5e6;

    idx = find(rem(c,1)==0&c>0&c<=[13 200 233],1);
    if ~isempty(idx)
        band = [2.4 5 6];
        band = band(idx);
        channel = c(idx);
    else
        band = "Unknown";
        channel = "Unknown";
    end
end

function out = scalarExpandInput(in,expansionValue,varname)
    if isscalar(in)
        out = repmat(in,expansionValue,1);
    else
        out = in;
        if length(in) ~= expansionValue
            error("hWLANOFDMDescriptor:inputSizeMismatch","The number of " + ...
                "%s values (%d) does not match the number of channels (%d).", ...
                varname,length(in),expansionValue);
        end
    end
end

function channels = getChannelsFromBandwidth(band,cbw)

    switch band
        case 2.4
            if matches(cbw,"CBW40")
                channels = 3:11;
            else
                channels = 1:14;
            end
        case 5
            switch cbw

                case "CBW10"
                    channels = [7 9 11 180 180:2:184 187 189];
                case "CBW20"
                    channels = [8 12 16 32 36:4:64 68 96 100:4:144 149:4:177 183 188:4:196];
                case "CBW40"
                    channels = [102:8:142 151:8:175];
                case "CBW80"
                    channels = [42 58 106 122 138 155 171];
                case "CBW160"
                    channels = [50 114 163];
                otherwise
                    channels = 1:200;
            end
        otherwise %case 6

            switch cbw
                case {"CBW20" "CBW40" "CBW80" "CBW160" "CBW320"}
                    channels = 1:4:233;
                    l = length(channels);
                    nsc = str2double(extractAfter(cbw,"CBW"))/20;
                    channels = sum(reshape(channels(1:l-rem(l,nsc)),nsc,[]),1)/nsc;
                    if matches(cbw,"CBW20")
                        channels = [2 channels];
                        channels = sort(channels);
                    end
                otherwise % CBW5, CBW10
                    channels = 1:233;
            end
    end
end
