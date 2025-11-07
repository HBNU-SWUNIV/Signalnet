# Wi-Fi CSI 기반 자세 분류 실험 (Supine / Lateral)

본 프로젝트는 USRP B210 SDR 장비를 활용하여 Wi-Fi CSI(Channel State Information) 데이터를 수집하고,  
수집된 데이터를 이용해 CNN 모델을 학습하여 누운 자세(정자세, Supine)와 옆으로 누운 자세(Lateral)를 분류하는 실험입니다.

---

## 전체 파이프라인 개요

| 단계 | 내용 |
|-----|-----|
| 1. SDR 설정 | USRP B210 장비 초기화 및 채널/주파수/GAIN 설정 |
| 2. 데이터 수집 | Supine / Lateral 각각 지정된 수량 만큼 CSI 캡처 및 저장 |
| 3. 데이터 로드 & 전처리 | 저장된 CSI 데이터 불러오기 및 정규화 |
| 4. Train / Validation / Test 분할 | 훈련용 / 검증용 / 테스트용 데이터 생성 |
| 5. CNN 모델 구성 및 학습 | 2D CNN 기반 분류 모델 학습 |
| 6. 실시간 자세 감지 | 학습된 모델로 실시간 자세 분류 수행 |

---

## 1. SDR 기본 설정

```matlab
useSDR = true; % true: 실시간 SDR 캡처, false: 저장된 데이터 사용
rxsim.DeviceName           = "B210";
rxsim.RadioGain            = 15;
rxsim.ChannelNumber        = 124;
rxsim.FrequencyBand        = 5;
```

- 기존 SDR 객체가 남아 있는 경우 충돌 방지를 위해 `release()` 후 재생성합니다.
- 데이터 저장 파일은 다음과 같습니다.

```
dataset-Supine.mat
dataset-Lateral.mat
```

---

## 2. 데이터 수집

### Supine / Lateral 모두 동일한 방식

- 1 Batch = 10개의 캡처
- 총 50 batch → 500개의 샘플 수집
- 캡처 실패 시 최대 5회 재시도

```matlab
capturePerBatch = 10;
numBatches = 50;
maxRetries = 5;
```

수집 중 실패한 샘플은 자동으로 건너뜁니다.  
수집된 데이터는 추가 저장 방식(append)으로 파일 끝에 계속 이어 붙여집니다.

---

## 3. 데이터 정규화 및 분할

```matlab
normalizeCSI = @(x) (abs(x) - mean(abs(x),'all')) / std(abs(x),0,'all');
```

- CSI 진폭값을 평균 0, 표준편차 1로 변환 (학습 안정화 효과)

학습/검증/테스트 분할:
```matlab
trainingRatio = 0.8;
```

---

## 4. CNN 구조

```matlab
imageInputLayer(imgInputSize,'Normalization','none')
convolution2dLayer(3,16,'Padding','same')
...
fullyConnectedLayer(numClasses)
softmaxLayer
classificationLayer
```

- 3-Block Conv 구조
- Dropout 적용 (0.2)
- Adam optimizer 사용 (`MaxEpochs = 20`)

---

## 5. 학습 및 실시간 예측

```matlab
trainedCNN = trainNetwork(trainingData, cnnLayers, options);
```

### 실시간 모드 (`useSDR = true`)
```matlab
sensingResults = livePresenceDetection(rxsim, trainedCNN, uniqueClassLabels, 20);
```

### 테스트 데이터 평가 (`useSDR = false`)
```matlab
sensingResults = testPresenceDetection(testData, trainedCNN);
```

---

## 주의 사항

| 항목 | 내용 |
|-----|-----|
| 실험 환경 유지 | 침대 위치 / 실험자 위치 변화 금지 |
| 라우터-수신기 사이 가림 주의 | 사람/가구 이동 시 CSI 변화 발생 |
| 데이터 수집 시간 일정하게 | 배치 간 시간차 줄일수록 학습 성능 ↑ |
| Supine ↔ Lateral 수집 균형 | 클래스 불균형 시 학습 성능 ↓ |

---

## 결론

이 코드는  
**CSI 기반 자세 인식 실험 → 데이터 수집 → CNN 학습 → 실시간 감지** 까지  
전체 파이프라인을 자동으로 수행할 수 있도록 구성되어 있습니다.

실험을 반복하면서 환경 변화 최소화, 데이터 수집 균형 유지, 정규화/전처리 유지가 핵심입니다.
