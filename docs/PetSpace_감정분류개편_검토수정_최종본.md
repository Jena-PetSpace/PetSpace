# PetSpace 감정 분류 개편 작업지시서 — 검토 수정 최종본
**이론 근거**: Russell의 원형 모델(1980) × Panksepp의 정동 신경과학(1998) × Ekman의 기본 감정 이론(1992)
**변경 요약**: 5가지(기쁨/슬픔/불안/졸림/호기심) → 8가지(기쁨/편안함/흥분/호기심/불안/공포/슬픔/불편함) + 졸림 생리지표 분리
**최종 수정**: 2026-04-07 | 풀스택 개발자 + UI/UX 디자이너 협의 검토본

---

## 검토 결과 — 이전 작업지시서에서 발견된 문제점

### 🔴 풀스택 개발자 관점 — 치명적 오류 5가지

**오류 1 — 누락 파일 11개**
이전 작업지시서는 sleepiness를 참조하는 파일을 일부만 다뤘다.
실제로는 아래 11개가 추가로 수정되어야 한다:
```
pjh/lib/core/constants/app_constants.dart              ← emotionTypes 상수 리스트
pjh/lib/features/emotion/data/repositories/emotion_repository_impl.dart  ← 통계 계산
pjh/lib/features/emotion/presentation/pages/emotion_calendar_page.dart   ← 이모지/이름 맵
pjh/lib/features/emotion/presentation/pages/emotion_history_page.dart    ← 필터 칩
pjh/lib/features/emotion/presentation/pages/emotion_trend_page.dart      ← 감정 분포 계산
pjh/lib/features/emotion/presentation/pages/weekly_report_page.dart      ← 하드코딩 컬러
pjh/lib/features/my/presentation/pages/my_emotion_history_page.dart      ← switch-case
pjh/lib/features/my/presentation/pages/my_posts_page.dart               ← switch-case
pjh/lib/features/pets/presentation/pages/public_pet_page.dart           ← 이모지 맵
pjh/lib/features/home/presentation/widgets/home_dashboard_header.dart   ← 이모지/설명 맵
pjh/lib/features/home/presentation/widgets/statistics_summary_card.dart ← 감정 리스트
```

**오류 2 — part of 구조 오인식**
emotion_result_cards_a/b/c와 emotion_result_helpers는 독립 위젯이 아니다.
모두 `part of emotion_result_page.dart`로 선언된 extension 파일이다.
→ emotion_result_page.dart 수정 시 함께 처리해야 하며, 독립 위젯처럼 import 수정 불필요.

**오류 3 — sleepinessColor 단순 이름 변경 불가**
`AppTheme.sleepinessColor`를 직접 사용하는 파일이 다수 존재한다.
단순 이름 변경 시 컴파일 에러 다수 발생.
→ 기존 이름 유지 + deprecated getter 추가 방식으로 처리해야 한다.

**오류 4 — weekly_report_page 하드코딩 컬러**
weekly_report_page.dart는 AppTheme을 쓰지 않고 Color(0xFF...) 직접 사용.
AppTheme만 업데이트하면 이 파일은 자동 반영이 안 된다. 별도 수정 필수.

**오류 5 — 중복 helper 메서드 미통합**
_getEmotionName, _getEmotionIcon, _getEmotionColor, _getEmotionValue가
emotion_result_page, emotion_history_page, emotion_calendar_page, weekly_report_page,
my_posts_page, my_emotion_history_page 등 6개 파일에 각각 중복 구현되어 있다.
C단계에서 AppTheme에 getEmotionLabel/Emoji/Color를 추가하면,
이후 각 파일의 중복 메서드를 AppTheme 호출로 교체해야 한다.

---

### 🟡 UI/UX 디자이너 관점 — 추가/수정/삭제 사항

**추가 1 — 레이더 차트 5→8축 시 가독성 문제**
5각형 → 8각형으로 변경 시 각 꼭짓점 간격이 좁아져 모바일에서 라벨 겹침 발생.
→ 레이더 차트는 정서 그룹(긍정/중립/부정) 3개 값으로 요약한 3각 차트로 교체.
또는 레이더 차트 size를 300dp로 확대 + 라벨 9sp로 축소.

**추가 2 — 8개 바 차트 모바일 가독성**
300dp 너비 화면에 8개 바를 나열하면 각 바 너비가 약 30dp로 너무 좁아짐.
→ 그룹별 컬러 배경 구분(긍정/중립/부정)으로 시각적 묶음 처리.
또는 가로 스크롤 바 차트로 전환(수평 배치).

**추가 3 — 감정 필터 칩 8개 레이아웃**
emotion_history_page의 필터 다이얼로그에 8개 칩이 Wrap으로 나열되면
2~3줄 차지 → 다이얼로그 너무 길어짐.
→ 긍정/중립/부정 3개 섹션으로 구분한 그룹형 필터로 개선.

**추가 4 — 홈 화면 감정 표시 간결화**
8가지 감정 중 dominant 1개 + secondary 1개만 홈에 표시.
상세는 AI분석 탭에서 확인 유도 → 홈 화면 정보 과부하 방지.

**추가 5 — 생리지표 졸림 배너 위치**
isSleepy 배너를 결과 카드에 삽입하면 감정 결과와 시각적 혼동 발생.
→ 결과 페이지 상단 알림 배너(슬라이드 인 애니메이션)로 분리 표시.

**삭제 1 — 레이더 차트 8축 방안 제거**
8축 레이더 차트는 모바일 UX상 부적합. 추가 2의 그룹 바 차트 또는 요약 도넛 차트 사용.

**수정 1 — 감정 컬러 팔레트 일관성**
신규 추가 4개 컬러(그린/앰버/퍼플/딥오렌지)가 JENA 브랜드 팔레트와 이질감.
→ JENA 팔레트 기반으로 재설계:
  calm:       Color(0xFF4CAF50)  → Color(0xFF2E7D6B)  (JENA 계열 틸 그린)
  excitement: Color(0xFFFFC107)  → Color(0xFFE8A838)  (따뜻한 앰버, 브랜드 친화)
  fear:       Color(0xFF9C27B0)  → Color(0xFF6B3FA0)  (딥 퍼플, 강렬하지 않게)
  discomfort: Color(0xFFFF5722)  → Color(0xFFD4511E)  (JENA 코랄보다 진한 오렌지)

**수정 2 — 공유 카드 감정 표시 간략화**
8가지 감정을 모두 바 차트로 표시하면 공유 카드가 복잡해짐.
→ dominant 1개(크게) + 나머지 7개를 작은 dot 형태로 표시.

---

## ⚠️ Claude Code 작업 지시 주의사항

### 기본 원칙

**파일 단위 분리**
한 번에 파일 1~2개씩만 요청한다. 여러 파일 동시 수정 지시 금지.
이 작업지시서의 A~Z 순서 = 의존성 순서. 반드시 준수.

**매 단계 후 필수 확인**
```bash
flutter analyze
# → 반드시 0 issues 확인 후 다음 단계 진행
```

**커밋 타이밍**
flutter analyze 0 issues 확인 후에만 커밋.
각 단계 완료마다 커밋. 여러 단계 묶어서 커밋 금지.

**지시 형식**
```
[단계명] 작업을 진행해줘.
대상 파일: [파일 경로]
[구현 명세 붙여넣기]
완료 후 flutter analyze 실행해서 0 issues 확인해줘.
확인되면 커밋해줘: [커밋 메시지]
```

### 주요 금지 사항
- "전체 감정을 한 번에 바꿔줘" 같은 광범위한 지시 금지
- `AppTheme.sleepinessColor` 완전 삭제 금지 (deprecated 처리만)
- `emotion_result_cards_a/b/c`를 독립 위젯으로 인식하여 별도 import 추가 금지
  (이 파일들은 `part of emotion_result_page.dart`임)
- J단계(SQL)를 Claude Code로 실행 시도 금지 (Supabase Dashboard에서 직접 실행)

### 의존성 순서 (절대 변경 금지)
```
C (AppTheme) → D (엔티티) → E (모델) → F (Gemini 프롬프트)
→ G (app_constants) → H (emotion_repository_impl)
→ I (trend_service) → J (insights_service) → K (diary_service)
→ L (Supabase SQL, 직접 실행)
→ M~T (UI 위젯/페이지들, 병행 가능)
→ U (테스트) → V (빌드 검증) → W (병합)
→ X (Gemini 실제 검증) → Y (UI 이론 표기) → Z (문서화)
```

### 자주 발생하는 실수와 해결법

**실수 1 — required 파라미터 오류**
새 필드는 반드시 optional + 기본값으로 추가:
```dart
// 잘못된 방법
const EmotionScores({required this.calm, ...});
// 올바른 방법
const EmotionScores({this.calm = 0.0, ...});
```

**실수 2 — sleepiness 삭제로 크래시**
기존 DB JSONB에 sleepiness 키 존재. 절대 삭제 금지. @Deprecated + 기본값 0.0 유지.

**실수 3 — 합계 1.0 초과**
8감정 정규화 시 sleepiness 제외:
```dart
final total = happiness + calm + excitement + curiosity +
              anxiety + fear + sadness + discomfort;
if (total > 0) { 각각 /= total; }
```

**실수 4 — part of 파일 독립 처리**
emotion_result_helpers, emotion_result_cards_a/b/c 는 extension 파일.
별도 import나 독립 인스턴스 생성 불가. emotion_result_page.dart와 함께 수정.

**실수 5 — weekly_report_page 하드코딩 컬러 미수정**
AppTheme 업데이트만으로 자동 반영 안 됨. V단계에서 별도 수정 필수.

**빌드 에러 발생 시**
```bash
git checkout -- .         # 전체 되돌리기
git reset --hard HEAD~1   # 이전 커밋으로
git checkout -- pjh/lib/파일경로.dart  # 특정 파일만
```

---

## 이론적 배경 요약

### 최종 8가지 감정 분류표

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

**생리지표 (감정 점수에서 분리)**
- `is_sleepy`: boolean (졸림)
- `stress_level`, `activity_level`, `comfort_level`: 0~100 정수 (기존 유지)

### 감정 그룹 분류 (UI 구성 기준)
```
긍정 그룹: happiness, calm, excitement
중립 그룹: curiosity
부정 그룹: anxiety, fear, sadness, discomfort
```

---

## 전체 수정 대상 파일 목록 (완전판)

```
[공유 레이어] 1개
  pjh/lib/shared/themes/app_theme.dart

[상수] 1개
  pjh/lib/core/constants/app_constants.dart             ← 이전 작업지시서 누락

[도메인 레이어] 1개
  pjh/lib/features/emotion/domain/entities/emotion_analysis.dart

[데이터 레이어] 6개
  pjh/lib/features/emotion/data/models/emotion_analysis_model.dart
  pjh/lib/features/emotion/data/services/gemini_ai_service.dart
  pjh/lib/features/emotion/data/services/emotion_trend_service.dart
  pjh/lib/features/emotion/data/services/emotion_insights_service.dart
  pjh/lib/features/emotion/data/services/emotion_diary_service.dart
  pjh/lib/features/emotion/data/repositories/emotion_repository_impl.dart  ← 누락

[감정 분석 페이지] 5개
  pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart
    part: emotion_result_helpers.dart                   ← part of, 독립 아님
    part: emotion_result_cards_a.dart                   ← part of, 독립 아님
    part: emotion_result_cards_b.dart                   ← part of, 독립 아님
    part: emotion_result_cards_c.dart                   ← part of, 독립 아님
  pjh/lib/features/emotion/presentation/pages/emotion_calendar_page.dart   ← 누락
  pjh/lib/features/emotion/presentation/pages/emotion_history_page.dart    ← 누락
  pjh/lib/features/emotion/presentation/pages/emotion_trend_page.dart      ← 누락
  pjh/lib/features/emotion/presentation/pages/weekly_report_page.dart      ← 누락 (하드코딩 컬러)

[감정 분석 위젯] 7개
  pjh/lib/features/emotion/presentation/widgets/emotion_chart.dart         ← 파이 차트
  pjh/lib/features/emotion/presentation/widgets/emotion_chart_widget.dart  ← 바 차트
  pjh/lib/features/emotion/presentation/widgets/emotion_radar_chart.dart
  pjh/lib/features/emotion/presentation/widgets/emotion_interpretation_card.dart
  pjh/lib/features/emotion/presentation/widgets/emotion_recommendations_card.dart
  pjh/lib/features/emotion/presentation/widgets/emotion_loading_widget.dart
  pjh/lib/features/emotion/presentation/widgets/result/emotion_share_card.dart

[홈 feature] 3개
  pjh/lib/features/home/presentation/widgets/recent_emotion_card.dart
  pjh/lib/features/home/presentation/widgets/pet_profile_card.dart
  pjh/lib/features/home/presentation/widgets/home_dashboard_header.dart    ← 누락
  pjh/lib/features/home/presentation/widgets/statistics_summary_card.dart  ← 누락

[MY feature] 2개
  pjh/lib/features/my/presentation/pages/my_emotion_history_page.dart      ← 누락
  pjh/lib/features/my/presentation/pages/my_posts_page.dart               ← 누락

[소셜 feature] 2개
  pjh/lib/features/social/presentation/widgets/post_card.dart
  pjh/lib/features/social/presentation/pages/create_post_page.dart

[펫 feature] 1개
  pjh/lib/features/pets/presentation/pages/public_pet_page.dart            ← 누락

[테스트] 1개
  pjh/test/features/emotion/emotion_analysis_bloc_test.dart

[DB] Supabase Dashboard 직접 실행
  emotion_stats 뷰 교체
```

---

## A. 사전 준비 — 브랜치 생성 및 현황 확인

**소요 시간**: 10분

```bash
cd ~/Desktop/PetSpace/pjh
git checkout win-android-release
git pull origin win-android-release
git checkout -b feature/emotion-8class-refactor
flutter analyze   # 0 issues 확인

# 수정 전 기준선 기록
grep -rln "sleepiness" lib/ --include="*.dart" | wc -l
# → 34개 파일 (이 숫자가 0이 되어야 작업 완료)
```

**완료 기준**: 브랜치 생성 확인, flutter analyze 0 issues

---

## B. 이론 문서 작성

**소요 시간**: 20분
**대상 파일**: `docs/develop/emotion_classification_theory.md` (신규)

```
문서 구조:
  # PetSpace 감정 분류 이론적 근거
  ## 1. 적용 이론 (Russell / Panksepp / Ekman)
  ## 2. 반려동물 감정 연구 현황 (DogFACS, 2018 Nature 논문)
  ## 3. 최종 8가지 감정 분류 및 근거
  ## 4. 기존 5가지 대비 개편 이유
  ## 5. AI 프롬프트 설계 원칙

커밋 메시지: docs: 감정 분류 이론적 근거 문서 추가 (B)
```

---

## C. AppTheme — 컬러 확장 + 헬퍼 메서드 중앙화

**소요 시간**: 30분
**대상 파일**: `pjh/lib/shared/themes/app_theme.dart`

```dart
// ── [1] 기존 컬러 유지 (이름 변경 없음) ─────────────────────
// happinessColor, sadnessColor, anxietyColor, curiosityColor → 그대로

// sleepinessColor → 삭제하지 않고 유지 (하위 호환)
// 아래처럼 기존 상수를 그대로 두고 deprecated 주석만 추가
/// @deprecated Use physiologicalColor. 생리지표용으로 의미 분리.
static const Color sleepinessColor = Color(0xFF1E3A5F);

// ── [2] 신규 컬러 추가 (JENA 브랜드 팔레트 기반) ─────────────
static const Color physiologicalColor = Color(0xFF1E3A5F); // 생리지표 (sleepinessColor 동일값)
static const Color calmColor       = Color(0xFF2E7D6B);    // 틸 그린 (편안함)
static const Color excitementColor = Color(0xFFE8A838);    // 따뜻한 앰버 (흥분)
static const Color fearColor       = Color(0xFF6B3FA0);    // 딥 퍼플 (공포)
static const Color discomfortColor = Color(0xFFD4511E);    // 딥 오렌지 (불편함)

// ── [3] getEmotionColor 확장 ────────────────────────────────
static Color getEmotionColor(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'happiness':   return happinessColor;
    case 'calm':        return calmColor;
    case 'excitement':  return excitementColor;
    case 'curiosity':   return curiosityColor;
    case 'anxiety':     return anxietyColor;
    case 'fear':        return fearColor;
    case 'sadness':     return sadnessColor;
    case 'discomfort':  return discomfortColor;
    case 'sleepiness':  return physiologicalColor; // 하위 호환
    default:            return primaryColor;
  }
}

// ── [4] getEmotionLabel 신규 (기존 중복 switch 대체용) ────────
static String getEmotionLabel(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'happiness':   return '기쁨';
    case 'calm':        return '편안함';
    case 'excitement':  return '흥분';
    case 'curiosity':   return '호기심';
    case 'anxiety':     return '불안';
    case 'fear':        return '공포';
    case 'sadness':     return '슬픔';
    case 'discomfort':  return '불편함';
    case 'sleepiness':  return '졸림';
    default:            return emotion;
  }
}

// ── [5] getEmotionEmoji 신규 ───────────────────────────────
static String getEmotionEmoji(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'happiness':   return '😊';
    case 'calm':        return '😌';
    case 'excitement':  return '🤩';
    case 'curiosity':   return '🧐';
    case 'anxiety':     return '😰';
    case 'fear':        return '😨';
    case 'sadness':     return '😢';
    case 'discomfort':  return '😣';
    case 'sleepiness':  return '😴';
    default:            return '🐾';
  }
}

// ── [6] getEmotionGroup 신규 (UI 그룹핑용) ─────────────────
static String getEmotionGroup(String emotion) {
  const positive = ['happiness', 'calm', 'excitement'];
  const neutral  = ['curiosity'];
  if (positive.contains(emotion)) return 'positive';
  if (neutral.contains(emotion))  return 'neutral';
  return 'negative';
}

// ── [7] 감정 정렬 순서 상수 ────────────────────────────────
static const List<String> emotionOrder = [
  'happiness', 'calm', 'excitement', 'curiosity',
  'anxiety', 'fear', 'sadness', 'discomfort',
];
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(theme): 감정 8종 컬러 + 헬퍼 메서드 중앙화 (C)`

---

## D. EmotionScores 엔티티 확장

**소요 시간**: 30분
**대상 파일**: `pjh/lib/features/emotion/domain/entities/emotion_analysis.dart`

```dart
// ── [1] EmotionScores 필드 추가 ──────────────────────────────
// 기존 5개 유지. 신규 4개는 optional + 기본값 0.0으로만 추가.
// sleepiness는 절대 삭제 금지.

final double calm;        // 신규
final double excitement;  // 신규
final double fear;        // 신규
final double discomfort;  // 신규

@Deprecated('생리지표로 분리됨. EmotionAnalysis.isSleepy 사용')
final double sleepiness;  // 기존 유지, deprecated 처리

// ── [2] 생성자 ─────────────────────────────────────────────
const EmotionScores({
  required this.happiness,
  this.calm        = 0.0,  // optional
  this.excitement  = 0.0,  // optional
  required this.curiosity,
  required this.anxiety,
  this.fear        = 0.0,  // optional
  required this.sadness,
  this.discomfort  = 0.0,  // optional
  this.sleepiness  = 0.0,  // deprecated, optional
  // 기존 나머지 필드(stressLevel, activityLevel 등) 그대로 유지
});

// ── [3] EmotionAnalysis 클래스에 생리지표 추가 ────────────────
final bool isSleepy;  // 생성자에 this.isSleepy = false 추가 (optional)

// ── [4] total getter 수정 (sleepiness 제외) ─────────────────
double get total =>
  happiness + calm + excitement + curiosity +
  anxiety + fear + sadness + discomfort;

// ── [5] dominantEmotion getter 수정 ─────────────────────────
String get dominantEmotion {
  final scores = {
    'happiness': happiness, 'calm': calm,
    'excitement': excitement, 'curiosity': curiosity,
    'anxiety': anxiety, 'fear': fear,
    'sadness': sadness, 'discomfort': discomfort,
  };
  return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

// ── [6] toJson / fromJson ────────────────────────────────────
// calm, excitement, fear, discomfort 추가
// isSleepy: fromJson에서 json['is_sleepy'] ?? false
// sleepiness: fromJson에서 json['sleepiness'] ?? 0.0 (하위 호환 유지)

// ── [7] empty() factory 수정 ────────────────────────────────
EmotionScores(
  happiness: 0.125, calm: 0.125, excitement: 0.125, curiosity: 0.125,
  anxiety: 0.125, fear: 0.125, sadness: 0.125, discomfort: 0.125,
)

// ── [8] copyWith 수정 ────────────────────────────────────────
// calm, excitement, fear, discomfort, isSleepy 파라미터 추가
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(domain): EmotionScores 5종→8종 확장 + isSleepy 생리지표 분리 (D)`

---

## E. EmotionScoresModel 데이터 모델 확장

**소요 시간**: 20분
**대상 파일**: `pjh/lib/features/emotion/data/models/emotion_analysis_model.dart`

```dart
// D단계 엔티티 변경에 맞게 Model 업데이트

// [1] 생성자: calm, excitement, fear, discomfort → super.calm 등으로 추가
// [2] fromEntity: 신규 4개 필드 추가
// [3] fromMap:
  calm:        (map['calm']        as num?)?.toDouble() ?? 0.0,
  excitement:  (map['excitement']  as num?)?.toDouble() ?? 0.0,
  fear:        (map['fear']        as num?)?.toDouble() ?? 0.0,
  discomfort:  (map['discomfort']  as num?)?.toDouble() ?? 0.0,
// [4] toMap:
  'calm': calm, 'excitement': excitement,
  'fear': fear, 'discomfort': discomfort,
// [5] EmotionAnalysisModel.fromMap:
  isSleepy: (map['emotion_analysis']?['is_sleepy'] as bool?) ?? false,
// [6] copyWith: 신규 4개 + isSleepy 파라미터 추가
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(model): EmotionScoresModel 8종 확장 (E)`

---

## F. Gemini AI 프롬프트 개편

**소요 시간**: 40분
**대상 파일**: `pjh/lib/features/emotion/data/services/gemini_ai_service.dart`

```dart
// _buildPrompt 메서드 전면 교체

static String _buildPrompt({String? petType, String? breed}) {
  final breedContext = ...;  // 기존 유지

  return """
이 사진의 반려동물을 아래 심리학·신경과학 이론에 기반하여 분석해주세요.
$breedContext

[분석 이론 기반]
- Russell(1980) 원형 모델: valence(긍정/부정) × arousal(고각성/저각성)
- Panksepp(1998) 정동 신경과학: 포유류 7대 감정 시스템
- Ekman(1992) 기본 감정: 얼굴 근육 움직임 기반 분류

[1] 감정 분포 (0.0~1.0, 합계 반드시 1.0):
- happiness  (기쁨):  긍정-중간각성 | Panksepp PLAY   | 입 열림·눈 빛남·편안한 귀
- calm       (편안함): 긍정-저각성  | Panksepp CARE   | 눈 반쯤 감음·이완된 귀입자세
- excitement (흥분):  긍정-고각성  | Ekman 확장      | 귀 세움·눈 크게·입 열림
- curiosity  (호기심): 중립-중간각성 | Panksepp SEEKING| 귀 앞·고개 기울임
- anxiety    (불안):  부정-중간각성 | Panksepp ANXIETY| 귀 뒤·눈 흰자·긴장
- fear       (공포):  부정-고각성  | Panksepp FEAR   | 귀 완전뒤·동공확대·몸낮춤
- sadness    (슬픔):  부정-저각성  | Panksepp GRIEF  | 귀처짐·눈처짐·고개숙임
- discomfort (불편함): 부정-중간각성 | Panksepp RAGE전 | 눈살찌푸림·입긴장

[2] 생리 지표 (Russell 모델: 각성 상태, 감정과 별도):
- is_sleepy: 졸림 true/false
- stress_level: 0~100
- activity_level: 0~100
- comfort_level: 0~100

[3] 건강 신호: "good" / "normal" / "caution"
[4] 부위별: eyes, ears, mouth, posture (state + signal)
[5] 행동 권장 2~3가지
${breedContext.isNotEmpty ? '[6] 품종 해석 1~2문장' : ''}

JSON 형식으로만 응답:
{
  "happiness": 0.0, "calm": 0.0, "excitement": 0.0, "curiosity": 0.0,
  "anxiety": 0.0, "fear": 0.0, "sadness": 0.0, "discomfort": 0.0,
  "is_sleepy": false,
  "stress_level": 0, "activity_level": 0, "comfort_level": 0,
  "health_signal": "good",
  "facial_features": {
    "eyes": {"state": "", "signal": ""},
    "ears": {"state": "", "signal": ""},
    "mouth": {"state": "", "signal": ""},
    "posture": {"state": "", "signal": ""}
  },
  "health_tips": ["", ""]
}
동물이 없으면: 감정 각각 0.125, is_sleepy false, 지표 50
""";
}

// _parseResponse 메서드 수정:
// [1] 8감정 파싱 추가 (calm, excitement, fear, discomfort)
// [2] is_sleepy 파싱 추가
// [3] 정규화: sleepiness 제외한 8감정만 합산
// [4] EmotionScoresModel 생성자에 8감정 + isSleepy 전달
// [5] 로그: happiness 외 fear, discomfort도 출력
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(ai): Gemini 프롬프트 8종 + 이론 기반 개편 (F)`

---

## G. app_constants.dart — emotionTypes 업데이트

**소요 시간**: 5분
**대상 파일**: `pjh/lib/core/constants/app_constants.dart`

```dart
// emotionTypes 8개로 확장 (AppTheme.emotionOrder와 동일 순서 유지)
static const List<String> emotionTypes = [
  'happiness',
  'calm',
  'excitement',
  'curiosity',
  'anxiety',
  'fear',
  'sadness',
  'discomfort',
];
// sleepiness 제거 (생리지표로 분리)
// 단, 기존 데이터 호환을 위해 아래 별도 상수 추가:
static const List<String> legacyEmotionTypes = ['sleepiness']; // DB 구버전 데이터용
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(constants): emotionTypes 8종으로 업데이트 (G)`

---

## H. emotion_repository_impl.dart — 통계 계산 수정

**소요 시간**: 25분
**대상 파일**: `pjh/lib/features/emotion/data/repositories/emotion_repository_impl.dart`

```dart
// [1] emotionSums Map 8개 키로 확장
final emotionSums = {
  'happiness': 0.0, 'calm': 0.0, 'excitement': 0.0, 'curiosity': 0.0,
  'anxiety': 0.0, 'fear': 0.0, 'sadness': 0.0, 'discomfort': 0.0,
};
// sleepiness 키 제거 (별도 생리지표로 분리)

// [2] 합산 루프에 신규 4개 추가
emotionSums['calm']!        += analysis.emotions.calm;
emotionSums['excitement']!  += analysis.emotions.excitement;
emotionSums['fear']!        += analysis.emotions.fear;
emotionSums['discomfort']!  += analysis.emotions.discomfort;

// [3] dayAnalyses 일별 평균에도 동일하게 8개 반영

// [4] 358번 줄 scores.sleepiness 참조 → 제거 또는 0.0으로 대체
// (이 라인은 통계 계산 배열에 sleepiness를 넣는 부분이므로 제거)
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(repo): emotion_repository 통계 계산 8종으로 업데이트 (H)`

---

## I. emotion_trend_service.dart 수정

**소요 시간**: 30분
**대상 파일**: `pjh/lib/features/emotion/data/services/emotion_trend_service.dart`

```dart
// [1] wellbeingScore 계산식 (G단계 positiveEmotions 상수 활용)
double score = 0.5;
score += emotions.happiness  * 0.40;
score += emotions.calm       * 0.35;
score += emotions.excitement * 0.20;
score += emotions.curiosity  * 0.25;
score -= emotions.sadness    * 0.40;
score -= emotions.anxiety    * 0.35;
score -= emotions.fear       * 0.45;  // 공포가 가장 강한 부정 신호
score -= emotions.discomfort * 0.30;
return score.clamp(0.0, 1.0);

// [2] emotionTotals Map 8개 키로 확장 (sleepiness 제거)

// [3] emotionTotals 합산 루프: calm, excitement, fear, discomfort 추가

// [4] _emotionToScore switch: 4개 케이스 추가

// [5] _isPositiveEmotion / _isNegativeEmotion 메서드 수정
static bool _isPositiveEmotion(String emotion) =>
  ['happiness', 'calm', 'excitement'].contains(emotion);
static bool _isNegativeEmotion(String emotion) =>
  ['sadness', 'anxiety', 'fear', 'discomfort'].contains(emotion);

// [6] _findDominantEmotion: AppTheme.emotionOrder 기준으로 8개 비교
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(service): emotion_trend 8종 연산 로직 (I)`

---

## J. emotion_insights_service.dart 수정

**소요 시간**: 20분
**대상 파일**: `pjh/lib/features/emotion/data/services/emotion_insights_service.dart`

```dart
// [1] positiveRatio 계산 수정
positiveRatioSum += e.happiness + e.calm + e.excitement + (e.curiosity * 0.5);

// [2] emotionVariation: 4개 추가
totalVariation += (cur.calm - prev.calm).abs()
                + (cur.excitement - prev.excitement).abs()
                + (cur.fear - prev.fear).abs()
                + (cur.discomfort - prev.discomfort).abs();

// [3] 감정 키 목록 8개로 확장 (sleepiness 제거)
const emotionKeys = [
  'happiness', 'calm', 'excitement', 'curiosity',
  'anxiety', 'fear', 'sadness', 'discomfort'
];

// [4] switch-case: calm, excitement, fear, discomfort 케이스 추가

// [5] 공포/불편함 전용 경고 인사이트 추가
if (latestFear > 0.4)
  InsightData(type: InsightType.warning, title: '공포 반응 감지',
    description: '공포 수치가 높습니다. 특정 자극이 원인일 수 있어요.', emotion: 'fear')

if (latestDiscomfort > 0.35)
  InsightData(type: InsightType.warning, title: '신체 불편 신호',
    description: '불편함이 감지됩니다. 건강 체크를 권장해요.', emotion: 'discomfort')
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(service): emotion_insights 8종 + 공포/불편 경고 (J)`

---

## K. emotion_diary_service.dart 수정

**소요 시간**: 15분
**대상 파일**: `pjh/lib/features/emotion/data/services/emotion_diary_service.dart`

```
sleepiness 참조 부분을 grep으로 찾아 8종 키 목록으로 교체.
AppTheme.emotionOrder 상수 활용.
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(service): emotion_diary 8종 키 업데이트 (K)`

---

## L. Supabase DB 마이그레이션

**소요 시간**: 10분
**⚠️ Claude Code 불가 — Supabase Dashboard → SQL Editor에서 직접 실행**

```sql
DROP VIEW IF EXISTS emotion_stats;

CREATE VIEW emotion_stats AS
SELECT
  user_id,
  COUNT(*) as total_analyses,
  AVG((emotion_analysis->>'happiness')::NUMERIC)  as avg_happiness,
  AVG((emotion_analysis->>'calm')::NUMERIC)       as avg_calm,
  AVG((emotion_analysis->>'excitement')::NUMERIC) as avg_excitement,
  AVG((emotion_analysis->>'curiosity')::NUMERIC)  as avg_curiosity,
  AVG((emotion_analysis->>'anxiety')::NUMERIC)    as avg_anxiety,
  AVG((emotion_analysis->>'fear')::NUMERIC)       as avg_fear,
  AVG((emotion_analysis->>'sadness')::NUMERIC)    as avg_sadness,
  AVG((emotion_analysis->>'discomfort')::NUMERIC) as avg_discomfort,
  AVG((emotion_analysis->>'stress_level')::NUMERIC) as avg_stress,
  COUNT(*) FILTER (
    WHERE (emotion_analysis->>'is_sleepy')::BOOLEAN = true
  ) as sleepy_count
FROM emotion_history
GROUP BY user_id;
-- 기존 JSONB 데이터의 sleepiness 값은 그대로 유지됨 (스키마리스 특성)
```

---

## M. emotion_result_page.dart + part 파일들 수정

**소요 시간**: 50분
**대상 파일**: `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`
**⚠️ part 파일(helpers, cards_a/b/c)은 emotion_result_page.dart와 함께 수정. 별도 import 추가 불필요.**

```dart
// ── [1] emotion_result_helpers.dart (_getEmotionValue / Name / Icon) ─────
// AppTheme 메서드로 교체 (중복 제거)

double _getEmotionValue(String emotion) {
  final e = widget.analysis.emotions;
  switch (emotion) {
    case 'happiness':   return e.happiness;
    case 'calm':        return e.calm;
    case 'excitement':  return e.excitement;
    case 'curiosity':   return e.curiosity;
    case 'anxiety':     return e.anxiety;
    case 'fear':        return e.fear;
    case 'sadness':     return e.sadness;
    case 'discomfort':  return e.discomfort;
    default:            return 0.0;
  }
}
// _getEmotionName → AppTheme.getEmotionLabel(emotion) 으로 교체
// _getEmotionIcon → 아래 8종으로 확장
IconData _getEmotionIcon(String emotion) {
  switch (emotion) {
    case 'happiness':   return Icons.sentiment_very_satisfied;
    case 'calm':        return Icons.self_improvement;
    case 'excitement':  return Icons.celebration;
    case 'curiosity':   return Icons.explore;
    case 'anxiety':     return Icons.psychology_alt;
    case 'fear':        return Icons.warning_amber_outlined;
    case 'sadness':     return Icons.sentiment_very_dissatisfied;
    case 'discomfort':  return Icons.sick_outlined;
    default:            return Icons.pets;
  }
}
// _getShortDescription 8종으로 확장
String _getShortDescription(String emotion) {
  switch (emotion) {
    case 'happiness':   return '지금 이 순간, 아이가 행복해 보여요!';
    case 'calm':        return '편안하게 이완된 상태예요. 좋은 환경이에요.';
    case 'excitement':  return '에너지가 넘치는 흥분 상태예요!';
    case 'curiosity':   return '무언가에 호기심이 가득한 눈빛이에요!';
    case 'anxiety':     return '살짝 긴장하고 있어요. 안심시켜 주세요.';
    case 'fear':        return '무언가를 무서워하고 있어요. 안전한 환경을 만들어주세요.';
    case 'sadness':     return '오늘은 조금 기운이 없어 보이네요.';
    case 'discomfort':  return '불편한 것이 있어 보여요. 몸 상태를 확인해주세요.';
    default:            return '오늘 아이의 상태를 확인했어요.';
  }
}

// ── [2] emotion_result_page 본문 _buildEmotionSummaryCard ────────────────
// summaryMap 8종으로 확장
final summaryMap = {
  'happiness':   '오늘 반려동물이 매우 행복해 보여요! 😊',
  'calm':        '편안하고 안정적인 상태예요. 좋은 환경을 유지해주세요 😌',
  'excitement':  '에너지가 넘치는 흥분 상태예요! 함께 놀아주세요 🤩',
  'curiosity':   '호기심이 가득해 보여요! 새로운 놀이를 해보세요 🧐',
  'anxiety':     '불안한 모습이 보여요. 편안한 환경을 만들어주세요 😰',
  'fear':        '무언가를 무서워하고 있어요. 안전한 공간을 제공해주세요 😨',
  'sadness':     '조금 우울해 보이네요. 많이 안아주세요 😢',
  'discomfort':  '불편한 것이 있어 보여요. 몸 상태를 확인해주세요 😣',
};

// ── [3] isSleepy 배너 추가 (결과 페이지 상단 — 감정 카드 위) ────────────
// 감정 결과와 분리해서 상단에 슬라이드 인 배너로 표시
if (widget.analysis.isSleepy)
  AnimatedContainer 또는 Banner:
    '💤 졸린 상태가 감지됐어요. 편히 쉴 수 있는 공간을 만들어주세요.'
    배경: AppTheme.physiologicalColor, 10% opacity
    borderRadius: 12dp

// ── [4] emotion_result_cards_a — _buildDistributionCard 수정 ────────────
// 감정 분포 섹션: AppTheme.emotionOrder 기준 8개 표시
// 긍정/중립/부정 그룹 구분선으로 시각적 분리
// 각 감정 행: AppTheme.getEmotionEmoji(key) + getEmotionLabel(key) + 비율 바

// ── [5] 공유용 텍스트 수정 ───────────────────────────────────────────────
// _getEmotionNameForShare, _getEmotionValueForShare → AppTheme 메서드 활용
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(page): emotion_result_page 8종 감정 반영 (M)`

---

## N. emotion_chart.dart (파이 차트) 수정

**소요 시간**: 20분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_chart.dart`

```dart
// PieChart sections 8개로 확장
List<PieChartSectionData> _buildSections() {
  final emotionData = AppTheme.emotionOrder.map((key) {
    double value;
    switch (key) {
      case 'happiness':   value = emotions.happiness;  break;
      case 'calm':        value = emotions.calm;        break;
      case 'excitement':  value = emotions.excitement;  break;
      case 'curiosity':   value = emotions.curiosity;   break;
      case 'anxiety':     value = emotions.anxiety;     break;
      case 'fear':        value = emotions.fear;        break;
      case 'sadness':     value = emotions.sadness;     break;
      case 'discomfort':  value = emotions.discomfort;  break;
      default:            value = 0.0;
    }
    return {
      'label': AppTheme.getEmotionLabel(key),
      'value': value,
      'color': AppTheme.getEmotionColor(key),
    };
  }).toList();
  // ... 기존 섹션 빌드 로직 유지, emotionData 소스만 교체
}
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): emotion_chart 파이차트 8종 (N)`

---

## O. emotion_chart_widget.dart (바 차트) 수정 — UI/UX 개선 포함

**소요 시간**: 35분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_chart_widget.dart`

```
[UI/UX 개선]
문제: 8개 바를 300dp 너비에 나열하면 각 바 너비가 약 30dp로 너무 좁음.
해결: 그룹별 배경 컬러로 시각적 묶음 처리 + 바 너비 자동 조정.

[구현 명세]
barGroups 8개로 변경:
  AppTheme.emotionOrder에 따라 순서대로 배열
  각 바 컬러: AppTheme.getEmotionColor(key)

X축 라벨:
  이름 대신 이모지 사용 (AppTheme.getEmotionEmoji(key))
  → 좁은 공간에서 가독성 확보

그룹 구분 시각화:
  barGroups에서 긍정(0~2) / 중립(3) / 부정(4~7) 그룹 사이에
  그룹 배경 색상 차별화:
  FlGridData horizontalInterval 유지
  각 그룹 범위에 배경 사각형 오버레이
  긍정: successColor 5% opacity
  부정: errorColor 5% opacity

하단 범례:
  Row: 긍정 dot / 중립 dot / 부정 dot + 텍스트 10sp
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): emotion_chart_widget 8종 바차트 + 그룹 구분 (O)`

---

## P. emotion_radar_chart.dart 수정 — UI/UX 개선 포함

**소요 시간**: 30분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_radar_chart.dart`

```
[UI/UX 검토 결과]
5각형 → 8각형 전환 시 모바일에서 라벨 겹침 발생.

[해결 방향: 2개 중 1개 선택]
옵션 A (권장): 긍정/중립/부정 3개 그룹 값으로 요약하는 삼각 레이더
  긍정점수 = (happiness + calm + excitement) / 3
  중립점수 = curiosity
  부정점수 = (anxiety + fear + sadness + discomfort) / 4
  → RadarChart 3각형으로 단순화, 직관적

옵션 B: 8축 유지하되 size 300dp + titlePositionPercentageOffset 0.45로 확대
  getTitle 내 텍스트: AppTheme.getEmotionEmoji(index 기준)만 표시 (이름 생략)

[구현 명세: 옵션 A 기준]
titles: ['긍정', '중립', '부정'] (3개)
dataEntries:
  RadarEntry(value: (emotions.happiness + emotions.calm + emotions.excitement) / 3),
  RadarEntry(value: emotions.curiosity),
  RadarEntry(value: (emotions.anxiety + emotions.fear + emotions.sadness + emotions.discomfort) / 4),

[기존 EmotionIntensityGauge 위젯]
이 파일 하단의 EmotionIntensityGauge 위젯은 개별 감정 강도 표시에 활용 가능.
8종 감정 각각을 세로 게이지 리스트로 emotion_result_page에서 활용 검토.
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): emotion_radar 3그룹 요약 차트로 개편 (P)`

---

## Q. emotion_interpretation_card.dart 수정

**소요 시간**: 30분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_interpretation_card.dart`

```dart
// [1] _generateInterpretation switch-case 8종으로 확장
case 'calm':
  return _InterpretationData(
    title: '편안함', subtitle: '편안함이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
    primaryColor: AppTheme.calmColor,
    reason: _getCalmReason(dominantValue, secondaryEmotion),
  );
case 'excitement':
  // ...
case 'fear':
  // ...
case 'discomfort':
  // ...

// [2] 신규 reason 메서드 추가
String _getCalmReason(double value, String secondary) =>
  value > 0.6
    ? '매우 이완된 상태예요. 현재 환경이 아이에게 잘 맞아요.'
    : '비교적 안정적인 상태예요.';

String _getFearReason(double value, String secondary) =>
  value > 0.5
    ? '강한 공포 반응이 감지됩니다. 원인 자극을 파악하고 즉시 안전한 환경을 제공해주세요.'
    : '약한 공포 반응이 있어요. 안심시켜 주세요.';

String _getDiscomfortReason(double value, String secondary) =>
  value > 0.5
    ? '신체 불편함이 강하게 감지됩니다. 수의사 방문을 권장해요.'
    : '가벼운 불편함 신호예요. 몸 상태를 확인해주세요.';

// [3] 중복 _getEmotionValue → AppTheme 메서드로 교체
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): interpretation_card 8종 감정 해석 (Q)`

---

## R. emotion_recommendations_card.dart 수정

**소요 시간**: 25분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_recommendations_card.dart`

```dart
// 신규 감정 4종 추천 행동 추가 (기존 4종 유지)
case 'calm':
  return _Recommendations(immediate: [...], today: [...], ongoing: [...]);
  // immediate: '지금 환경을 유지해주세요. 스트레스 없는 상태예요.'
  // today: '조용한 공간에서 함께 쉬어보세요.'

case 'excitement':
  // immediate: '함께 놀아주거나 산책으로 에너지를 발산시켜주세요.'
  // ongoing: '과도한 흥분이 지속되면 진정 훈련을 고려해보세요.'

case 'fear':
  // immediate: '원인 자극을 즉시 제거해주세요.'
  // today: '안전한 은신처(켄넬, 담요) 제공'
  // ongoing: '지속되는 공포는 수의사 상담 권장'

case 'discomfort':
  // immediate: '피부, 귀, 발바닥 등 신체 부위를 점검해주세요.'
  // today: '이물질, 기생충 여부 확인'
  // ongoing: '지속되면 수의사 진료 예약'
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): recommendations_card 8종 행동 권장 (R)`

---

## S. emotion_loading_widget.dart 수정

**소요 시간**: 10분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/emotion_loading_widget.dart`

```dart
// 감정 목록 8종으로 업데이트
final emotionLabels = AppTheme.emotionOrder
    .map((key) => AppTheme.getEmotionEmoji(key) + ' ' + AppTheme.getEmotionLabel(key))
    .toList();
// → ['😊 기쁨', '😌 편안함', '🤩 흥분', '🧐 호기심', ...]
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): emotion_loading 8종 텍스트 (S)`

---

## T. emotion_share_card.dart 수정 — UI/UX 개선 포함

**소요 시간**: 20분
**대상 파일**: `pjh/lib/features/emotion/presentation/widgets/result/emotion_share_card.dart`

```
[UI/UX 개선]
8종 바 차트를 모두 표시하면 공유 카드가 복잡해짐.
→ dominant 1개 크게 표시 + 나머지 7개를 작은 dot 형태로 아래 나열.

[구현 명세]
상단: 주요 감정 (이모지 + 이름 + 퍼센트) 크게 표시
      AppTheme.getEmotionEmoji(dominant) + getEmotionLabel + 퍼센트

중간: 감정 dot 7개 (나머지 감정)
  Row: 각 감정 원형 8dp dot (AppTheme.getEmotionColor(key)) + 퍼센트 9sp
  상위 3개만 불투명, 나머지 4개는 opacity 0.4로 흐릿하게

하단 출처 표기:
  '이 분석은 Russell(1980) 원형 모델 기반입니다'
  11sp, lightTextColor
```

**완료 기준**: flutter analyze 0 issues
**커밋 메시지**: `feat(widget): emotion_share_card 8종 + 이론 출처 (T)`

---

## U. 페이지별 중복 헬퍼 메서드 교체 (누락 파일 처리)

**소요 시간**: 60분
**⚠️ 이전 작업지시서에서 완전히 누락된 단계**
아래 6개 파일에 sleepiness 참조 및 중복 helper 메서드가 있다. 하나씩 처리.

---

### U-1. emotion_calendar_page.dart

**대상 파일**: `pjh/lib/features/emotion/presentation/pages/emotion_calendar_page.dart`

```dart
// [1] 하드코딩 _emotionEmoji / _emotionName Map 삭제
// AppTheme 메서드로 교체:
//   기존: _emotionEmoji[dominant] → AppTheme.getEmotionEmoji(dominant)
//   기존: _emotionName[dominant]  → AppTheme.getEmotionLabel(dominant)

// [2] 캘린더 dot 마커 색상:
//   AppTheme.getEmotionColor(dominant) 사용 (8종 자동 반영)

// [3] 감정 통계 표시:
//   getEmotionLabel, getEmotionEmoji로 8종 자동 반영
```

**커밋 메시지**: `feat(page): emotion_calendar 8종 감정 + AppTheme 중앙화 (U-1)`

---

### U-2. emotion_history_page.dart

**대상 파일**: `pjh/lib/features/emotion/presentation/pages/emotion_history_page.dart`

```dart
// [1] 감정 분포 바:
//   기존 5종 하드코딩 → AppTheme.emotionOrder 기준 8종으로 교체
//   AppTheme.sleepinessColor → AppTheme.physiologicalColor

// [2] 필터 다이얼로그 감정 칩 (UI/UX 개선):
//   기존: 5개 FilterChip 나열 → 8개 시 Wrap 2줄 됨
//   개선: 긍정/중립/부정 3개 섹션으로 그룹화
//
//   [긍정] 기쁨 · 편안함 · 흥분
//   [중립] 호기심
//   [부정] 불안 · 공포 · 슬픔 · 불편함
//
//   각 섹션: 작은 섹션 라벨(10sp, secondaryTextColor) + FilterChip Row

// [3] _buildEmotionFilterChip에 8종 케이스 추가
//     AppTheme.getEmotionColor(key) 사용

// [4] 중복 helper 메서드 → AppTheme 메서드로 교체
//   _getEmotionColor → AppTheme.getEmotionColor
//   _getEmotionIcon → 위 M단계 로직 참고
```

**커밋 메시지**: `feat(page): emotion_history 8종 + 필터 그룹화 (U-2)`

---

### U-3. emotion_trend_page.dart

**대상 파일**: `pjh/lib/features/emotion/presentation/pages/emotion_trend_page.dart`

```dart
// [1] _buildEmotionDistribution의 emotionMap 8종으로 확장
final emotionMap = {
  'happiness': emotions.happiness, 'calm': emotions.calm,
  'excitement': emotions.excitement, 'curiosity': emotions.curiosity,
  'anxiety': emotions.anxiety, 'fear': emotions.fear,
  'sadness': emotions.sadness, 'discomfort': emotions.discomfort,
};

// [2] wellbeingScore 계산식: I단계 emotion_trend_service와 동일한 가중치 적용
//   기존: score += emotions.happiness * 0.5;
//   변경: I단계 계산식으로 교체

// [3] 감정 컬러/이름 참조 → AppTheme 메서드로 교체
```

**커밋 메시지**: `feat(page): emotion_trend 8종 감정 분포 (U-3)`

---

### U-4. weekly_report_page.dart

**대상 파일**: `pjh/lib/features/emotion/presentation/pages/weekly_report_page.dart`
**⚠️ 하드코딩 컬러 사용 — AppTheme 업데이트만으로 자동 반영 안 됨. 반드시 수정 필요.**

```dart
// [1] 하드코딩 컬러 Map 삭제 (가장 중요)
// 기존:
// static const _emotionColor = {
//   'happiness': Color(0xFF5BC0EB), 'sadness': Color(0xFF2C4482),
//   'anxiety': Color(0xFFFF6F61), 'sleepiness': Color(0xFF1E3A5F),
//   'curiosity': Color(0xFF0077B6),
// };
// 삭제 후 → AppTheme.getEmotionColor(key) 사용

// [2] _emotionEmoji / _emotionName Map 삭제
// → AppTheme.getEmotionEmoji(key) / getEmotionLabel(key) 사용

// [3] 주간 리포트 감정 표시:
//   AppTheme.emotionOrder 기준으로 8종 자동 반영
```

**커밋 메시지**: `feat(page): weekly_report 하드코딩 컬러 제거 + 8종 (U-4)`

---

### U-5. my_emotion_history_page.dart + my_posts_page.dart

**대상 파일**
- `pjh/lib/features/my/presentation/pages/my_emotion_history_page.dart`
- `pjh/lib/features/my/presentation/pages/my_posts_page.dart`

```dart
// 두 파일 모두 동일한 패턴:
// 중복 switch-case (_getEmotionName, _getEmotionColor, _getEmotionIcon)
// → AppTheme.getEmotionLabel / getEmotionColor 로 교체
// sleepiness case → 제거 (하위 호환: default로 처리)
```

**커밋 메시지**: `feat(page): my탭 감정 8종 + AppTheme 중앙화 (U-5)`

---

### U-6. 홈 위젯 (home_dashboard_header, statistics_summary_card)

**대상 파일**
- `pjh/lib/features/home/presentation/widgets/home_dashboard_header.dart`
- `pjh/lib/features/home/presentation/widgets/statistics_summary_card.dart`

```dart
// home_dashboard_header.dart:
// 기존 하드코딩 이모지/설명 맵
// 'sleepiness': '😴', 'sleepiness': '졸린가봐요 😴'
// → AppTheme.getEmotionEmoji / getEmotionLabel 교체
// 8종 감정 자동 반영

// statistics_summary_card.dart:
// 감정 리스트 하드코딩 → AppTheme.emotionOrder 사용
// sleepiness 케이스 → AppTheme.getEmotionColor(key)로 교체
```

**커밋 메시지**: `feat(widget): 홈 위젯 감정 8종 반영 (U-6)`

---

### U-7. 소셜·펫 feature

**대상 파일**
- `pjh/lib/features/social/presentation/widgets/post_card.dart`
- `pjh/lib/features/social/presentation/pages/create_post_page.dart`
- `pjh/lib/features/pets/presentation/pages/public_pet_page.dart`

```dart
// 세 파일 모두:
// 감정 컬러/이름/이모지 중복 switch-case → AppTheme 메서드로 교체
// sleepiness case → 제거

// create_post_page.dart:
// '졸림': analysis.emotions.sleepiness → 제거 또는 is_sleepy 별도 표시
// 8종 감정 동적 표시: AppTheme.emotionOrder 기반으로 반복
```

**커밋 메시지**: `feat(widget): 소셜/펫 감정 8종 반영 (U-7)`

---

## V. recent_emotion_card.dart + pet_profile_card.dart 수정

**소요 시간**: 25분

```dart
// [UI/UX 개선]
// 홈 화면에는 8종 감정 모두 표시하지 않는다.
// dominant 1개 + secondary 1개만 표시 → 홈 화면 정보 과부하 방지

// recent_emotion_card.dart:
// dominant: AppTheme.getEmotionEmoji + getEmotionLabel + 퍼센트
// secondary: 작은 텍스트로 2위 감정 표시
// AppTheme 메서드로 모든 switch-case 교체

// pet_profile_card.dart:
// '오늘 기분: {emoji} {label} {퍼센트}%' 형태 유지
// secondary emotion 추가 표시:
// '+ {emoji2} {label2}' (14sp, secondaryTextColor)
```

**커밋 메시지**: `feat(widget): 홈 감정 카드 dominant+secondary 표시 (V)`

---

## W. 테스트 코드 업데이트

**소요 시간**: 30분
**대상 파일**: `pjh/test/features/emotion/emotion_analysis_bloc_test.dart`

```dart
// [1] 더미 데이터 8종으로 업데이트 (합계 1.0 유지)
EmotionScores(
  happiness: 0.25, calm: 0.15, excitement: 0.10, curiosity: 0.10,
  anxiety: 0.15, fear: 0.10, sadness: 0.10, discomfort: 0.05,
)

// [2] 신규 테스트 케이스
test('calm 감정 컬러 반환'): expect(AppTheme.getEmotionColor('calm'), AppTheme.calmColor)
test('isSleepy true 생리지표 분리 확인'): expect(analysis.isSleepy, true)
test('8감정 합계 정규화'): expect(scores.total, closeTo(1.0, 0.01))
test('dominantEmotion 8종 중 올바른 값 반환')
test('fear > 0.4 경고 인사이트 생성')
test('discomfort > 0.35 경고 인사이트 생성')
```

**flutter test && flutter analyze 실행**
**커밋 메시지**: `test: 감정 8종 테스트 케이스 (W)`

---

## X. 통합 빌드 검증

**소요 시간**: 30분

```bash
flutter analyze  # 0 issues 필수
flutter test     # 전체 통과 필수
flutter build apk --debug
flutter run      # 실기기 실행

# 수동 시나리오 테스트
# 1. AI분석 → 사진 업로드 → 결과 화면
#    - 8종 감정 바 표시 확인
#    - 그룹 구분(긍정/중립/부정) 시각화 확인
#    - isSleepy 배너 표시 확인
#    - 레이더 차트 3그룹 요약 확인
# 2. 홈 화면 → 최근 감정 카드 dominant + secondary 표시 확인
# 3. 감정 히스토리 → 캘린더 dot 8종 컬러 확인
# 4. 감정 히스토리 → 필터 다이얼로그 그룹형 칩 확인
# 5. 주간 리포트 → 하드코딩 컬러 제거 확인
# 6. 공유 기능 → 공유 카드 dominant + dot 7개 표시 확인

# sleepiness 잔존 여부 최종 확인
grep -rn "sleepiness" lib/ --include="*.dart" | grep -v "deprecated\|Deprecated\|@Deprecated\|// sleepiness\|sleepiness = 0.0\|sleepiness ?? 0.0"
# → 0개여야 함 (deprecated 선언부와 기본값 처리만 남아야 함)
```

**커밋 메시지**: `test: 통합 빌드 검증 완료 (X)`

---

## Y. 브랜치 병합

**소요 시간**: 10분

```bash
git checkout win-android-release
git pull origin win-android-release
git merge feature/emotion-8class-refactor
git push origin win-android-release
```

**충돌 발생 시**: 충돌 파일 수동 해결 → git add → git commit → push

---

## Z. Gemini 실제 동작 검증

**소요 시간**: 30분
**⚠️ Y단계 병합 후 진행. 실제 secrets.dart에 Gemini API 키 설정 필요.**

```
테스트 케이스:
  케이스 1 - 기쁜 강아지 사진: happiness 높음, fear/discomfort 낮음 확인
  케이스 2 - 불안한 고양이 사진: anxiety 높음, fear 중간 확인
  케이스 3 - 자는 반려동물: is_sleepy true, calm 높음 확인
  케이스 4 - 호기심 표정: curiosity 높음 확인
  케이스 5 - 낯선 환경: fear > anxiety 확인

검증:
  log('분석 결과: ${scores.toJson()}', name: 'GeminiAI'); 로그 확인
  8감정 합계: 0.99~1.01 허용
  is_sleepy: boolean 정상 반환
```

**커밋 메시지**: `test: Gemini 8종 실제 응답 검증 (Z)`

---

## 이론 출처 UI 표기 (Z-1, Z단계 후)

```dart
// emotion_result_page.dart 하단에 추가
Container(
  padding: EdgeInsets.all(12.w),
  decoration: BoxDecoration(
    color: AppTheme.subtleBackground,
    borderRadius: BorderRadius.circular(12.r),
  ),
  child: Text(
    '본 분석은 Russell(1980) 원형 모델과 Panksepp(1998) 정동 신경과학 이론에 기반하여 '
    '8가지 감정을 긍정/중립/부정 3그룹으로 분류합니다.',
    style: TextStyle(fontSize: 10.sp, color: AppTheme.lightTextColor),
  ),
)

// AI분석 탭 설명 텍스트 수정
// 기존: '사진 한 장으로 반려동물 상태를 파악해요'
// 변경: '심리학·신경과학 이론 기반 8가지 감정 분석'
```

**커밋 메시지**: `feat(ui): 감정 분석 이론 출처 표기 (Z-1)`

---

## 최종 문서화 (Z-2)

```
docs/develop/emotion_8class_release_note.md 생성:
  - 변경 일자 / 이론 배경 / 전후 비교표 / 수정 파일 목록 / 하위 호환 정보

docs/DEVELOPER_GUIDE.md 감정 분류 섹션 교체:
  - 5가지 → 8가지 감정 표로 교체
  - 이론 근거 섹션 추가

git tag v2.0.0-emotion-8class
git push origin v2.0.0-emotion-8class
```

**커밋 메시지**: `docs: 감정 8종 개편 릴리즈 노트 + 개발자 가이드 (Z-2)`

---

## 전체 예상 소요 시간 (수정 반영)

| 구간 | 단계 | 소요 | 이전 대비 |
|------|------|------|---------|
| 준비 | A~B | 30분 | 동일 |
| 핵심 모델 | C~F | 2시간 | +30분 (C단계 헬퍼 중앙화) |
| 서비스/상수/레포 | G~L | 2시간 | +45분 (G, H 신규 추가) |
| 감정 페이지+위젯 | M~T | 4시간 | +40분 (UI/UX 개선) |
| 누락 파일 처리 | U (U-1~U-7) | 2시간 | **신규 추가** |
| 홈 위젯 | V | 25분 | 동일 |
| 검증/배포 | W~Z | 2시간 | 동일 |
| **합계** | | **약 13시간** | +4시간 |
