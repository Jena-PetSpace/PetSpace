# 2026-07-30 iOS Simulator UI/UX 검증 보고서

## 검증 범위와 방법

- 기기: iPhone 17 Simulator, iOS 26.4
- Home 및 AI 분석 결과 상세 화면은 이번 검토·수정 범위에서 제외했다.
- 로그인·회원가입·비밀번호 재설정 화면은 실제 앱을 직접 조작해 확인했다.
- 로그인 이후 화면은 운영 데이터나 원격 계정을 변경하지 않도록 실제 production 위젯에 테스트 상태를 주입해 iOS Simulator에서 렌더링하고 상호작용했다.
- 캡처 전용 임시 테스트 코드는 검증 완료 후 삭제했다.
- 비밀번호 재설정 메일 발송, OAuth 로그인, 대표 반려동물 원격 변경·삭제 등 실제 서버 쓰기는 실행하지 않았다.

## 검증 결과

- 로그인/회원가입 전환 및 원형 Apple·Google·Kakao 버튼: 정상
- 비밀번호 재설정 이메일 형식 검증: 정상
  - 빈 값: CTA 비활성
  - 잘못된 이메일: 오류 문구 및 CTA 비활성
  - 올바른 이메일: CTA 활성
- 반려동물 목록·대표 변경 확인·대표 삭제 보호 대화상자: 기능 상태 정상
- 설정 상단·하단 및 앱 정보·라이선스 진입: 기능 상태 정상
- 위치 지도 실패→목록 전환→재시도 소진→검색 결과: 기능 상태 정상
- 캡처용 iOS integration 시나리오 3개: 모두 통과
- 기존 구현 검증 기준: `flutter analyze` 통과, 전체 테스트 975개 통과, iOS release no-codesign build 통과

## 캡처 목록

| 번호 | 화면/상태 | 파일 |
|---:|---|---|
| 01 | 회원가입 | [01-signup.png](01-signup.png) |
| 02 | 로그인 | [02-login.png](02-login.png) |
| 03 | 비밀번호 재설정 초기 | [03-password-reset-initial.png](03-password-reset-initial.png) |
| 04 | 비밀번호 재설정 잘못된 이메일 | [04-password-reset-invalid.png](04-password-reset-invalid.png) |
| 05 | 비밀번호 재설정 올바른 이메일 | [05-password-reset-valid.png](05-password-reset-valid.png) |
| 06 | 반려동물 관리 | [06-pet-management.png](06-pet-management.png) |
| 07 | 대표 반려동물 변경 확인 | [07-pet-primary-confirm.png](07-pet-primary-confirm.png) |
| 08 | 대표 반려동물 삭제 보호 | [08-pet-primary-delete-gate.png](08-pet-primary-delete-gate.png) |
| 09 | 설정 상단 | [09-settings-top.png](09-settings-top.png) |
| 10 | 설정 하단 | [10-settings-bottom.png](10-settings-bottom.png) |
| 11 | 앱 정보 | [11-app-info.png](11-app-info.png) |
| 12 | 오픈소스 라이선스 | [12-license-page.png](12-license-page.png) |
| 13 | 위치 지도 실패·목록 전환 | [13-location-list-only.png](13-location-list-only.png) |
| 14 | 위치 지도 재시도 소진 | [14-location-retry-exhausted.png](14-location-retry-exhausted.png) |
| 15 | 위치 검색 결과 | [15-location-search-results.png](15-location-search-results.png) |

## UI/UX 리뷰

### P1 — 다음 구현 묶음에서 우선 수정

1. 앱 정보·라이선스의 브랜드 및 한국어 일관성
   - `View licenses`, `Close`, `Licenses`, `Powered by Flutter`가 영문 기본 UI로 노출된다.
   - 앱 정보 대화상자의 빈 공간이 크고 PetSpace의 디자인 시스템과 동떨어져 앱 신뢰도를 낮춘다.
   - 한국어 기반의 간결한 브랜드 앱 정보 화면과 `오픈소스 라이선스`, `닫기` 액션으로 정리한다.
   - 예상 대상:
     - `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
     - `pjh/lib/features/my/presentation/widgets/settings_bottom_sheet.dart`
     - `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`

2. 대표 반려동물 대화상자 문장과 행동 구조
   - `호두을(를)`은 자연스럽지 않다. 조사 없는 문장으로 변경한다.
   - 삭제 보호 제목이 세 줄로 끊기며 마지막 `요`가 고립된다.
   - 단순 `확인`보다 `반려동물 선택`을 주 행동으로 제공해 다음 행동을 바로 이해할 수 있게 한다.
   - 예상 대상:
     - `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
     - `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`

3. 위치 지도 실패 시 화면 재배치
   - 지도 사용이 끝난 목록 전용 상태에서도 빈 지도 영역이 화면 상단 절반 가까이 남는다.
   - 검색 결과가 아래로 밀려 목록 전환의 효율이 낮고, 화면이 고장 난 듯 보일 수 있다.
   - 목록 전용 상태에서는 지도 영역을 접고 검색·결과를 상단으로 올린다.
   - 재시도 안내 배지는 짧게 바꾸고 상세 이유는 보조 문구로 분리한다.
   - 예상 대상:
     - `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
     - `pjh/test/features/social/presentation/pages/location_picker_page_test.dart`

### P2 — P1 이후 다듬기

1. 인증 화면의 세로 균형
   - 큰 화면에서 소셜 로그인 아래 빈 공간이 길다.
   - 핵심 폼의 접근성을 해치지 않는 범위에서 상단/폼/소셜 영역 간격을 반응형으로 조정한다.
   - Apple·Google·Kakao 아이콘의 실제 크기보다 시각적 크기가 달라 보이므로 optical size를 맞춘다.
   - 대상:
     - `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
     - `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`

2. 설정 스크롤 전환
   - 내용 계층과 위험 영역 구분은 좋다.
   - 하단으로 스크롤할 때 고정 앱바 아래에서 행이 잘리는 경계가 다소 거칠다.
   - 얇은 divider 또는 미세한 elevation으로 고정 헤더와 콘텐츠의 깊이를 구분한다.

3. 위치 결과 카드의 선택 피드백
   - 검색 결과 정보 구조는 명확하다.
   - 결과 선택 전 `완료`가 비활성인 이유가 약하므로, 선택 시 카드 배경·테두리·체크 표시와 `완료` 활성 전환을 함께 검증한다.

## 유지할 장점

- 인증 화면의 단일 배경과 입력·CTA 구조가 일관적이다.
- 원형 소셜 로그인 버튼의 순서와 접근성 라벨이 명확하다.
- 반려동물 목록은 대표/다른 반려동물 계층이 명확하고 카드 정보 밀도가 적절하다.
- 설정은 일반·지원·위험 영역 구분과 터치 목표 크기가 안정적이다.
- 위치 권한 거부와 지도 실패에도 검색으로 작업을 계속할 수 있다.

## 다음 작업 순서

1. 위 P1 세 묶음의 문구·화면 구조를 사용자와 확정한다.
2. Home 및 AI 분석 결과 상세를 건드리지 않는 정확한 수정 manifest를 만든다.
3. P1 구현 후 관련 개별 테스트를 먼저 실행한다.
4. `flutter analyze --no-pub` 및 전체 `flutter test --no-pub`를 실행한다.
5. iPhone 17 Simulator에서 같은 15개 상태를 다시 캡처해 전후 비교한다.
6. OAuth, 비밀번호 재설정 메일, 반려동물 변경·삭제, 위치 선택 저장은 별도 QA 계정으로 백엔드 E2E 검증한다.
7. P1 결과 승인 후 P2를 별도 묶음으로 구현한다.

## 별도 합의가 필요한 기능 계약

- 반려동물 삭제를 즉시 삭제로 유지할지 30일 비활성화로 바꿀지
- 인증 만료 시 silent refresh 정책
- 위치 저장 단위를 정확 좌표로 할지 시·군·구 공개 단위로 할지
- AI 분석 이미지 삭제 시 원본·썸네일을 함께 제거할지

이 네 항목은 UI 수정과 섞지 않고 데이터·보안 계약으로 별도 기획한다.
