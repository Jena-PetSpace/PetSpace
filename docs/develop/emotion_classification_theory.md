# PetSpace 감정 분류 이론적 근거

**작성일**: 2026-04-07  
**버전**: 2.0 (5종 → 8종 개편)  
**브랜치**: feature/emotion-8class-refactor

---

## 1. 적용 이론

### Russell(1980) — 원형 감정 모델 (Circumplex Model of Affect)
Russell은 모든 감정이 두 차원으로 구성된다고 제안했다.
- **Valence (긍정/부정)**: 감정의 쾌불쾌 차원
- **Arousal (각성도)**: 감정의 고각성/저각성 차원

이 모델에 따르면 8가지 감정은 2D 공간에 다음과 같이 배치된다:
```
          높은 각성 (High Arousal)
               ↑
흥분(excitement) ·  · 공포(fear)
               |
긍정 ←  호기심(curiosity)  → 부정
               |
편안함(calm) ·  · 슬픔(sadness)
               ↓
          낮은 각성 (Low Arousal)
```

### Panksepp(1998) — 정동 신경과학 (Affective Neuroscience)
Panksepp은 포유류 뇌에 내장된 7대 기본 감정 시스템을 제안했다.

| 시스템 | PetSpace 감정 매핑 |
|--------|------------------|
| PLAY | happiness (기쁨) |
| CARE | calm (편안함) |
| SEEKING | curiosity (호기심) |
| ANXIETY | anxiety (불안) |
| FEAR | fear (공포) |
| GRIEF | sadness (슬픔) |
| RAGE (전단계) | discomfort (불편함) |
| excitement | Ekman 확장 (별도 추가) |

이 이론은 반려동물이 인간과 동일한 신경 기반의 감정 시스템을 공유한다는 점에서 PetSpace 분석의 핵심 근거다.

### Ekman(1992) — 기본 감정 이론 (Basic Emotions)
Ekman은 얼굴 근육 움직임(FACS)에 기반하여 기본 감정을 분류했다.
- 반려동물 적용 연구: DogFACS(Waller et al., 2013), CatFACS
- PetSpace에서는 눈·귀·입·자세 4개 부위 분석에 Ekman 모델 활용

---

## 2. 반려동물 감정 연구 현황

### DogFACS (Dog Facial Action Coding System, Waller et al., 2013)
- 개의 얼굴 근육 움직임을 체계적으로 분류한 코딩 시스템
- Inner Brow Raise(AU101): 불안·두려움 신호
- 2018 Scientific Reports: 개가 사람 얼굴 표정에 반응하는 신경 메커니즘 확인

### Merola et al. (2014) — 반려동물 감정 전이
- 반려동물이 주인의 감정 상태를 인식하고 반응함을 실증
- PetSpace 분석에서 '환경 맥락' 파라미터 중요성의 이론적 근거

### 졸림(sleepiness)의 생리지표 분리 근거
Russell 모델에서 sleepiness는 감정(affect)이 아닌 각성 상태(arousal state)에 해당한다.
→ **감정 점수에서 분리하여 `is_sleepy` boolean 생리지표로 처리**하는 것이 이론적으로 올바른 분류.

---

## 3. 최종 8가지 감정 분류표

| 감정 | key | Valence | Arousal | 이론 근거 | 반려동물 표정 신호 |
|------|-----|---------|---------|---------|----------------|
| 기쁨 | happiness | 긍정 | 중간 | Ekman + Panksepp(PLAY) | 입 열림, 눈 빛남, 편안한 귀 |
| 편안함 | calm | 긍정 | 낮음 | Russell(315°) + Panksepp(CARE) | 눈 반쯤 감음, 이완된 귀·입 |
| 흥분 | excitement | 긍정 | 높음 | Russell(45°) + Ekman 확장 | 귀 세움, 눈 크게, 입 열림 |
| 호기심 | curiosity | 중립 | 중간 | Panksepp(SEEKING) | 귀 앞으로, 고개 기울임 |
| 불안 | anxiety | 부정 | 중간 | Panksepp(ANXIETY) | 귀 뒤로, 눈 흰자, 긴장 |
| 공포 | fear | 부정 | 높음 | Panksepp(FEAR) + Ekman | 귀 완전 뒤, 동공 확대, 몸 낮춤 |
| 슬픔 | sadness | 부정 | 낮음 | Panksepp(GRIEF) + Ekman | 귀 처짐, 눈 처짐, 고개 숙임 |
| 불편함 | discomfort | 부정 | 중간 | Panksepp(RAGE 전단계) | 눈살 찌푸림, 입 긴장 |

### 감정 그룹 분류 (UI 구성 기준)
```
긍정 그룹: happiness, calm, excitement
중립 그룹: curiosity
부정 그룹: anxiety, fear, sadness, discomfort
```

### 생리지표 (감정 점수에서 분리)
| 지표 | 타입 | 설명 |
|------|------|------|
| is_sleepy | boolean | 졸림 상태 (Russell 모델: 각성도 저하) |
| stress_level | int (0~100) | 스트레스 수준 |
| activity_level | int (0~100) | 활동성 수준 |
| comfort_level | int (0~100) | 편안함 수준 |

---

## 4. 기존 5종 대비 개편 이유

| 기존 5종 | 문제점 | 개편 방향 |
|---------|--------|----------|
| happiness | 유지 | 유지 |
| sadness | 유지 | 유지 |
| anxiety | 유지 | 유지 |
| sleepiness | 감정이 아닌 생리지표 | `is_sleepy` boolean으로 분리 |
| curiosity | 유지 | 유지 |
| (없음) | calm 부재 → 긍정 저각성 표현 불가 | calm 추가 |
| (없음) | excitement 부재 → 긍정 고각성 표현 불가 | excitement 추가 |
| (없음) | fear 부재 → anxiety와 구분 불가 | fear 추가 |
| (없음) | discomfort 부재 → 신체 불편 표현 불가 | discomfort 추가 |

**핵심 개선**: 5종 체계에서 `anxiety`가 불안·공포·불편함을 모두 커버하는 과부하 상태였음.
8종으로 분리하면 행동 권장 정확도가 크게 향상됨.

---

## 5. AI 프롬프트 설계 원칙

1. **이론 명시**: 프롬프트에 Russell/Panksepp/Ekman 이론을 직접 명시하여 Gemini가 이론 기반으로 분류하도록 유도
2. **부위별 신호 제공**: 각 감정의 눈·귀·입·자세 신호를 프롬프트에 포함하여 정확도 향상
3. **합계 강제**: 8감정 합계 = 1.0 강제 (sleepiness 제외)
4. **생리지표 분리**: is_sleepy는 감정 점수와 별도 JSON 필드로 요청
5. **동물 없음 처리**: 동물이 없는 경우 각 감정 0.125씩 균등 분포 반환

---

## 참고 문헌

- Russell, J. A. (1980). A circumplex model of affect. *Journal of Personality and Social Psychology*, 39(6), 1161–1178.
- Panksepp, J. (1998). *Affective Neuroscience: The Foundations of Human and Animal Emotions*. Oxford University Press.
- Ekman, P. (1992). An argument for basic emotions. *Cognition & Emotion*, 6(3-4), 169–200.
- Waller, B. M., et al. (2013). Paedomorphic Facial Expressions Give Dogs a Selective Advantage. *PLOS ONE*.
- Merola, I., et al. (2014). Social referencing and cat–human communication. *Animal Cognition*, 18(3).
