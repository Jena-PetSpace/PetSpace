# 작업지시서: UIUX Wave 1B — 반려동물 추가·수정 시트

- 상태: 사용자 목업 및 제한된 외부 Claude Fable 5 검토·구현 전송 승인 완료 — 양쪽 비준 대기
- 선행 완료: Wave 1A `20260714-UIUX-wave1A-ratification-db56`
- 작성: Codex
- 구현 후보: Claude Code `claude-fable-5`
- 교차 리뷰: Codex 및 Claude Fable 5
- commit·merge·push·deploy: 금지

사용자 승인 기록: 2026-07-14, 목업 승인 및 이 작업지시서·목업·승인된 3개 파일 범위의 Claude Fable 5 외부 전송·열람·구현 승인. 비밀키·환경파일·보호 화면은 전송 범위에서 제외한다.

## 목표

현재 한 화면에 길게 이어진 반려동물 추가·수정 폼을 기본 정보와 선택 여권 정보로 명확히 구분한다. 승인된 Wave 1A의 중립 surface, 타이포, 간격, radius, 다크모드, 44px 터치 계약을 유지하면서 기존 입력값·검증·저장·업로드·콜백·문구·데이터 계약은 바꾸지 않는다.

## 정확한 변경 manifest

기존 파일 1개만 수정한다.

1. `pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart`
   - 변경 전 SHA-256: `27045cbc8a07fed12016ba4fb1cdc3744813ea2e5e277eb518b78fc254842692`

신규 파일 2개만 만들 수 있다.

2. `pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart`
3. `pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart`

이 목록 밖 앱 코드·테스트·문서는 수정하지 않는다.

## 소비자 보호 hash

아래 소비자는 읽기·테스트만 허용하고 직접 수정하지 않는다.

- `pet_management_page.dart`: `8711bc1ed385a2d423da66c10e1c7ef4c2788adb4a0f231d07aa0c0f3629cec0`
- `pet_detail_page.dart`: `ac62d87eb140cd85a62a75060f65c7497001dc309fa4522f009d792ca8cffa4e`
- `petspace_page_scaffold.dart`: `4be04bb4410495a56a345fdf6a3e1b73d1cda41257d3fe323230b65bea9aa69d`
- `petspace_settings_components.dart`: `22d531a13da6c51fca90d5faaa93c40ffee3f684d5cd1f6efd515580bc431f66`
- `petspace_state_view.dart`: `edb26f99ec8ed2f8fe136c3d912a363c0583e5480cf1817ea53371b8e1806ca7`

기존 보호 범위인 실제 홈, `features/home/**`, `features/emotion/presentation/**`, `main_navigation.dart`, AppTheme, 기존 shared widget, route·BLoC·domain·data·Repository·DB·secret·법무 문서도 수정 금지다.

## 현재 진입점

- 펫 관리 빈 상태의 추가 CTA
- 펫 관리 목록 상단 추가 CTA
- PetCard 수정 메뉴
- 펫 상세의 수정 진입

추가와 수정은 같은 `AddPetBottomSheet`를 사용한다. 모든 진입점의 생성자와 `onPetAdded(Pet)` 계약을 그대로 유지한다.

## 승인 대상 시각 구조

1. 상단: sheet handle, 기존 제목 `반려동물 추가하기` 또는 `반려동물 수정하기`, 닫기 버튼
2. 프로필 사진: 88~100px 원형, 사진 선택 동작 유지, 장식성 다색 배경 제거
3. 기본 정보 section: 이름, 종류, 품종, 성별, 생년월일, 설명
4. 종류·성별: 기존 값과 onChanged 의미를 유지한 단일 선택 segmented control
5. 여권 정보: 기존 `여권 정보 (선택)`과 안내 문구를 사용하는 접을 수 있는 section
6. 여권 section은 신규 추가 시 기본 접힘, 수정 시 기존 여권 값이 하나라도 있으면 기본 펼침
7. 하단: 스크롤과 분리된 `취소` 및 기존 `추가하기`/`수정하기` CTA, 로딩·disabled 상태 유지
8. 키보드가 올라오면 sheet가 viewInsets를 반영하고 폼 본문만 스크롤되며 하단 CTA가 가려지지 않는다.

새 정책·법무·수의학 문구를 만들지 않는다. 목업의 짧은 보조 라벨은 시각 설명용이며 실제 구현 문구는 현재 파일의 기존 문자열 집합을 사용한다.

## 디자인 계약

- sheet 배경·본문·보조·경계는 라이트에서 PetSpace v2, 다크에서 `Theme.of(context)`의 surface/onSurface/onSurfaceVariant/outlineVariant를 우선한다.
- 브랜드·선택·CTA는 `AppTheme.actionBase`, 오류는 승인된 error 의미 토큰을 사용한다.
- section 간격 24, 필드 간격 16, 내부 padding 16~20, 입력 radius 8, section/sheet radius 14/20 역할을 따른다.
- 헤더는 heading 17, section heading 17, body 15, caption 13 역할을 사용한다.
- 모든 icon button, segmented item, 날짜 선택, 취소·저장 CTA는 최소 44px 터치 영역을 보장한다.
- 320×568 및 360×800, text scale 150%, 키보드 viewInsets에서 overflow가 없어야 한다.
- 국기 이모지는 기존 국가 식별 정보이므로 유지한다. 신규 장식 이모지는 추가하지 않는다.

## UI 전용 분리 파일

`pet_editor_form_widgets.dart`에는 비즈니스 상태·Supabase·DI·업로드·Pet 생성을 넣지 않는다. 허용 후보는 다음 UI-only 컴포넌트뿐이다.

- `PetEditorSection`
- `PetEditorSegmentedChoice<T>`
- 필요한 경우 sheet handle 또는 고정 action bar

컴포넌트 API는 표시 label/value/selected/onSelected/children 정도로 제한하며 route나 저장 의미를 알면 안 된다.

## 동작 불변 계약

- `AddPetBottomSheet({Pet? pet, required Function(Pet) onPetAdded})` 시그니처 유지
- `_initializeWithPet`, controller 초기값·dispose 유지
- 종류 변경 시 품종·직접 입력 초기화 순서 유지
- 이름 50자 및 기존 validator 문구 유지
- 품종 `기타`, 생년월일 범위 1990~현재, 설명 maxLines 의미 유지
- 여권 영문 대문자 formatter, 허용 문자, 한글 이름 helper, 국가 코드 목록·기본 `KOR` 유지
- 이미지 picker 크기·품질, preview, upload service, petId 결정 유지
- Supabase current user 확인, 로그인 필요 SnackBar, Pet 필드 매핑, onPetAdded→pop, finally loading reset 순서 유지
- 기존 원시 예외 `$e` 표시 2곳은 별도 P0 범위이므로 이번 UI wave에서 수정하지 않는다.
- `pet_management_page.dart`와 `pet_detail_page.dart` 호출부 수정 금지

## 테스트

신규 widget test는 네트워크·Supabase 저장을 호출하지 않고 다음을 검증한다.

- 추가 모드 제목·기본 필드·버튼 렌더
- 빈 이름 submit 시 기존 validator 문구와 callback 미호출
- 종류·성별 단일 선택과 기존 값 의미
- 여권 section 접기·펼치기 및 기존 필드 렌더
- 수정 모드 제목·기존 값 prefill·기존 여권 값이 있으면 펼침
- 라이트·다크 surface/text 선택
- 320×568·150% text scale·키보드 viewInsets에서 예외/overflow 없음
- 닫기·날짜·선택·하단 CTA 최소 44px

## 자동 검증

`pjh/`에서 실행한다.

```powershell
dart format --output=none --set-exit-if-changed <변경 3개 파일>
flutter analyze --no-pub
flutter test test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart
flutter test
git diff --check
```

전체 테스트의 기존 14개 실패는 baseline과 분리하고 신규 실패는 0이어야 한다. 소비자·보호 hash와 실제 변경 경로가 manifest와 일치해야 한다.

## 사람 검증 대기

- 실제 추가·수정 진입 네 곳
- 사진 선택 허용·거부·취소·오류
- 키보드가 열린 상태의 스크롤과 CTA
- 라이트·다크 실제 대비
- 360×800, 390×844, 큰 화면, 글자 130~150%
- 긴 이름·품종·설명·여권 helper, 국가 dropdown
- 화면 읽기 순서와 터치 영역

## 중단 조건

- 기존 파일 hash 불일치
- Supabase·업로드·Pet 매핑·callback·route·표시 문구 변경 필요
- 소비자 또는 보호 경로 수정 필요
- 신규 패키지·자산 필요
- Claude Fable 5와 Codex의 manifest·목업·완료 조건 불일치
- blocker/high, 신규 analyzer/test 실패, overflow 또는 접근성 악화
