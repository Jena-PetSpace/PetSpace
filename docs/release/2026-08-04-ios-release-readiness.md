# PetSpace iOS 출시 준비 현황

기준일: 2026-08-04
기준 브랜치: `mac-ios-release`
기준 커밋: `ac9599637ac7eff0d89a71a3bab58120c0547b80`
앱 버전: `1.0.0+4`

## 범위와 금지 사항

이 문서는 App Store 제출 전 로컬 준비 상태를 기록한다. App Store Connect
제출, TestFlight 업로드, signing 자산 생성·변경, 운영 DB·RPC·Edge Function,
APNs·Firebase 콘솔 변경은 수행하지 않았다. 비밀 설정과
`GoogleService-Info.plist`는 존재 여부만 확인했고 내용·해시·크기를 기록하지
않았다.

## 로컬 검증 결과

| 항목 | 결과 | 근거 |
|---|---|---|
| release preflight | PASS | `BLOCKERS=0`, App Store URL 경고 1건과 수동 게이트만 남음 |
| preflight 계약 테스트 | PASS | 9개 테스트 통과 |
| plist·entitlement·Privacy Manifest 문법 | PASS | `plutil -lint` 통과 |
| AppIcon manifest | PASS | JSON 정상, 25개 슬롯이 참조하는 21개 고유 PNG 누락 0 |
| App Store 1024 아이콘 | PASS | 1024×1024, alpha 없음 |
| iOS release 빌드 | PASS | `Runner.app` 91.8MB, codesign 비활성 |
| iOS archive | PASS | `Runner.xcarchive` 294.5MB, IPA export는 codesign 미구성으로 생략 |
| archive 정합성 | PASS | `com.jena.petspace`, `1.0.0(4)`, iOS 16.0 |
| Apple SDK 요구 | PASS | Xcode 26.4, iOS SDK 26.4 |
| privacy manifest 포함 | PASS | 앱·SDK 포함 archive 내 39개 확인 |
| dSYM | PASS | Runner dSYM 포함 |
| 로컬 민감 설정 | PASS | 앱 검증 설정과 iOS Firebase 설정 파일 존재 여부만 확인 |
| 원격 동기화 | PASS | 로컬 HEAD와 `origin/mac-ios-release` 일치 |

실행 명령:

```bash
cd pjh
dart run tool/release_preflight.dart
flutter test --no-pub test/tool/release_preflight_test.dart
plutil -lint ios/Runner/Info.plist \
  ios/Runner/Runner.entitlements \
  ios/Runner/RunnerDebug.entitlements \
  ios/Runner/PrivacyInfo.xcprivacy
flutter build ios --release --no-codesign --no-pub
flutter build ipa --release --no-codesign --no-pub
```

## 제출 전 차단 항목

### P0 — 반드시 해결

1. **공개 법적·지원 URL**
   - `https://petspace.app/privacy`, `/terms`, `/support`는 HTTP 200이지만
     모두 동일한 `/lander` 주차 페이지로 이동한다.
   - 실제 개인정보처리방침, 이용약관, 고객지원 페이지를 배포하고
     로그아웃·시크릿 브라우저에서 본문과 연락처를 확인해야 한다.
2. **서명 환경**
   - 이 Mac에서 유효한 iOS codesigning identity와 provisioning profile이
     확인되지 않았다.
   - Apple Developer 멤버십, App ID `com.jena.petspace`, Sign in with
     Apple·Push Notifications capability, 배포 인증서·프로파일 또는 Xcode
     자동 서명을 설정해야 한다.
3. **계정 삭제 운영 계약**
   - Apple revoke secret 4종, 검토된 탈퇴 Edge Function, L1/L2 migration,
     purge secret·일별 작업·실패 알림을 운영에서 활성화하고 실계정으로
     검증해야 한다.
4. **App Store Connect 개인정보 답변**
   - 정확한 위치, 이메일·사용자 ID, 사진·사용자 콘텐츠, FCM 토큰,
     Analytics·Crashlytics·Performance와 Google AI 처리 흐름을 앱·SDK의
     실제 동작에 맞춰 확정해야 한다.

### P1 — build 선택 전 해결

1. Firebase Console에 APNs 인증 키가 연결되었는지 확인한다.
2. 실제 iPhone에서 foreground/background/terminated push를 검증한다.
3. Apple·Google·Kakao 로그인, Apple 비공개 이메일 릴레이와 Apple 계정
   탈퇴/revoke를 실제 계정으로 검증한다.
4. 로그인 완료 QA 계정과 반려동물·분석·게시글·채팅 샘플 데이터를 준비한다.
5. iPhone·iPad의 회전, Split View, 권한 거부·복구, Dynamic Type 200%,
   VoiceOver를 검증한다.
6. 서명 archive의 SDK Privacy Manifest와 signature 경고를 Xcode Organizer에서
   최종 확인한다.
7. 서비스 알림과 선택적 마케팅 알림의 동의·철회 정책을 확정한다.
8. App Store Connect에서 앱 레코드를 생성한 뒤 숫자 Apple ID를 앱의
   App Store URL에 반영한다.

## 현재 Apple 제출 기준 대조

- 2026-04-28 이후 iOS/iPadOS 앱은 iOS 26 SDK 이상으로 빌드해야 한다.
  현재 Xcode 26.4와 iOS SDK 26.4이므로 로컬 도구 체인은 충족한다.
- iOS 앱은 공개 개인정보처리방침 URL이 필수이며, 앱과 모든 통합 제3자
  SDK의 데이터 수집을 App Store Connect 개인정보 답변에 포함해야 한다.
- 스크린샷은 기기군·언어별 1~10개를 제출할 수 있다. universal target이므로
  iPhone과 iPad 화면을 실제 제출 build 기준으로 준비한다.
- 계정을 만드는 앱은 앱 안에서 전체 계정 삭제를 시작할 수 있어야 한다.
  Sign in with Apple 계정 삭제 시 Apple token revoke도 수행해야 한다.

공식 근거:

- https://developer.apple.com/news/?id=ueeok6yw
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- https://developer.apple.com/support/offering-account-deletion-in-your-app

## 역할 분담과 권장 순서

### Codex가 진행할 수 있는 작업

1. 공개 법적 페이지 배포본과 앱 내부 정본의 문구 차이 검토
2. App Store 메타데이터·개인정보 답변·심사 메모 초안 정리
3. 서명 설정 후 archive 정합성·SDK Privacy Manifest·dSYM 재검증
4. QA 계정과 실기기가 준비되면 OAuth·푸시·탈퇴·UGC·접근성 회귀 수행
5. 최종 스크린샷 규격·개인정보 제거·build UI 일치 검수

### 사용자가 직접 확인하거나 승인할 작업

1. 개인정보처리방침·이용약관의 법적 최종 문구와 공개 도메인 배포
2. Apple Developer 계약·멤버십·App ID capability·서명 자산 설정
3. Apple revoke·Firebase APNs·Kakao Developers의 비밀값과 콘솔 연결
4. 운영 migration·Edge·cron 배포 승인과 실제 QA 계정 제공
5. App Store Connect 앱 생성, 연령 등급·판매 지역·가격·개인정보 답변 승인
6. TestFlight 업로드와 최종 심사 제출

권장 실행 순서는 공개 URL 배포 → Apple 서명·capability → 운영 탈퇴 계약과
APNs → 실기기 QA → App Store Connect 레코드·메타데이터 → 서명 archive →
TestFlight → 최종 심사 순이다.
