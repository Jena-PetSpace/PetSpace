# 홈 광고 슬롯·출시 정책 후속 작업지시서

기준일: 2026-08-11
기준 브랜치: `mac-ios-release`
사용자 승인: 홈 배너 준비, 플레이스 위치 흐름 유지, 자체 AI 출시 전 도입 예정,
공식 지원 이메일 확정

## 목표

출시 앱에 미완성 광고 플레이스홀더를 노출하지 않으면서 광고 공급자 연결을
위한 홈 슬롯을 보존한다. 플레이스와 자체 AI의 데이터 흐름은 현재 구현과
예정 기능을 구분해 법적 문서·App Store 개인정보 답변에 반영한다.

## 이번 구현 범위

1. 홈의 `광고 · 공지 배너 영역` 플레이스홀더 제거
2. 실제 플레이스로 이동하는 펫페이스 내부 추천 배너 제공
3. 배너 전체 탭 영역, 접근성 라벨, 200% 글자 크기 안전성 보장
4. 외부 광고 SDK, AdMob ID, IDFA, ATT는 미도입
5. 공식 지원 이메일을 앱 설정·법적 문서·테스트에서 통일
6. 사용자 승인 홈 변경에 맞춰 보호 SHA snapshot만 새 기준으로 갱신

## 데이터 흐름 판정

### 광고

현재 build에는 광고 SDK가 없다. 내부 추천 배너를 제3자 광고나 유료 광고로
표시하지 않는다. 광고 공급자 연결은 다음 결정 후 별도 작업으로 수행한다.

- 광고 공급자
- 맞춤형 광고 사용 여부
- 출시 국가
- 동의 관리 플랫폼과 개인정보 옵션 재진입 화면
- App Store 개인정보 답변과 Privacy Manifest 갱신

### 플레이스

- 현재 위치: 주변 장소 검색 기준으로 Kakao Local/Map 경로에서 처리
- 장소 공유: 장소명, 주소, Kakao 장소 링크를 시스템 공유 시트로 전달
- 사용자 실시간 위치: 다른 사용자에게 공유하지 않음
- 게시물 장소: 사용자가 게시글에 선택하면 장소 좌표가 게시물 데이터에 저장
- 산책 경로: 사용자 본인 데이터로 저장하고 RLS로 보호

### 자체 AI

자체 AI는 예정 기능이며 현재 build의 완료된 데이터 처리로 간주하지 않는다.
입력 데이터, 추론·학습 구분, 명시적 동의, 보유기간, 삭제·탈퇴 처리,
모델·인프라 운영 위치가 확정되고 구현·테스트되기 전에는 공개 정책에 완료
기능으로 기재하지 않는다.

## 변경 허용 파일

- `docs/legal/location_terms_v5.md`
- `docs/legal/privacy_policy_v6.md`
- `docs/release/2026-08-09-ios-step-1-action-matrix.md`
- `docs/work-orders/2026-08-11-home-ad-slot-and-release-policy.md`
- `pjh/lib/config/app_config.dart`
- `pjh/lib/features/home/presentation/widgets/home_ad_banner.dart`
- `pjh/lib/features/social/presentation/pages/home_page.dart`
- `pjh/test/contracts/uiux_scope_boundary_contract_test.dart`
- `pjh/test/features/home/presentation/widgets/home_ad_banner_test.dart`
- `pjh/test/features/profile/presentation/pages/community_guidelines_page_test.dart`
- `pjh/tool/uiux_frozen_scope.sha256`
- `pjh/tool/uiux_protected_scope.sha256`

## 검증 명령

```bash
cd pjh
dart format --output=none --set-exit-if-changed \
  lib/config/app_config.dart \
  lib/features/home/presentation/widgets/home_ad_banner.dart \
  lib/features/social/presentation/pages/home_page.dart \
  test/contracts/uiux_scope_boundary_contract_test.dart \
  test/features/home/presentation/widgets/home_ad_banner_test.dart \
  test/features/profile/presentation/pages/community_guidelines_page_test.dart
flutter analyze --no-pub --fatal-infos
flutter test --no-pub \
  test/features/home/presentation/widgets/home_ad_banner_test.dart \
  test/features/home/presentation/widgets/home_quick_actions_test.dart \
  test/features/profile/presentation/pages/community_guidelines_page_test.dart
flutter test --no-pub test/contracts/uiux_scope_boundary_contract_test.dart
dart run tool/release_preflight.dart
git diff --check
```

## 시뮬레이터 검증 기준

- 주 검증 기기: `iPhone 17`, iOS 26.4
- 실행 방식: 기기 ID를 명시해 iPad 자동 선택을 방지
- 2026-08-11 결과: 현재 변경본 설치·실행과 로그인 화면 렌더링 확인
- 홈 배너 실화면: iPhone 17에 인증 세션이 없어 로그인 이후 검증 대기
- 인증 우회와 개인 계정 임의 로그인은 금지
- iPad는 universal target을 유지하는 동안 App Store 호환성 확인을 위한
  부 검증 기기이며, iPhone 검증을 대체하지 않는다.

## 중단 조건

- 광고 SDK·IDFA·ATT가 승인 없이 추가됨
- 플레이스 장소 공유를 사용자 실시간 위치 공유로 오인해 구현·고지함
- 자체 AI가 데이터 계약·동의 없이 사용자 콘텐츠를 학습에 사용함
- Home 외 보호 파일 또는 AI 결과 화면이 변경됨
- 지원 이메일 외 비밀값·Firebase 설정·서명 자산이 diff에 포함됨
