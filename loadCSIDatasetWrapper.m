function [data, labelsVec, timestamps] = loadCSIDatasetWrapper(fileName, posture, visualizeData)
% loadCSIDatasetWrapper
%   저장된 자세별(.mat) 데이터에서 올바른 변수명을 불러오고
%   레이블과 타임스탬프 벡터를 생성합니다.
%
% Inputs:
%   fileName     - 불러올 .mat 파일명 (string or char)
%   posture      - 'Supine' 또는 'Lateral' (string)
%   visualizeData - (optional) 시각화 여부 (default: false)
%
% Outputs:
%   data        - CSI 데이터 (3차원 배열)
%   labelsVec   - 자세 레이블 벡터 (categorical)
%   timestamps  - 타임스탬프 배열

    arguments
        fileName {mustBeText}
        posture (1,1) string
        visualizeData (1,1) logical = false
    end

    % .mat 파일 로드
    S = load(fileName);

    % posture 별 변수명 맞추기
    switch posture
        case "Supine"
            if isfield(S, 'dataSupine') && isfield(S, 'timestampSupine')
                data = S.dataSupine;
                timestamps = S.timestampSupine;
            else
                error('Supine 데이터 변수명이 없습니다.');
            end
        case "Lateral"
            if isfield(S, 'dataLateral') && isfield(S, 'timestampLateral')
                data = S.dataLateral;
                timestamps = S.timestampLateral;
            else
                error('Lateral 데이터 변수명이 없습니다.');
            end
        otherwise
            error("지원하지 않는 posture 값입니다.");
    end

    % 레이블 벡터 생성 (마지막 차원 크기만큼 posture 레이블 반복)
    labelsVec = categorical(repmat(posture, size(data, ndims(data)), 1));

    % 데이터 크기 출력
    disp(['Dimensions of the ' char(posture) ' dataset (numSubcarriers x numPackets x numCaptures): [' num2str(size(data)) ']']);

    % 시각화 수행
    if visualizeData
        plotSamplesFromDataset(data, posture);
    end

    % -------------------
    function plotSamplesFromDataset(data, mode)
        inputData = abs(data);
        numTotalCaptures = size(inputData, ndims(inputData));
        numPlots = min(3, numTotalCaptures);
        idxSelected = sort(randperm(numTotalCaptures, numPlots));

        figure;
        T = tiledlayout(2, numPlots, 'TileSpacing', 'compact');

        for i = 1:numPlots
            nexttile
            imagesc(inputData(:,:,idxSelected(i)));
            colorbar;
            xlabel('Packets');
            ylabel('Subcarriers');
            title(['Raw CSI (#' num2str(idxSelected(i)) ')']);
        end

        for j = 1:numPlots
            nexttile
            imagesc(csi2periodogram(inputData(:,:,idxSelected(j))));
            colorbar;
            clim([0 1]);
            xlabel('Temporal Index');
            ylabel('Spatial Index');
            title(['CSI Periodogram (#' num2str(idxSelected(j)) ')']);
            title(T, ['Randomly Selected Samples of "', char(mode), '" Data']);
            set(gcf, 'Position', [0 0 650 450]);
        end
    end

end
