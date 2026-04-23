# lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 818줄 (Phase 2에서 가장 큰 페이지)

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/pet-registration` (app_router.dart:188)
- **BLoC 의존성:** PetBloc (BlocProvider.value), AuthBloc (read만)
- **상위 탭:** 온보딩 플로우 (프로필 설정 → 반려동물 등록)
- **로그인 필요:** ✅
- **Scaffold 구조:** BlocProvider → Scaffold → AppBar + SafeArea → Padding → Column

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 58-67 | AppBar 뒤로가기 | canPop이면 pop, 아니면 `/onboarding/profile` | 동일 | ✅ |
| 2 | IconButton | 197-201 | 등록된 펫 개별 삭제 | `_removePet(pet)` | 동일 | ✅ |
| 3 | GestureDetector | 250-287 | 반려동물 사진 영역 탭 | `_pickPetPhoto` → ImageSourcePicker | 동일 | ✅ |
| 4 | GestureDetector × 2 | 347-391 | 종류 선택 (강아지/고양이) | `_selectedType` 설정 + 품종 초기화 | 동일 | ✅ |
| 5 | TextFormField | 218-232 | 이름 입력 (필수) | 빈값 검증 | 동일 | ✅ |
| 6 | DropdownButtonFormField | 411-434 | 품종 선택 | `_selectedBreed` 설정, "기타" 선택 시 `_isCustomBreed = true` | 동일 | ✅ |
| 7 | TextFormField | 437-451 | 품종 직접 입력 (기타 선택 시만) | 빈값 검증 | 동일 | ✅ |
| 8 | GestureDetector × 2 | 484-515 | 성별 선택 (수컷/암컷, 토글) | `_selectedGender` 토글 | 동일 | ✅ |
| 9 | GestureDetector | 518-542 | 생년월일 선택 | `showDatePicker` → `_birthDate` | 동일 | ✅ |
| 10 | ElevatedButton.icon | 546-555 | "반려동물 추가" | `_addPet` → 폼 검증 + 목록 추가 | 동일 | ✅ |
| 11 | ElevatedButton | 565-574 | "계속하기" (펫 있을 때) | `_continue` → DB 저장 + `/onboarding/complete` | 동일 | ✅ |
| 12 | OutlinedButton | 580-589 | "나중에 등록하기" (펫 없을 때) | `_skip` → `/onboarding/complete` | 동일 | ✅ |

**상호작용 요소 합계:** 12개

---

## 🎨 UI 요소

### 레이아웃 구조
- BlocProvider(PetBloc) → Scaffold → AppBar + SafeArea → Padding → Column
  - 헤더 + (등록된 펫 목록) + Expanded(Form SingleChildScrollView) + 하단버튼

### 스크롤
- [x] `SingleChildScrollView` (line 208) — 폼 부분만
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 76)

### 리소스 관리
- [x] `_nameController.dispose()` (line 44)
- [x] `_breedController.dispose()` (line 45)

### 오버플로우 위험
- 등록된 펫 많을 경우 헤더 고정 + `_registeredPets.length` → 영역이 커져 Expanded 폼이 줄어듦. 보통 문제 없으나 10마리 이상 등록 시 폼 스크롤이 매우 좁아질 수 있음

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | `_selectedType == null` | 품종 필드 비활성 (힌트 텍스트) |
| 종류 선택 | `_selectedType != null` | 품종 드롭다운 활성화 |
| "기타" 품종 | `_isCustomBreed = true` | 직접 입력 TextField 추가 |
| 펫 없음 | `_registeredPets.isEmpty` | 상단 목록 숨김, 하단 "나중에 등록하기" |
| 펫 있음 | `_registeredPets.isNotEmpty` | 목록 카드 + 하단 "계속하기" |

---

## 🔗 외부 의존성

### API 호출
- PetBloc → PetRepository → Supabase `pets` 테이블

### 권한 요청
- 카메라 / 사진 라이브러리 (ImageSourcePicker)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/pet-registration`
- 진출: `/onboarding/complete` (성공/스킵), `/onboarding/profile` (뒤로)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 신규 가입 후 프로필 설정 완료 시 자동 진입.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🔴 **Critical** | **경쟁조건 `AddPetEvent` + `Future.delayed(500ms)` 체크** | line 753-764: `petBloc.add(AddPetEvent(pet))` 호출 후 고정 500ms 대기로 상태 확인. 네트워크 느리면 false negative → 성공한 것도 실패로 집계됨. 또한 여러 펫 연속 추가 시 이전 이벤트의 상태가 겹침 |
| 2 | 🟠 High | `_addPet` 시 `_formKey.validate()`만 확인 — type이 선택 안 돼도 추가 가능한 코드 경로 | line 634-638에서 type null 가드는 있으나 validator 주석에 `if (_selectedType != null)` 같은 통합 검증 없음. 복잡한 분기 로직 유지 어려움 |
| 3 | 🟠 High | 로컬 상태와 실제 DB 저장 시점 분리 | `_registeredPets` 배열에 저장되지만 실제 DB 저장은 `_continue`에서만. "반려동물 추가" 스낵바는 저장이 아니라 로컬 배열 추가에 불과 — 사용자가 `_continue` 누르기 전에 앱 종료 시 데이터 유실 |
| 4 | 🟡 Medium | 펫 아이콘이 PetType과 무관하게 동일 (`Icons.pets`) | line 170, 330, 338 — 강아지/고양이 시각 구분 없음. UX 저하 |
| 5 | 🟡 Medium | ImageSourcePicker `maxWidth/Height 512` 로 Pet 사진 제한 | 업로드 성능에는 좋지만 프로필 아바타와 동일 크기. 차별화 없음 |
| 6 | 🟡 Medium | BirthDate 기본값 1년 전 | line 622: `DateTime.now().subtract(const Duration(days: 365))` — 어린 강아지/고양이 기본 선택 방해 |
| 7 | 🟢 Low | PetType import alias | line 10, 17 — `pets.PetType`, `PetType` 두 번 import. 혼동 유발 |
| 8 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 감성 |
| 9 | 🟢 Low | 에러 원문 노출 | line 613, 806 `e.toString()` |

---

## ✅ 종합 평가

- **정상 동작:** 12/12 (기능은 작동)
- **버그 발견:** 9건 (**Critical 1** / High 2 / Medium 3 / Low 3)
- **심각도:** **Critical** (경쟁조건)
- **iOS 특화 문제:** Low 1건

### 권장 조치
- **즉시 수정:** 이슈 #1 (PetBloc 상태 확인 로직 재설계 — BlocListener/Stream으로 변경), #3 (로컬 배열 대신 즉시 저장 또는 명확한 임시 저장 UX)
- 다음 이터레이션: #2, #4, #5, #6
- 모니터링: #7, #8, #9

### 경쟁조건 상세 (Critical)

```dart
for (final petData in _registeredPets) {
  petBloc.add(AddPetEvent(pet));
  await Future.delayed(const Duration(milliseconds: 500)); // ⚠️
  final currentState = petBloc.state;
  if (currentState is PetOperationSuccess || currentState is PetLoaded) {
    successCount++;
  }
}
```

- `PetBloc`은 비동기 이벤트 처리. 500ms 안에 Supabase 응답이 도착한다는 보장 없음
- 또한 이전 펫의 성공 상태가 남아있어서 다음 펫 이벤트가 실패해도 PetLoaded로 보일 수 있음
- **권장**: `BlocListener`로 각 결과를 개별 확인하거나 단일 Batch add 이벤트 작성
