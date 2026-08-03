# W1 인증·온보딩·설정·알림 3회 검토

기준일: 2026-08-03
대상 브랜치: `mac-ios-release`
기준 HEAD: `8b275f17c13c58a055553660d0accc537cb9974e`
상태: 기획·목업 완료, 사용자 선택 전 구현 금지

## 결론

현재 기능 계약은 W1 지정 테스트 15개 파일, 64건에서 모두 통과했다.
로그인의 승인된 한 화면 구조와 원형 Apple·Google·Kakao 버튼은 보존한다.
이번 W1의 핵심은 인증 기능을 다시 만드는 것이 아니라 다음 세 가지다.

1. iPad의 과도한 빈 공간과 인증 입력 피드백을 정돈한다.
2. 설정을 큰 아이콘 카드 모음에서 컴팩트 그룹 목록으로 낮춘다.
3. 가입 후 7단계 설명 흐름을 필수 4단계와 첫 사용 맥락형 도움말로 나눈다.

권고 조합은 `인증 A + 설정/알림 A + 온보딩 A`다.

## W0 현행 기준

- iPhone 로그인·회원가입·비밀번호 찾기 현행 캡처를 재검토했다.
- 실행 중인 iPad mini (A17 Pro), iOS 26.4 Simulator에서 로그인 화면의
  접근성 트리와 가로 UI를 다시 확인했다.
- iPad에서는 폼 최대 너비가 안정적이지만 전체 높이에 비해 상단에 몰리고
  하단 대부분이 비어 보여 제품 완성도가 낮아 보인다.
- 실제 OAuth, OTP 메일, 알림 수신, 서버 쓰기는 실행하지 않았다.
- QA 계정·운영 DB·Edge·APNs·signing·스토어 제출은 변경하지 않았다.

## 1차 검토 — 정보 구조·사용자 여정

### 유지할 점

- 로그인/회원가입이 별도 페이지가 아니라 한 화면 전환이어서 재입력이 적다.
- 아이디 찾기, 비밀번호 찾기, 소셜 로그인이 첫 화면에서 모두 발견된다.
- 비밀번호 찾기는 이메일 형식이 맞을 때만 CTA가 활성화된다.
- OTP는 계정 존재 여부를 공개하지 않고 신규 계정 생성을 막는다.
- 약관은 필수와 선택을 분리하고 저장 실패 시 선택 상태를 유지한다.
- 알림 설정은 로컬 캐시를 먼저 표시하고 서버 값으로 정본화한다.
- 알림 저장 실패 시 이전 상태로 되돌리고 내부 오류를 노출하지 않는다.

### 개선할 점

- `onboarding_page.dart`와 `onboarding_slides_page.dart`는 라우터에서 로그인으로
  우회되지만 코드와 테스트에는 남아 있어 실제 가입 여정과 문서상의 여정을
  혼동시킨다. 구현 때 삭제 여부를 별도 diff로 확정한다.
- 이메일 가입 후 인증 → 재로그인 → 약관 → 프로필 → 반려동물 → 다단계
  튜토리얼 → 완료는 첫 가치 도달까지 길다.
- 설정은 `내 활동`, `계정`, `정보`, `계정 관리` 구분은 맞지만 한 행의 장식
  비중이 커서 실제 메뉴 수보다 복잡하게 느껴진다.
- 알림 화면은 기기 권한과 앱 내부 선택을 설명으로 구분하지만, 사용자가 한눈에
  두 상태를 비교할 수 있는 고정 상태 행이 더 명확하다.

## 2차 검토 — 시각·인터랙션·접근성

### 인증

- iPhone 단일 배경과 CTA 위계는 보존 가치가 높다.
- 현재 비밀번호 필드에는 보기/숨기기 동작이 없어 오타 복구 비용이 크다.
- iPad 가로에서는 480pt 제한만으로는 수직 균형이 해결되지 않는다. 콘텐츠를
  화면 중앙에 가깝게 배치하되 키보드가 나타나면 자연스럽게 스크롤해야 한다.
- Apple/Google/Kakao 58pt 원형과 접근성 라벨은 유지한다.
- 입력 오류는 SnackBar가 아니라 해당 입력칸 바로 아래에 유지한다.

### 설정·알림

- 현재 36pt 색상 아이콘 타일과 56pt 행은 각각은 접근 가능하지만, 메뉴가
  연속될 때 카드와 아이콘 박스가 중첩돼 정보보다 장식이 먼저 보인다.
- 권고안은 52~56pt 행, 20~24pt 선형 아이콘, 얇은 행 구분선, 섹션 간 20~24pt다.
- 고정 앱바 아래에는 1px 구분선 또는 아주 약한 elevation 중 하나만 사용한다.
- 로그아웃·회원탈퇴는 아이콘 배경 없이도 빨간 텍스트와 별도 섹션으로 충분히
  위험도를 전달할 수 있다.
- 모든 스위치와 행은 최소 44pt 터치, Dynamic Type 200%, 다크 모드를 유지한다.

## 3차 검토 — 기능·백엔드·신뢰성

- 이메일 검증은 공통 `AuthInputValidators`를 유지한다.
- 비밀번호는 영문·숫자 포함 8자 이상, 최대 72자 계약을 유지한다.
- Apple/Google/Kakao 버튼은 기존 BLoC 이벤트와 중복 요청 잠금을 유지한다.
- 비밀번호 재설정은 `shouldCreateUser: false`와 계정 존재 비공개를 유지한다.
- 알림의 서버 컬럼 `enabled_push`, `enabled_like`, `enabled_comment`,
  `enabled_follow`, `enabled_mention`, `enabled_system`은 변경하지 않는다.
- 현재 비정본 `notification_chat` 캐시는 삭제하거나 서버 컬럼으로 가장해
  표시하지 않는다.
- 시스템 권한 거부 상태에서는 앱 설정을 잃지 않고 시스템 설정 이동과 복귀 후
  재확인을 유지한다.
- 로그아웃·회원탈퇴 진행 잠금, 30일 복구 문구, 정확한 `탈퇴` 입력 계약을 유지한다.
- FCM/realtime의 알림 제목·본문·payload release 로그 제거는 W1 시각 구현과
  분리한 출시 P0 보안 작업으로 관리한다.

## 사용자 선택이 필요한 목업

### W1-A 인증 진입

- `A · 단일 흐름 정돈` — 권고
- `B · 브랜드 패널 강조` — 비권고. 배경 분절을 다시 만들 가능성이 있다.
- 목업: `docs/mockups/2026-08-03-w1-auth-settings/A-auth-entry-ab-v1.png`

### W1-B 설정·알림

- 설정 `A · 컴팩트 그룹형` — 권고
- 설정 `B · 브랜드 카드형`
- 알림 `A · 권한과 앱 설정 분리` — 권고
- 알림 `B · 설명 카드형`
- 목업: `docs/mockups/2026-08-03-w1-auth-settings/B-settings-notifications-ab-v1.png`

### W1-C 가입 후 온보딩

- `A · 필수만 먼저` — 권고
- `B · 전체 안내 유지`
- 목업: `docs/mockups/2026-08-03-w1-auth-settings/C-post-signup-onboarding-ab-v1.png`

## 승인 후 예상 구현 파일

아래는 권고 조합 A/A/A 승인 시의 최대 수동 수정 후보이며, 구현 전 실제 diff
manifest를 다시 고정한다.

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_slides_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart`
- `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
- `pjh/lib/shared/widgets/petspace_settings_components.dart`

## 관련 테스트 정본

- `pjh/test/core/navigation/settings_routes_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_email_verification_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_profile_setup_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_pet_registration_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_complete_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_detail_page_test.dart`
- `pjh/test/features/auth/presentation/pages/kakao_consent_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart`
- `pjh/test/shared/widgets/petspace_settings_components_test.dart`

## 승인 게이트

사용자는 다음 세 항목을 선택한다.

1. 인증: `A` 또는 `B`
2. 설정·알림: 각각 `A` 또는 `B`
3. 가입 후 온보딩: `A` 또는 `B`

선택 전에는 Flutter UI·라우트·테스트 코드를 수정하지 않는다. 승인 후에도 Home과
AI 분석 결과 페이지는 W1 diff에서 제외한다.
