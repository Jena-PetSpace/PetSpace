# 작업지시서: UI/UX Wave 1C — 반려동물 전체 화면 등록·수정 B안

- 상태: 양쪽 비준 완료, Fable 5 사용량 한도로 사용자 지시에 따라 Codex 구현·Claude Opus 4.8 리뷰로 전환
- 선행 완료: Wave 1A `20260714-UIUX-wave1A-ratification-db56`, Wave 1B `20260714-UIUX-wave1B-pet-editor-ratific-d6bf`
- 목업: `petspace-pet-flow-b-mockup.html`
- 목업 SHA-256: `c34893f89c0274adc57ebfad7b15e85b57f374147594fa3afef592113efe7c9f`
- 초안·오케스트레이션: Codex
- 구현자: Codex (2026-07-14 사용자 실행자 변경 승인)
- 독립 구현 리뷰: Claude Opus 4.8 및 Codex
- commit·merge·push·deploy·운영 DB 작업: 금지

## 사용자 승인과 목표

실행자 변경 기록: 비준 뒤 Claude Fable 5가 사용량 한도에서 코드 작성 전에 중단되었다. 사용자는 동일 manifest를 Codex가 구현하고 Claude Opus 4.8이 리뷰하도록 명시적으로 변경 승인했다. 시작 hash와 정확한 앱 코드 manifest는 변경하지 않는다.

사용자는 2026-07-14에 B안 가시 목업을 승인했고, 주요 버튼이 검은색이 아니라 PetSpace 브랜드 액션 색이어야 함을 확인한 뒤 구현 진행을 승인했다. 기존 Wave 1B의 긴 92% 높이 bottom sheet를 최종 형태로 보지 않고 다음 구조로 교체한다.

1. 신규 등록은 하단 탭이 없는 전체 화면 2단계 흐름이다.
2. 1단계는 사진·이름·종류에 집중한다. 이름은 필수이고 사진은 선택이다.
3. 2단계의 품종·성별·생년월일·소개는 모두 선택이며 `건너뛰기`와 `등록 완료`는 같은 유효한 빈 선택 상태를 저장한다.
4. 수정은 하단 탭이 없는 단일 전체 화면 `반려동물 정보`다.
5. 여권 입력은 신규 등록에서 제거하고 수정 화면의 별도 `여권 정보 > 관리` 하위 화면으로 이동한다.
6. 저장 성공 전에는 화면을 닫지 않는다. 실패하면 입력값과 현재 화면을 유지한다.
7. 기능·DB·API 계약은 유지하면서 기존 Presentation의 직접 Supabase 사용자 조회는 새 화면에서 반복하지 않는다.

사용자는 PetSpace의 Claude·Codex 협업 자동화 흐름에 따라 이 작업지시서, 승인 목업, 아래 정확한 구현 파일과 필요한 읽기 전용 의존 코드의 Claude Fable 5 외부 열람·검토·구현을 승인한 것으로 처리한다. `.env`, 키, 토큰, 인증 세션, 운영 데이터와 보호 화면은 전송·탐색 범위에서 제외한다.

## 정확한 앱 코드 manifest

### 수정 3개

1. `pjh/lib/core/navigation/app_router.dart`
   - 시작 SHA-256: `adc034bfeca1c857953c9694afe876e952e2925dce0a121ba345ec1cae220d6d`
2. `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
   - 시작 SHA-256: `8711bc1ed385a2d423da66c10e1c7ef4c2788adb4a0f231d07aa0c0f3629cec0`
3. `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
   - 시작 SHA-256: `ac62d87eb140cd85a62a75060f65c7497001dc309fa4522f009d792ca8cffa4e`

### 생성 2개

4. `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
5. `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`

### 대체 완료 후 삭제 2개

6. `pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart`
   - 시작 SHA-256: `2f50bbaef2185ae6e89069ba438ff6dcff1a0d86c148e901ea5175ca4fee4a1b`
7. `pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart`
   - 시작 SHA-256: `9117b0dd3a070169fc3eab2c33866eaae5b0c3550880983515f2ef407974300d`

이 7개 밖의 앱 코드·테스트를 수정하거나 만들거나 삭제하지 않는다. `pet_editor_form_widgets.dart`는 현재 공개 UI-only 컴포넌트를 읽고 재사용할 수 있으나 수정하지 않는다.

## 읽기 전용 계약과 보호 hash

- `pet_editor_form_widgets.dart`: `219982f735924dda208042390bf3adaa4b70c8942653c26cf6e548cafc307b92`
- `pet_bloc.dart`: `b12d265fa47212a994f543ed03a45514066d038bc54c4333b4ec3a7c2fd9b324`
- `pet.dart`: `4aa99ea8af5f67043ed31fb4cbfecd8c4b4b8523f39de2dfe01d9ce6e95f3312`
- `app_theme.dart`: `54b24735396329a729ba1f5ce7f214908caadd647fcf9f691ae1409e453a02f8`
- `main_navigation.dart`: `bc048d39d03d312a4bfcb117f682dd7282804a699b8a368c383d5dfad1f334cf`
- 실제 홈 `home_page.dart`: `021681acf3f3c6898e2afebe7ba263dfb703bc9bc1728f450605dad369117269`

`pjh/lib/features/home/**`, `pjh/lib/features/emotion/presentation/**`, BLoC·domain·data·Repository·DI·theme·shared widget·DB·migration·법무·secret은 읽기 전용이다. 라우터 외 전역 navigation 구조를 수정하지 않는다.

## 라우팅·상태 계약

1. `app_router.dart`의 `ShellRoute` 밖 fullscreen 영역에 등록과 수정 named route를 추가한다. 경로·이름은 충돌이 없고 테스트에서 안정적으로 찾을 수 있게 명시 상수 또는 고정 문자열로 둔다.
2. 관리·상세 화면에서 새 `PetBloc`을 생성하지 않는다. 현재 Shell이 보유한 동일 `PetBloc` 인스턴스를 typed route data로 전달하고 route builder에서 `BlocProvider.value`로 제공한다.
3. 신규 등록의 userId는 `createRouter(AuthBloc authBloc)`이 이미 보유한 인증 상태에서 전달한다. 새 Presentation 화면이 `Supabase.instance`를 import하거나 조회하면 안 된다.
4. route extra가 없거나 타입·petId가 맞지 않는 비정상 진입은 crash 또는 blank 화면 대신 안전한 오류 화면과 뒤로 가기를 제공한다.
5. `PetEditorPage`는 제출 시 기존 `AddPetEvent` 또는 `UpdatePetEvent`만 dispatch한다. `PetOperationSuccess`를 받은 뒤 한 번만 pop하고, `PetError`에서는 현재 입력과 단계가 유지되며 제출 가능 상태로 돌아간다.
6. 관리 화면의 기존 success/error listener와 목록 갱신 의미를 유지한다.
7. 상세 화면은 수정 성공 뒤 기존 immutable 생성자 pet만 계속 그리지 말고, 같은 pet id의 최신 `PetOperationSuccess.pets` 또는 `PetLoaded.pets`를 반영한다. 삭제 성공 때만 기존처럼 상세를 닫는다.

## 승인된 등록 화면

### 1단계 `기본 정보`

- 상단: 닫기, 중앙 제목 `반려동물 등록`, 단계 `1 / 2`와 절제된 progress
- 사진: 96~104 논리 px 원형 preview, 보이는 `사진 추가` 또는 `사진 변경` 라벨, 선택 사항 안내
- 이름: 기존 50자 제한, 공백 입력 불가, 기존 validator 의미 유지
- 종류: 강아지·고양이 단일 선택, 기본 강아지
- 하단 고정 CTA: `다음`
- 안내: `나머지 정보는 다음 화면이나 등록 후에 추가할 수 있어요.`

### 2단계 `추가 정보`

- 상단: 이전 단계, 중앙 제목, `2 / 2`와 progress
- 품종: 종류별 기존 목록과 `기타` 직접 입력, 종류가 실제로 바뀔 때만 품종 초기화
- 성별: 수컷·암컷 optional 단일 선택
- 생년월일: 기존 1990~현재 범위
- 소개: 기존 description 매핑과 3줄 입력 의미
- 안내: 모든 항목이 선택이며 언제든 수정 가능
- 여권 안내: `여권 정보는 등록 완료 후 반려동물 상세에서 만들 수 있어요.`
- 하단: 낮은 위계의 `건너뛰기`, 강한 `등록 완료`

`건너뛰기`는 입력된 선택값을 강제로 지우는 기능이 아니다. 현재 2단계 입력을 그대로 저장하며, 아무것도 입력하지 않은 상태도 유효하다는 빠른 완료 CTA다.

## 승인된 수정·여권 화면

1. 수정 상단 제목은 `반려동물 정보`다.
2. 사진과 이름을 먼저 보여주고 기본 정보는 이름·종류·품종·생년월일·성별·소개 순서로 정돈한다.
3. 현재 pet 값은 모두 prefill한다. 같은 종류 재탭으로 품종이 지워지지 않는다.
4. 하단 고정 CTA는 `변경사항 저장`이다.
5. 본문 하단에 여권 요약 row와 `관리` 진입을 둔다. passportNo가 있으면 `등록됨 · {countryCode}`, 없으면 사실에 맞는 중립 상태를 쓴다.
6. 여권 관리는 같은 파일 안의 draft 하위 전체 화면으로 구현할 수 있다. 저장 전 원본 Pet/DB를 직접 바꾸지 않고 상위 편집 draft로만 값을 반환한다.
7. 기존 영문 성·영문 이름·여권 표기용 한글 이름·국가 목록, 영문 대문자 formatter, ASCII 영문/공백 허용, 기본 `KOR`, helper 의미를 보존한다.
8. 기존 passportNo는 변경하지 않는다. 신규 번호 생성·재발급·삭제 UI나 DB 의미를 만들지 않는다.

## Pet 매핑·업로드 계약

- 이미지 picker: 기존 `maxWidth: 512`, `maxHeight: 512`, `imageQuality: 70` 유지
- 새 이미지가 있을 때만 기존 `ImageUploadService.uploadPetAvatar(file, petId)` 사용
- 신규 id와 업로드 petId의 기존 밀리초 기반 결정 의미 유지
- 신규 Pet: authBloc에서 받은 userId, name/type/optional fields, now createdAt·updatedAt, passport 입력은 null·국가 KOR
- 수정 Pet: id/userId/createdAt/passportNo뿐 아니라 `currentMbtiType`, `currentMbtiUpdatedAt` 등 편집하지 않는 모든 필드를 보존한다. 수정 가능한 nullable 필드는 UI 값대로 null 또는 새 값으로 매핑한다.
- 이름 trim, 품종 기타 trim, 빈 description/passport 문자열 null 처리 유지
- callback 없이 직접 Repository·Supabase·운영 API를 호출하지 않는다.
- 이미지 선택·업로드 내부 예외 원문 `$e`를 사용자에게 노출하지 않는다. 사용자용 고정 문구를 보여주고 디버그 원문을 화면에 출력하지 않는다.
- 제출 중 중복 탭, 성공 이중 pop, dispose 뒤 setState를 방지한다.

## 시각·접근성 계약

- 주요 CTA/선택 상태: `AppTheme.actionBase` `#3A6EA8`
- pressed overlay/상태: `AppTheme.actionPressed` `#2E5786`
- 라이트 heading: `AppTheme.brandDeep` `#1E3A5F`; 다크에서는 대비되는 theme `onSurface`
- 검은색은 본문 역할색일 수 있으나 primary button fill로 사용하지 않는다.
- 배경·surface·본문·보조·경계는 `Theme.of(context).colorScheme`과 AppTheme 의미 토큰을 사용한다.
- 본문 15~16, 보조 13, 화면 제목 17~20 역할. 의미 없는 과대 타이포·gradient·과한 그림자·장식 이모지 금지
- section 24, field 16, page horizontal 20 전후, radius 8/14 역할 유지
- 모든 icon button, choice, date, passport row, bottom CTA 최소 44×44 논리 px
- SafeArea, 키보드, 320×568, 360×800, text scale 150%, 긴 한국어에서 RenderFlex/overflow가 없어야 한다.
- 화면 읽기 순서와 semantics label이 시각 순서와 일치해야 한다.

## 삭제 전 게이트

기존 `AddPetBottomSheet`와 테스트는 다음이 모두 충족된 뒤에만 삭제한다.

1. 관리 빈 상태·목록 CTA·PetCard 수정·상세 수정 네 진입점이 새 전체 화면으로 연결됨
2. 앱 코드와 테스트에서 `AddPetBottomSheet` 및 파일 import 참조가 0개
3. 새 page widget test 통과
4. analyzer 통과

게이트 전 실패하면 두 파일을 삭제하지 말고 작업을 `blocked`로 보고한다. 구 bottom sheet와 신 page를 동시에 활성 진입점으로 남기지 않는다.

## 자동 테스트와 독립 검증

신규 `pet_editor_page_test.dart`는 실제 네트워크·Supabase·이미지 선택기를 호출하지 않고 최소 다음을 검증한다.

- 등록 1단계 구조, 이름 공백 validator, 다음 단계 전환
- 등록 2단계 선택 안내, `건너뛰기` 및 `등록 완료`의 AddPetEvent 매핑
- 수정 prefill, 같은 종류 재탭 품종 유지, UpdatePetEvent의 미편집 필드 보존
- 여권 관리 진입·draft 반환, 대문자/허용 문자/국가 매핑, passportNo 보존
- 제출 중 중복 dispatch 방지
- PetOperationSuccess 전 미종료, 성공 뒤 단일 pop, PetError 뒤 입력·단계 유지와 재시도 가능
- CTA fill이 `AppTheme.actionBase`이며 검은색이 아님
- 320×568·150% text scale·키보드 viewInsets·다크모드에서 예외/overflow 없음
- 핵심 터치 대상 최소 44px

`pjh/`에서 다음을 실행한다.

```powershell
dart format --output=none --set-exit-if-changed \
  lib/core/navigation/app_router.dart \
  lib/features/pets/presentation/pages/pet_management_page.dart \
  lib/features/pets/presentation/pages/pet_detail_page.dart \
  lib/features/pets/presentation/pages/pet_editor_page.dart \
  test/features/pets/presentation/pages/pet_editor_page_test.dart
flutter analyze --no-pub
flutter test test/features/pets/presentation/pages/pet_editor_page_test.dart
flutter test
git diff --check
```

전체 테스트는 직전 기준 `379 pass / 14 existing failures / 0 new`와 비교하고 신규 실패가 0이어야 한다. 정확한 7경로 외 실행 전후 delta가 없어야 하고 읽기 전용 hash가 모두 일치해야 한다. Claude Fable 5와 Codex가 동일 diff를 각각 독립 리뷰해 blocker/high 0, 양쪽 approve일 때만 완료다.

## 사람 실기기 검증 대기

- 관리 빈 상태·목록·PetCard·상세의 네 진입점과 Android back
- 등록 1→2→이전, 건너뛰기, 저장 성공·실패·중복 탭
- 사진 권한 허용·거부·취소·업로드 실패와 preview
- 수정 직후 상세와 목록 최신값 반영
- 여권 관리 진입·뒤로·draft 저장·최종 저장
- 라이트·다크, 360×800·390×844·큰 화면, 글자 130~150%, 키보드
- TalkBack 읽기 순서·label·터치 영역

## 중단 조건

- manifest 시작 hash 불일치 또는 범위 밖 변경
- 동일 PetBloc 전달이 불가능해 BLoC/domain/data/Repository를 수정해야 함
- DB/API/라우팅 의미·패키지·asset·법무·수의학 문구 변경 필요
- 기존 userId, Pet 필드, passportNo, MBTI 또는 nullable 필드 데이터 손실 가능성
- 비정상 route·저장 오류가 crash/blank/조기 pop을 유발
- Claude Fable 5와 Codex의 manifest·상태·완료 조건·실행자 불일치
- blocker/high, 신규 analyzer/test 실패, 보호 hash 불일치, overflow·접근성 악화

중단 시 자동 채택하거나 범위를 넓히지 말고 쟁점과 최소 선택지만 사용자에게 보고한다.
