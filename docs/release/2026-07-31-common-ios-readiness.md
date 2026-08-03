# PetSpace 공통·iOS 출시 준비 기준서

기준일: 2026-07-31
기준 브랜치: `mac-ios-release`
앱 버전 정본: `pjh/pubspec.yaml`의 `1.0.0+4`

## 이번 준비 범위

- iOS와 Android가 공유하는 메타데이터·개인정보·운영 검토
- iOS 로컬 프로젝트 구성과 App Store 제출 전 점검
- 홈 화면과 AI 분석 결과 화면의 UI·기능 변경 제외
- Android 빌드·서명·Play Console 작업 제외
- App Store 제출, signing 자산 변경, APNs 콘솔 변경, 운영 DB·Edge 배포 제외

## 현재 판정

### 로컬에서 확인된 준비 완료 항목

- iOS bundle ID: `com.jena.petspace`
- 표시 이름: `펫페이스`
- iOS 최소 버전: 16.0
- Sign in with Apple entitlement
- Release/Debug APNs entitlement 분리
- Background remote notification mode
- 카메라·사진·마이크·위치 사용 목적 문구
- 수출 규정 키 `ITSAppUsesNonExemptEncryption=false`
- iPhone·iPad universal target
- 앱 내부 개인정보처리방침·이용약관
- 앱 내부 회원탈퇴 진입점과 30일 soft-delete 안내
- UGC 신고·차단·커뮤니티 가이드라인 기능
- 피드·댓글·커뮤니티 글 작성의 공용 클라이언트 콘텐츠 필터
- `AppConfig` 버전·빌드 `1.0.0+4` 동기화
- Android 실제 application ID `com.jena.petspace`와 Play Store URL 정합성
- UserDefaults·파일 타임스탬프·디스크 공간·부팅 시간 required-reason API 선언
- 게시물 좌표 흐름에 맞춘 연결된 정확한 위치 선언과 iOS 사용 목적 문구
- Apple 계정 탈퇴의 iOS 재인증 → ID token/identity/nonce 검증 →
  refresh token revoke 로컬 구현
- Apple revoke 성공 후 30일 soft delete를 먼저 기록하고, 전역 sign-out
  실패 시에도 L2 restrictive RLS가 기존 토큰의 사용자 데이터 접근을 차단
- 30일 purge의 Storage 페이지네이션, health-history cascade, 발신 알림
  삭제, 채팅방 마지막 메시지 스냅샷 제거, 멱등 재시도 계약
- 위치 이용·제공사실 확인자료의 좌표 미포함·6개월 법정 보존 예외와
  앱 내 개인정보처리방침·위치약관 문구 정합성, 6개월 만료 삭제 로직

### 제출 전 차단 항목

| 우선순위 | 항목 | 근거 | 해결 주체 |
|---|---|---|---|
| P0 | 탈퇴 운영 계약 활성화 | L1/L2 migration, 두 Edge 함수, Apple secret 4종, purge secret, 일별 cron과 실패 알림은 로컬 준비만 완료 | 사용자 운영 승인 + Codex 적용·실계정 검증 지원 |
| P0 | Apple revoke 운영 설정·실계정 검증 | 로컬 구현은 완료. Apple key 기반 Edge secret 4종, 운영 배포, 실제 Apple 계정 검증은 로컬에서 증명할 수 없음 | 사용자 운영 승인·키 설정 + Codex 배포/검증 지원 |
| P0 | 정확 위치 스토어 개인정보 답변 확정 | 로컬 iOS manifest·사용 목적 문구는 수정 완료. App Store Privacy와 Play Data safety 답변 및 법률 문구는 같은 사실로 확정해야 함 | 사용자 개인정보 답변·법적 확인 |
| P0 | 공개 개인정보처리방침·이용약관·지원 URL 운영 확인 | App Store 심사에서 접근 가능한 URL 필요 | 사용자 도메인·게시 승인 |
| P0 | App Store Connect 개인정보 답변 확정 | Firebase·Supabase·Google AI·위치·UGC 데이터 흐름 포함 | 사용자 최종 법적 확인 |
| P1 | Firebase APNs 키와 실기기 푸시 | 로컬 entitlement만으로는 콘솔·실기기 상태를 증명하지 못함 | 사용자 콘솔 + Codex 실기기 검증 |
| P1 | iPad 스크린샷·레이아웃 검증 | target이 iPhone·iPad를 모두 지원 | 사용자 캡처 승인 + Codex 검증 |
| P1 | App Review 데모 계정 | 로그인 앱은 심사자가 전체 기능을 확인할 수 있어야 함 | 사용자 QA 계정 제공 |
| P1 | IDFA/추적 문구 정합성 | manifest는 tracking=false, 개인정보처리방침은 IDFA 수집 가능성을 기재 | 사용자 정책 결정 + Codex 문서 동기화 |
| P1 | 서명 archive의 SDK Privacy Manifest 점검 | 로컬 소스만으로 포함 SDK의 최종 manifest·signature를 증명할 수 없음 | Codex 점검 + 사용자 signing 승인 |
| P1 | Apple 비공개 이메일 릴레이 | 발신자 등록과 실제 Apple 계정 메일 수신 확인 필요 | 사용자 콘솔 + Codex 실계정 검증 |
| P1 | 마케팅 푸시 동의 분리 | 서비스 알림과 선택적 마케팅 알림의 동의·철회 경로를 운영 정책과 대조해야 함 | 사용자 정책 결정 + Codex 구현 검토 |
| P1 | Kakao Maps 릴리스 키·지도 정상 표시 | 목록 폴백은 검증했지만 릴리스 번들 ID에 연결된 Native App Key와 정상 지도 표시는 서명 빌드·콘솔 확인이 필요 | 사용자 Kakao Developers 확인 + Codex 실기기 검증 |

## Claude 교차 검토 후 Codex 코드 대조

Claude 검토 의견을 그대로 채택하지 않고 현재 소스와 문서에 대조했다.

- required-reason API 4종은 이미 `PrivacyInfo.xcprivacy`에 선언되어 있다.
- 개인정보처리방침에는 Google·Supabase·Firebase FCM 국외 이전 표가 존재한다.
  최종 법률 문구는 사용자가 확인한다.
- 가입 화면에는 필수 만 14세 이상 확인이 있다.
- 피드·댓글 콘텐츠 필터, 신고·차단·가이드라인은 존재한다. 검토 당시 빠져
  있던 커뮤니티 글 작성 필터도 같은 `ContentFilter`로 적용하고 테스트했다.
  클라이언트 필터는 UX 보조이므로 서버 운영·신고 대응을 최종 방어선으로
  유지한다. 새 UGC 작성·수정 진입점을 추가할 때도 제출 직전 필터와
  신고·차단 연결을 필수 검토한다.
- AI 결과 화면은 공용 참고정보 고지를 사용한다. 반려동물이 아닌 이미지의
  실제 API 응답은 별도 실기기·실서비스 검증이 필요하다.
- 30일 soft-delete 안내와 Apple 최초 로그인 이름·이메일 보존 경로가 있다.
- Apple 탈퇴는 호출자 JWT의 계정만 대상으로 하며, Apple identity가 있으면
  native client ID `com.jena.petspace`로 재인증한다. Edge가 Apple JWKS의
  RS256 ID token, audience, issuer, subject, nonce를 검증하고 refresh token
  revoke 성공 후에만 soft delete를 기록한다.
- soft delete를 Apple revoke 뒤, best-effort 전역 sign-out 앞에 기록한다.
  전역 sign-out이 실패하더라도 L2 restrictive RLS가 25개 사용자 소유
  테이블에 대한 기존 access token의 읽기·쓰기를 막는다.
- 30일 purge는 Storage와 사용자 연관 데이터를 페이지네이션해 삭제하고,
  `ON DELETE SET NULL`로 본문이 남을 수 있는 발신 알림 행과 채팅방 마지막
  메시지 스냅샷을 identity 삭제 전에 제거한다.
- 위치 이용·제공사실 확인자료에는 좌표를 저장하지 않고 앱 내 약관에
  명시된 6개월 동안 분리 보관한다. 그 밖의 개인위치정보는 탈퇴·삭제 시
  파기한다. 매일 실행할 purge 배치가 UTC 달력 기준 6개월 만료 행도
  삭제하며, cron 등록은 제출 전 운영 게이트다.
- 실제 Android application ID는 `com.jena.petspace`다.
  `com.petspace.app`은 로그인 callback용 custom URL scheme으로만 남아
  있으므로 패키지 ID와 혼동하지 않는다.
- Apple 비공개 이메일 릴레이, 서명 archive SDK manifest, iPad, 마케팅
  푸시는 콘솔·실기기·서명 archive가 필요한 수동 검증 항목으로 유지한다.

## 2026-07-31 로컬 실행 결과

- Claude 최종 교차 검토: `LOCAL PASS`, BLOCKER 0건, HIGH 0건
- `flutter analyze --no-pub`: 오류 0건
- 관련 회귀 테스트: 65건 통과
- 전체 `flutter test --no-pub`: 999건 통과
- 릴리스 preflight 테스트 9건 통과, `BLOCKERS=0`
- Apple 탈퇴·30일 purge Edge 함수 `deno check`: 모두 통과
- `flutter build ios --release --no-codesign`: 통과
- `flutter build ipa --release --no-codesign --no-pub`: 통과
- 생성 archive: `com.jena.petspace`, `1.0.0(4)`, iOS 16.0,
  arm64, Runner Privacy Manifest 포함
- iPhone 17 시뮬레이터: 로그인 기본 크기와 최대 Dynamic Type에서
  스크롤·입력·소셜 로그인 진입점이 overflow 없이 표시됨
- iPad mini 시뮬레이터: 세로·가로에서 로그인 콘텐츠 폭을 480pt 이하로
  제한하고 키보드 노출 상태에서도 주요 입력 흐름이 유지됨
- iPhone 17 시뮬레이터에서 회원가입 입력 오류, 비밀번호 재설정 요청,
  6자리 코드 활성화, 잘못된 코드 오류, 재발송·뒤로가기를 직접 수행
- 인증 코드 화면의 중복 제목을 제거하고 제목 단일 노출 회귀 테스트 추가
- `git diff --check`, 충돌 표식 검색, plist·entitlement·privacy manifest
  문법 검사: 통과

상세 직접 수행 결과와 로그인 후 실계정 검증 범위는
`docs/release/2026-07-31-ios-simulator-device-test.md`에 기록했다.

이 결과는 로컬 무서명 빌드와 시뮬레이터 기준이다. 서명 archive, 실제 OAuth,
Apple credential revoke, APNs push, Kakao 지도 SDK 정상 렌더링은 실제 계정,
콘솔 설정, 운영 Edge 배포, 실기기 검증을 대체하지 않는다.

## 공통 출시 준비 순서

1. 기능·데이터 인벤토리를 고정한다.
2. 개인정보처리방침, 앱 내 고지, iOS Privacy Manifest, App Store/Play Data Safety 답변을 같은 사실로 맞춘다.
3. 공개 지원·개인정보·이용약관 URL을 배포하고 비로그인 환경에서 확인한다.
4. UGC 신고·차단·운영 응답 경로와 지원 연락처를 실제 운영 가능 상태로 만든다.
5. AI 기능은 진단·치료·정확도 보장 표현을 사용하지 않고 참고 정보임을 명시한다.
6. 버전·앱 ID·스토어 URL·딥링크를 플랫폼별 정본과 맞춘다.
7. QA 계정, 심사 메모, 화면 캡처, 개인정보 답변을 준비한다.
8. release build와 실기기 핵심 흐름을 검증한 뒤 각 스토어에 제출한다.

## iOS 단계별 준비

### 1단계 — 로컬 코드·구성

Codex가 수행할 수 있는 작업:

- `dart run tool/release_preflight.dart`
- `plutil` 기반 plist·entitlement 문법 검증
- `flutter analyze --no-pub`
- 관련 테스트 및 전체 `flutter test --no-pub`
- `flutter build ios --release --no-codesign`
- `flutter build ipa --release --no-codesign --no-pub`
- Privacy Manifest와 실제 데이터 흐름 차이 검출
- App Store 메타데이터·심사 메모 초안

사용자가 해야 하는 작업:

- 회사명·법적 연락처·지원 URL 최종 확인
- 개인정보 처리 목적·보유기간·국외 이전 문구 법적 확인
- Apple Developer 계약·멤버십 상태 확인
- 정확한 위치 수집의 사용자 연결·목적·보유기간 최종 확인

### 2단계 — Apple Developer·Firebase

사용자가 해야 하는 작업:

- App ID `com.jena.petspace` capability 확인
- Sign in with Apple·Push Notifications capability 확인
- Apple 탈퇴 revoke용 key가 App ID에 연결되었는지 확인하고 Edge secret
  `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`,
  `APPLE_CLIENT_ID=com.jena.petspace` 등록
- APNs `.p8` 키 생성·보관·Firebase Console 업로드
- 배포 인증서·provisioning profile 또는 Xcode 자동 서명 설정
- Kakao Developers에서 iOS bundle ID와 Native App Key 연결 상태 확인

Codex가 지원할 수 있는 작업:

- 화면 공유 상태에서 설정 경로와 값 대조
- 비밀 키 내용을 출력하거나 저장하지 않고 존재·연결 상태 확인
- 실기기 push 시나리오와 결과 기록

### 3단계 — App Store Connect 앱 레코드

사용자가 해야 하는 작업:

- Bundle ID로 신규 앱 생성
- SKU, 기본 언어, 사용자 액세스 설정
- 개인정보처리방침 URL·지원 URL 입력
- 연령 등급·콘텐츠 권리·수출 규정 답변

Codex가 준비할 수 있는 작업:

- 앱 이름·부제·설명·키워드·프로모션 문구
- 카테고리 제안
- 심사 메모와 QA 계정 입력 템플릿
- 스크린샷 순서·캡션 기획

### 4단계 — TestFlight

사용자가 해야 하는 작업:

- 서명된 archive 업로드
- 수출 규정·테스트 정보 입력
- 내부 테스트 그룹과 테스터 지정

Codex가 지원할 수 있는 작업:

- 업로드 전 archive 설정 점검
- TestFlight 설치본 회귀 시나리오
- 크래시·푸시·OAuth·계정탈퇴 결과 기록

### 5단계 — 심사 제출

사용자가 해야 하는 작업:

- 최종 build 선택
- 개인정보 답변과 심사 메모 최종 승인
- 제출 버튼 실행
- 심사 질의 대응 및 출시 방식 선택

Codex가 지원할 수 있는 작업:

- 거절 사유 분석
- 답변 초안과 수정 manifest
- 수정 후 재검증

## 필수 실기기 시나리오

- Apple·Google·Kakao 로그인과 로그아웃
- 신규 가입, 약관 동의, 이메일 인증, 비밀번호 재설정
- Apple 로그인 계정 회원탈퇴와 재인증·credential revoke
- 알림 권한 허용·거부, foreground/background/terminated push
- 게시글 작성·사진·장소 선택·삭제
- 릴리스 서명 빌드에서 Kakao 지도 정상 표시와 지도 실패 목록 폴백
- 신고·차단·차단 해제
- 채팅 전송·수신·푸시
- 카메라·사진·마이크·위치 권한 거부 후 복구
- Dynamic Type 200%, VoiceOver, 작은 화면, iPad
- 네트워크 단절·재시도·세션 만료

## 자동 점검 명령

`pjh/`에서 실행:

```bash
dart run tool/release_preflight.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --release --no-codesign
flutter build ipa --release --no-codesign --no-pub
git diff --check
```

preflight는 `secrets.dart`와 `GoogleService-Info.plist`의 내용·해시·크기를
읽지 않고 존재 여부만 보고한다.

## 참고 공식 문서

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app
- 위치정보법 제16조: https://law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1023742095
- 위치정보법 제23조: https://law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1030160469
- App information: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- FCM Flutter setup: https://firebase.google.com/docs/cloud-messaging/flutter/get-started
