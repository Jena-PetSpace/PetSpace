# PetSpace UI/UX 보완 remediation manifest

- 작성일: 2026-07-30
- 기준 HEAD: `02f74e50d645a2e4eb29cb0d4ac735ff40d39445`
- 선행 문서:
  - `docs/work-orders/2026-07-30-approved-uiux-implementation-manifest.md`
  - `docs/work-orders/2026-07-30-post-windows-merge-uiux-plan.md`
- 검토: Codex 독립 확인 + Claude 단계별 재검토

## 1. 목적

기존 Wave 0~4 검증 이후 발견된 항목 중 DB·인증·서버 계약을 바꾸지 않는
국소 UI 보완만 수행한다. 홈과 AI 감정·건강 분석 결과 화면은 계속 동결한다.

## 2. 수동 수정 허용 경로

### Stage A — 인증·대표 반려동물

- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`

허용 변경:

- 카카오 원형 버튼의 semantics·tooltip을 `카카오 로그인`으로 통일한다.
- 원형 58pt, iOS Apple→Google→Kakao 순서, 16pt 간격, Kakao 심볼 30px,
  OAuth 이벤트 연결은 변경하지 않는다.
- 대표 반려동물 변경 전 영향 안내와 확인 단계를 추가한다.
- 대표 반려동물을 삭제하려 할 때 다른 반려동물이 있으면 새 대표 선택을 먼저
  요구한다. 실제 `DeletePetEvent`와 삭제 저장소 계약은 변경하지 않는다.

### Stage B — 지도 복구

- `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
- `pjh/test/features/social/presentation/pages/location_picker_page_test.dart`

허용 변경:

- 지도 platform view 재생성은 최대 2회만 허용하고, 이후 해당 화면 세션을
  리스트 전용으로 고정한다.
- 12초 ready timeout, `ValueKey<int>(_mapViewGeneration)`,
  `onPressed: _recreateMapView`, REST 검색·선택·완료 흐름은 보존한다.

### Stage C — 설정·문서 정합

- `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`
- `docs/work-orders/2026-07-30-post-windows-merge-uiux-plan.md`

허용 변경:

- 기존 앱 정보 다이얼로그 안에 Flutter 오픈소스 라이선스 진입점을 추가한다.
  신규 라우트나 화면 파일은 만들지 않는다.
- 실제 완료 Wave와 사용자 승인 이력을 문서에 반영한다.

## 3. 별도 승인 전 변경 금지 계약

- 펫 삭제: 현재 `public.pets` 물리 삭제, `health_records`,
  `emotion_history`, `pet_mbti_results` cascade, `posts`와 `walk_records`
  연결 해제 계약을 유지할지 30일 비활성화로 전환할지
- 인증: 세션 만료 시 조용한 1회 갱신과 인증 만료 상태의 신호 지점
- 위치: 정확 좌표 저장과 공개 시·군·구 상한의 서버·표시 계층 계약
- AI 기록: 분석 원본·파생 썸네일 삭제 뒤 `imageUrl` 보존 여부

위 항목은 Supabase FK·Storage·개인정보 파기·인증 인터셉터·조회 응답을
별도 manifest에서 검토하기 전 코드와 SQL을 수정하지 않는다.

## 4. 단계별 검증

각 Stage마다 아래를 실행하고 Claude에 해당 Stage의 정확한 변경 파일만
재검토한다.

```bash
dart format --output=none --set-exit-if-changed <변경 Dart 파일>
git diff --check
flutter analyze --no-pub
flutter test --no-pub <명시된 개별 테스트 파일>
dart run tool/verify_uiux_scope.dart
```

모든 Stage 종료 후 전체 `flutter test --no-pub`,
`flutter build ios --release --no-codesign --no-pub`, iOS 시뮬레이터 확인,
Codex read-only diff 리뷰를 수행한다.

## 5. 중단 조건

- 이 문서 밖 수동 코드 수정이 필요한 경우
- 홈 또는 AI 결과 동결 파일 변경이 필요한 경우
- Apple/OAuth, K1/H2, `auth.uid()`, iPad `shareOrigin` 계약 변경이 필요한 경우
- 별도 승인 대상 계약을 임의로 변경해야 하는 경우
- 비밀 파일 노출 또는 신규 analyze/test/build 실패가 발생하는 경우

원격 push, 운영 DB/RPC, Edge, APNs, signing, TestFlight, 배포는 수행하지
않는다.
