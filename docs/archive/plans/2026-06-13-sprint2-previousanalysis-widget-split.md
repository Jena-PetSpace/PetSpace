# Sprint 2 — previousAnalysis 주입 + emotion_analysis_page 위젯 분리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 감정분석 결과 페이지에 직전 분석 1건(previousAnalysis)을 주입해 delta 비교를 활성화하고, 1,383줄짜리 emotion_analysis_page를 동작 불변으로 위젯 분리해 400줄 이하로 줄인다.

**Architecture:** STEP 1은 순수 함수형 usecase(`GetPreviousAnalysis`)를 TDD로 추가하고 호출처 2곳의 `previousAnalysis: null` TODO를 해소. STEP 2는 emotion_analysis_page의 UI 빌더 메서드를 콜백 주입형 StatelessWidget으로 추출(동작·네비게이션·로딩 push 100% 불변).

**Tech Stack:** Flutter / flutter_bloc / dartz Either / get_it(sl) / mocktail + flutter_test.

---

## ⚠️ 절대 수정 금지 파일 (전 STEP 공통)

```
pjh/lib/features/home/**
pjh/lib/features/social/presentation/pages/home_page.dart
pjh/lib/features/emotion/presentation/pages/emotion_loading_page.dart
pjh/lib/features/emotion/presentation/pages/health_loading_page.dart
pjh/lib/features/emotion/presentation/widgets/ai_analysis_loading_widget.dart
pjh/lib/features/emotion/presentation/widgets/emotion_loading_widget.dart
```

- 리팩토링은 emotion_analysis_page의 **UI 빌더 메서드 분리만**. `_runEmotionAnalysis`/`_startHealthAnalysis` 내부의 `Navigator...push(EmotionLoadingPage/HealthLoadingPage)` **호출 형태 그대로 유지** — 로딩 페이지는 import만, 수정 안 함.
- 커밋마다 `git status --short`로 금지 경로 미포함 확인. 포함 시 즉시 중단·보고.

## 📋 조사로 확정된 사실 (plan 작성 중 확인)

1. **repository:** `getAnalysesByPet({required String petId, int limit = 20})` 존재 ([emotion_repository.dart:66](pjh/lib/features/emotion/domain/repositories/emotion_repository.dart#L66)). `EmotionAnalysis`는 `final String id` + `final String? petId` 보유.
2. **호출처 1 (emotion_analysis_page):** `_runEmotionAnalysis` 성공 분기 [emotion_analysis_page.dart:1276-1292](pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart#L1276-L1292). `result is EmotionAnalysisSuccess` → `result.analysis`에 `id`·`petId` 존재. petId는 `_analyzeWithoutPet ? null : _selectedPet?.id`(1256행)로 이미 결정됨.
3. **호출처 2 (loader page):** [emotion_result_loader_page.dart:110-114](pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart#L110-L114). 이 페이지는 `analysisId`만 받지만 **로드한 `_analysis!.petId`로 조회 가능** → petId 없는 경로 아님(STEP1 Step4에서 재확인).
4. **page의 repo 접근:** 현재 `context.read<EmotionAnalysisBloc>()`만 사용. previousAnalysis 조회는 `sl<EmotionRepository>()` 직접 호출 또는 usecase를 `sl()`로 가져와 사용 — DI 패턴은 `sl.registerLazySingleton(() => GetX(sl()))` ([injection_container.dart:213](pjh/lib/config/injection_container.dart#L213) 부근).
5. **테스트:** emotion repository를 mock하는 기존 테스트 없음 → 신규 `MockEmotionRepository extends Mock implements EmotionRepository {}` 작성. mocktail 패턴은 health_usecases_test.dart 참고.
6. **분리 대상 메서드(현 라인):** `_buildFullGuide`(136-315)+`_buildGuideTipRow`(316-382), `_buildImageGrid`(597-734), `_buildManualBreedSelector`(735-890)+`_buildTypeChip`(891-925), `_buildSubTab`(926-972), `_buildAreaChips`(973-1019), `_buildAdditionalInput`(1020-1087), `_buildSectionCard`(1088~). 총 1,383줄.

---

# STEP 1 — previousAnalysis 주입 (커밋 1) · TDD

### Task 1: GetPreviousAnalysis usecase (TDD)

**Files:**
- Create: `pjh/lib/features/emotion/domain/usecases/get_previous_analysis.dart`
- Test: `pjh/test/features/emotion/domain/usecases/get_previous_analysis_test.dart`
- Modify: `pjh/lib/config/injection_container.dart` (DI 등록)
- Modify: `pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart` (호출처 1)
- Modify: `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart` (호출처 2)

> ✅ **저장 타이밍 확정 (조사 완료 — 승인 조건 2):** `SaveAnalysisRequested`는 결과 페이지 `initState`→`addPostFrameCallback`에서 발행([emotion_result_page.dart:77](pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart#L77)). 즉 `_runEmotionAnalysis`가 결과 페이지를 push하는 시점엔 **방금 결과가 아직 DB INSERT 전.** 그래서 excludeId만으로는 타이밍 의존(저장 전이면 id가 안 걸리고, 저장됐으면 걸려야 함) → 신뢰 불가. **선택 기준 = "현재 분석의 `analyzedAt`보다 이전(`<`)인 것 중 최신 1건"** + 보조로 `id == excludeId` 제외(동일 시각 충돌 방지). `getAnalysesByPet`은 `created_at DESC`(= 엔티티 `analyzedAt DESC`) 정렬이므로 첫 매칭이 곧 최신. limit는 방금 결과가 끼어들 수 있으니 여유 있게 5.
>
> ✅ **엔티티 확정:** 시각 필드는 `analyzedAt`(DateTime, required), `EmotionAnalysis.empty()` 팩토리 존재 → 테스트는 `EmotionAnalysis.empty().copyWith(id:..., analyzedAt:...)`로 간소화. `ServerFailure(message:)` 존재.

- [ ] **Step 1: 실패하는 테스트 작성** — `get_previous_analysis_test.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/get_previous_analysis.dart';

class MockEmotionRepository extends Mock implements EmotionRepository {}

// id·analyzedAt만 의미 있는 테스트용 분석 (empty 팩토리 기반)
EmotionAnalysis _a(String id, DateTime at) =>
    EmotionAnalysis.empty().copyWith(id: id, petId: 'p1', analyzedAt: at);

void main() {
  late MockEmotionRepository repo;
  late GetPreviousAnalysis usecase;
  final current = _a('new', DateTime(2026, 6, 13, 12, 0));

  setUp(() {
    repo = MockEmotionRepository();
    usecase = GetPreviousAnalysis(repo);
  });

  test('현재보다 이전 분석이 있으면 그 중 최신 1건 반환', () async {
    // DESC 정렬 가정: [방금 결과(저장됨), 직전, 더 이전]
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([
        _a('new', DateTime(2026, 6, 13, 12, 0)), // 방금 결과(이미 저장된 경우)
        _a('prev', DateTime(2026, 6, 13, 11, 0)), // 직전 ← 기대값
        _a('older', DateTime(2026, 6, 10, 9, 0)),
      ]),
    );

    final result = await usecase(current: current);

    expect(result?.id, 'prev');
  });

  test('저장 전이라 방금 결과가 목록에 없어도 직전 1건 반환', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([
        _a('prev', DateTime(2026, 6, 13, 11, 0)), // 직전 ← 기대값
        _a('older', DateTime(2026, 6, 10, 9, 0)),
      ]),
    );

    final result = await usecase(current: current);

    expect(result?.id, 'prev');
  });

  test('이전 분석이 없으면(방금 1건뿐) null', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([_a('new', DateTime(2026, 6, 13, 12, 0))]),
    );

    final result = await usecase(current: current);

    expect(result, isNull);
  });

  test('0건이면 null', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5))
        .thenAnswer((_) async => const Right([]));

    final result = await usecase(current: current);

    expect(result, isNull);
  });

  test('repository Left(Failure)면 null (throw 안 함)', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5))
        .thenAnswer((_) async => const Left(ServerFailure(message: 'x')));

    final result = await usecase(current: current);

    expect(result, isNull);
  });

  test('petId가 null이면 조회 없이 null', () async {
    final noPet = EmotionAnalysis.empty().copyWith(id: 'x', petId: null);

    final result = await usecase(current: noPet);

    expect(result, isNull);
    verifyNever(() => repo.getAnalysesByPet(
        petId: any(named: 'petId'), limit: any(named: 'limit')));
  });
}
```

> ⚠️ **Step 1 실행 전 확인:** `EmotionAnalysis.empty()`·`copyWith`에 `analyzedAt`/`petId`/`id` 파라미터가 있는지 [emotion_analysis.dart](pjh/lib/features/emotion/domain/entities/emotion_analysis.dart)에서 재확인(확인됨: empty 팩토리 존재, copyWith에 analyzedAt 있음). 없으면 생성자 직접 호출로 대체.

- [ ] **Step 2: 실패 확인** — `cd pjh; flutter test test/features/emotion/domain/usecases/get_previous_analysis_test.dart` → 기대: 컴파일 에러(usecase 없음)로 FAIL

- [ ] **Step 3: 구현** — `get_previous_analysis.dart`

```dart
import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';

/// 방금 만든 결과(current)의 "직전 분석 1건"을 조회한다.
/// 선택 기준: current.analyzedAt 보다 이전 시각인 것 중 최신
///   (+ 보조로 current.id 와 동일한 항목 제외 — 동일 시각 충돌 방지).
/// push 시점엔 current가 아직 DB 저장 전일 수 있으므로 id 제외만으로는 부족,
/// analyzedAt 기준이 정답. getAnalysesByPet은 created_at DESC 정렬이라
/// 첫 매칭이 곧 최신이다.
/// 비교 UI(delta)는 부가 기능 — 실패·빈 결과·petId 없음은 모두 null,
/// 절대 throw하지 않는다 (분석 성공 흐름 우선).
class GetPreviousAnalysis {
  final EmotionRepository repository;

  GetPreviousAnalysis(this.repository);

  Future<EmotionAnalysis?> call({required EmotionAnalysis current}) async {
    final petId = current.petId;
    if (petId == null || petId.isEmpty) return null;

    final result = await repository.getAnalysesByPet(petId: petId, limit: 5);
    return result.fold(
      (_) => null,
      (list) {
        for (final a in list) {
          if (a.id == current.id) continue; // 방금 결과(저장됐다면) 제외
          if (a.analyzedAt.isBefore(current.analyzedAt)) return a; // 첫 매칭=최신
        }
        return null;
      },
    );
  }
}
```

- [ ] **Step 4: 통과 확인** — 같은 명령 → 기대: 6케이스 PASS

- [ ] **Step 5: DI 등록** — `injection_container.dart`의 emotion usecase 등록부(213행 `GetEmotionHistory` 부근)에 추가:

```dart
  sl.registerLazySingleton(() => GetPreviousAnalysis(sl()));
```

상단에 `import` 추가: `import '../features/emotion/domain/usecases/get_previous_analysis.dart';` (기존 emotion usecase import 그룹에 맞춰).

- [ ] **Step 6: 호출처 1 적용** — `emotion_analysis_page.dart` 1276-1292행

먼저 파일 상단 import에 `import '../../domain/usecases/get_previous_analysis.dart';`, `import '../../../../config/injection_container.dart';`(이미 있으면 생략), `import '../../domain/entities/emotion_analysis.dart';`(이미 있으면 생략) 확인.

1276-1292행을 아래로 교체 (조회는 300ms 타임아웃으로 화면 전환을 막지 않음):

```dart
    if (result is EmotionAnalysisSuccess) {
      final analysis = result.analysis;
      // 직전 분석 1건 조회. 비교 UI는 부가 기능이므로 화면 전환을 막지 않도록
      // 300ms 타임아웃 — 느리거나 실패하면 즉시 null로 진행.
      EmotionAnalysis? previous;
      try {
        previous = await sl<GetPreviousAnalysis>()(current: analysis)
            .timeout(const Duration(milliseconds: 300));
      } catch (_) {
        previous = null; // 타임아웃·오류 → 비교 없이 결과 표시
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: EmotionResultPage(
              analysis: analysis,
              imagePaths: imagePathsCopy,
              previousAnalysis: previous,
            ),
          ),
        ),
      );
    } else if (result is EmotionAnalysisError) {
      _showErrorDialog(result.message);
    }
```

> 지연 처리(승인 조건 1): 300ms `.timeout` + try-catch로 **조회가 결과 표시를 지연·차단하지 않음**. petId 없으면 usecase가 즉시 null 반환(조회 자체 안 함). `TimeoutException` import 필요 시 `dart:async` 추가(이미 있으면 생략).

- [ ] **Step 7: 호출처 2 적용** — `emotion_result_loader_page.dart`

이 페이지는 StatefulWidget이고 `_analysis`를 로드해 보관한다. `_analysis!.petId`로 조회 가능하므로 petId 있는 경로다(보고: 범위 조정 불필요). `_loadAnalysis`에서 분석 로드 후 previous도 함께 조회해 상태로 보관한다.

State에 필드 추가:
```dart
  EmotionAnalysis? _previousAnalysis;
```

`_loadAnalysis`를 아래로 교체 (fold 콜백 async 경고를 피하려 성공 시 별도 헬퍼 호출):
```dart
  Future<void> _loadAnalysis() async {
    final repository = sl<EmotionRepository>();
    final result = await repository.getAnalysisById(widget.analysisId);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (analysis) => _onAnalysisLoaded(analysis),
    );
  }

  Future<void> _onAnalysisLoaded(EmotionAnalysis analysis) async {
    // 직전 분석 1건 조회 — 비교 UI는 부가 기능이라 300ms 타임아웃, 실패는 null
    EmotionAnalysis? previous;
    try {
      previous = await sl<GetPreviousAnalysis>()(current: analysis)
          .timeout(const Duration(milliseconds: 300));
    } catch (_) {
      previous = null;
    }
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _previousAnalysis = previous;
      _loading = false;
    });
  }
```

> import 추가: `import '../../domain/usecases/get_previous_analysis.dart';`, `import 'dart:async';`(timeout용 — 이미 있으면 생략). injection_container·EmotionRepository import는 이미 존재(4·7행).

import 추가: `import '../../domain/usecases/get_previous_analysis.dart';` (injection_container import는 이미 4행에 존재).

build의 최종 반환부(110-114행) 교체:
```dart
    return EmotionResultPage(
      analysis: _analysis!,
      previousAnalysis: _previousAnalysis,
    );
```

- [ ] **Step 8: 검증·커밋**

```bash
cd pjh
flutter analyze   # 0 issues 필수
flutter test      # 베이스라인 245/14 + 신규 6 통과 (= 251 PASS / 14 FAIL 예상)
```

`rg "previousAnalysis: null" pjh/lib/features/emotion/presentation/pages` → petId 없는 경로(있다면)만 잔존하는지 확인. 둘 다 해소됐으면 0건.

```bash
git status --short    # 위 5파일만, 금지 경로 없음
git add pjh/lib/features/emotion/domain/usecases/get_previous_analysis.dart pjh/test/features/emotion/domain/usecases/get_previous_analysis_test.dart pjh/lib/config/injection_container.dart pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart
git commit -F <메시지파일>   # "Sprint2-STEP1: previousAnalysis 직전 분석 1건 조회·주입(TODO 2곳 해소)"
```

- [ ] **Step 9: STEP 1 보고 후 사용자 확인 대기** (변경 파일, analyze/test 수치, loader page petId 경로 확인 결과, 금지 파일 무변경)

---

# STEP 2 — emotion_analysis_page 위젯 분리 (커밋 2~N) · 동작 불변 verification

### Task 2: 분리 계획 정의 (승인 게이트)

- [ ] **Step 1: 분리 매핑표를 보고하고 승인 대기** — 아래 표를 사용자에게 제시하고 **승인 후 Task 3 진행**:

| 추출 위젯 (신규 파일 `presentation/widgets/analysis_input/`) | 원본 메서드 | 파라미터·콜백 시그니처 |
|---|---|---|
| `AnalysisGuideSheet` (+ 내부 `_GuideTipRow`) | `_buildFullGuide`+`_buildGuideTipRow` | `{required VoidCallback onClose}` 등 가이드가 참조하는 콜백/상수 인벤토리 후 확정 |
| `ImageGridSection` | `_buildImageGrid` | `{required List<String> imagePaths, required int maxImages, required VoidCallback onAdd, required void Function(int) onRemove}` |
| `ManualBreedSelector` (+ `_TypeChip`) | `_buildManualBreedSelector`+`_buildTypeChip` | `{required String? petType, required TextEditingController breedController, required void Function(String) onTypeChanged, ...}` — Autocomplete 상태 의존 인벤토리 후 확정 |
| `AnalysisSubTab` | `_buildSubTab` | `{required String label, required int index, required int currentIndex, required void Function(int) onTap}` |
| `AreaChips` | `_buildAreaChips` | `{required String? selectedArea, required void Function(String) onSelect}` |
| `AdditionalInputSection` | `_buildAdditionalInput` | `{required TextEditingController controller, ...}` |
| `SectionCard` | `_buildSectionCard` | `{required Widget child}` (순수 래퍼) |

> 각 메서드가 참조하는 상태 필드(`_imagePaths`, `_selectedArea`, 컨트롤러 등)·메서드(`_requestPermissionsAndOpenGuide` 등)·상수(`_maxImages`)를 추출 전 인벤토리해 콜백/파라미터로 전달. setState는 부모에 남기고 위젯은 표시·이벤트 전달만.

### Task 3~N: 위젯 단위 분리 (verification 중심 — 동작 불변이 핵심)

> 한 커밋에 위젯 1~2개. 가장 의존 적은 것부터: `SectionCard` → `AnalysisSubTab`/`AreaChips`/`ImageGridSection` → `AdditionalInputSection` → `ManualBreedSelector` → `AnalysisGuideSheet`.

각 분리 커밋의 공통 절차 (예: Task 3 = SectionCard + AnalysisSubTab):

- [ ] **Step 1: 신규 위젯 파일 작성** — `presentation/widgets/analysis_input/section_card.dart` 등. 원본 메서드 본문을 StatelessWidget `build`로 옮기고, 참조하던 상태는 생성자 파라미터로, setState 호출은 콜백으로 치환. **하드코딩 색이 있으면 Sprint 1에서 추가한 AppTheme 토큰 사용(신규 하드코딩 금지)**.
- [ ] **Step 2: emotion_analysis_page에서 메서드 제거 + 호출부 교체** — `_buildSectionCard(child: x)` → `SectionCard(child: x)`, `_buildSubTab('감정 분석', 0)` → `AnalysisSubTab(label: '감정 분석', index: 0, currentIndex: _selectedTab, onTap: (i) => setState(() => _selectedTab = i))` 형태. import 추가.
- [ ] **Step 3: 동작 불변 검증**
  - `cd pjh; flutter analyze` → 0
  - `flutter test` → 베이스라인 245/14 + STEP1 신규 4 유지 (신규 실패 0)
  - 분리 전후 `build` 메서드가 동일 위젯 트리를 만드는지 육안 대조 (파라미터·콜백 1:1 매칭 확인)
- [ ] **Step 4: 커밋** — 예: `Sprint2-STEP2a: SectionCard·AnalysisSubTab 위젯 분리(동작 불변)`

### Task Final: 본체 정리·보고

- [ ] **Step 1: 본체 줄 수 측정** — `wc -l pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart` (목표: 400줄 이하)
- [ ] **Step 2: 분석 실행/로딩 push 무변경 증명** — `git diff <STEP2-시작-SHA>..HEAD -- pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart`에서 `_runEmotionAnalysis`/`_startHealthAnalysis`의 `Navigator.push(...EmotionLoadingPage/HealthLoadingPage...)` 블록이 **호출 형태 그대로**인지 확인 (STEP1의 previousAnalysis 조회 추가분 외 push 로직 무변경).
- [ ] **Step 3: superpowers:requesting-code-review 1회** → 결과 첨부
- [ ] **Step 4: 수기기 스모크 체크리스트 제출** (다음 항목이 분리 후에도 동작하는지 — 실기기 확인용):
  - 펫 선택 / 미등록(수동) 토글
  - 이미지 추가·삭제 (최대 장수)
  - 품종 Autocomplete (수동 입력 경로)
  - 감정/건강 탭 전환
  - 부위 칩 선택 (건강 탭)
  - 추가입력 텍스트
  - 분석 시작 → 로딩 페이지 진입 → 결과 페이지까지
- [ ] **Step 5: STEP 2 종합 보고 후 대기**

---

## Sprint 2 완료 기준

- [ ] flutter analyze 0 / 테스트 베이스라인 245/14 + STEP1 신규 4 통과 (249/14)
- [ ] 금지 파일 diff 0줄: `git diff <Sprint2-시작-SHA>..HEAD --stat -- <금지 6경로>` → 출력 없음
- [ ] previousAnalysis: petId 있는 분석에서 직전 1건 주입, 없는 경우 null 유지
- [ ] emotion_analysis_page 본체 400줄 이하, 분석 실행/로딩 push 로직 무변경
- [ ] 수기기 스모크 체크리스트 제출

## 인계/보고 사항

- emotion_result_loader_page는 `_analysis.petId`로 조회 가능 → petId 경로 확보(범위 조정 불필요, STEP1 Step7에서 재확인).
- 리팩토링 중 발견되는 죽은 코드·중복은 별도 기록만(이번 범위는 분리, 정리는 보고).
- [[project-homepage-dispose-bug]] — HomePage.dispose 버그는 홈 트랙 인계(이번 범위 외).
