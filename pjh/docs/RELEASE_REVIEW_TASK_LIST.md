# PetSpace 출시 전 종합 리뷰 & 작업 지시서

- **작성일:** 2026-05-07
- **대상 브랜치:** `mac-ios-release` (= `origin/win-android-release` 동일 SHA `305ec9f`)
- **머지 상태:** Windows 브랜치 작업분은 이미 통합 완료 — 별도 머지 불필요
- **앱 버전:** `meong_nyang_diary` v1.0.0+1 / Bundle ID `com.petspace.app(.jsua)` / Android `com.petspace.app`

---

## 0. 종합 결론 (TL;DR)

| 관점 | 출시 가능 여부 | 핵심 메시지 |
|---|---|---|
| 풀스택 개발자 (20년차) | ⚠️ **수정 후 가능** | Sign in with Apple 미구현, cleartextTraffic, 키 노출 3건이 출시 블로커 |
| UI/UX 디자이너 (20년차) | 🟡 **양호하나 디테일 보완 필요** | 권한 거부 폴백·접근성·"더보기" UX 부재 |
| 한국 20~30대 유저 | 🟢 **무난** | Kakao 로그인·다크모드·Pretendard 적용 OK, Apple 로그인 추가 시 만족도↑ |
| Google Play 심사관 | ⚠️ **위험 항목 4건** | 데이터 안전성 양식·UGC 정책·민감 권한 정당화 누락 |
| App Store 심사관 | 🔴 **즉시 reject 위험 2건** | Sign in with Apple (4.8) + Privacy Manifest (필수) |

> **출시 가능 시점 추정:** P0 작업 완료 기준 **3~5 영업일** 내 가능. Privacy Manifest, Apple 로그인은 필수 경로.

---

## 1. 우선순위 분류 기준

- **P0 (Blocker)** — 미수정 시 스토어 reject 또는 보안 사고 가능. 출시 전 반드시 처리.
- **P1 (Major)** — 심사 통과는 가능하나 1차 reject 또는 유저 이탈 위험.
- **P2 (Minor)** — 출시 후 다음 패치(1~2주) 내 처리 권장.

---

## 2. P0 — Blocker 작업 (출시 전 필수)

### P0-1. Sign in with Apple 구현 (iOS)
- **관점:** App Store 심사관 ★★★ / 풀스택
- **근거:** App Store Review Guideline **4.8** — "타사 소셜 로그인 제공 시 Apple 로그인 동등 옵션 필수". 현재 Kakao + Google 만 제공.
- **현재 상태:**
  - [lib/features/auth/presentation/bloc/auth_bloc.dart:92-124](pjh/lib/features/auth/presentation/bloc/auth_bloc.dart#L92-L124) — Google/Kakao 핸들러만 존재
  - [lib/features/onboarding/presentation/pages/onboarding_login_page.dart](pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart) — Apple 버튼 없음
  - [ios/Runner/Info.plist](pjh/ios/Runner/Info.plist) — Apple URL scheme/Capability 미선언
- **작업 내용:**
  1. `pubspec.yaml` 에 `sign_in_with_apple` 패키지 추가
  2. Xcode `Runner.xcodeproj` → Signing & Capabilities → "Sign in with Apple" 추가
  3. Supabase Auth 콘솔에서 Apple Provider 활성화 + Service ID/Key 등록
  4. `auth_bloc.dart` 에 `AuthAppleSignInRequested` 이벤트/핸들러 추가
  5. `auth_repository_impl.dart` 에 Apple OAuth nonce 처리 로직 추가
  6. iOS 로그인 화면에서 Apple 버튼을 **Kakao/Google 위 또는 동일 위계**로 노출 (HIG 권장)
- **DoD:** TestFlight 빌드에서 Apple ID 로그인 → Supabase user row 생성 → 재로그인 시 동일 user 매칭, 회원탈퇴 후 재가입 시도까지 검증.

### P0-2. Android `usesCleartextTraffic="true"` 제거
- **관점:** Play 심사관 / 풀스택
- **근거:** Play 콘솔 보안 검사에서 경고. 평문 HTTP 트래픽 허용은 데이터 안전성 양식과 충돌.
- **현재 상태:** [android/app/src/main/AndroidManifest.xml:23](pjh/android/app/src/main/AndroidManifest.xml#L23)
- **작업 내용:**
  - 릴리즈 빌드에서 해당 속성 제거. 개발용으로 필요하면 `network_security_config.xml` 로 디버그 빌드만 허용.
  - Supabase/Firebase/Gemini 모든 엔드포인트가 HTTPS 인지 재확인.
- **DoD:** `./gradlew assembleRelease` 후 manifest merge 결과에 `cleartextTraffic` 없음 확인.

### P0-3. Supabase 키 평문 커밋 점검 + 키 로테이션
- **관점:** 풀스택 / 보안
- **근거:** [lib/config/secrets.dart:10-19](pjh/lib/config/secrets.dart#L10-L19) 평문. 과거 커밋 히스토리에 포함되어 있다면 anon key 라도 RLS 우회 패턴 발견 시 위험.
- **작업 내용:**
  1. `git log --all -p -- lib/config/secrets.dart lib/supabase_options.dart` 로 노출 이력 확인
  2. 노출 이력 있으면 Supabase 콘솔에서 **anon/service key 모두 로테이션**
  3. 빌드 타임 주입으로 전환: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  4. `secrets.dart` 는 `String.fromEnvironment` 로 주입받는 형태로 리팩토링, 실제 값은 `.env.local` + `.gitignore`
  5. CI/CD (Codemagic, Fastlane 등) 시크릿 환경변수로 등록
- **DoD:** `git grep -nE "supabase.co|eyJ[A-Za-z0-9_-]{20,}"` 결과 0건.

### P0-4. iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) 추가
- **관점:** App Store 심사관 ★★★
- **근거:** 2024년 5월부터 App Store 제출 시 **필수**. 누락 시 자동 reject.
- **현재 상태:** [ios/Runner/](pjh/ios/Runner/) 에 `PrivacyInfo.xcprivacy` 없음
- **작업 내용:**
  1. Xcode → New File → App Privacy → `PrivacyInfo.xcprivacy` 생성
  2. 다음 API 카테고리 선언 (앱 사용 현황 기반):
     - `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1)
     - `NSPrivacyAccessedAPICategoryFileTimestamp` (3B52.1 — 이미지 업로드 시 사용 가능)
     - `NSPrivacyAccessedAPICategorySystemBootTime` (필요 시)
  3. 수집 데이터 타입 선언: 이메일, 이름, 사진, 위치(대략), 사용자 콘텐츠, 식별자, 사용량 데이터, 진단(Crashlytics)
  4. 광고 식별자 미사용 → `NSPrivacyTracking = false`
- **DoD:** Xcode Archive → Validate App 에서 Privacy Manifest 관련 경고 0건.

### P0-5. Google Play 데이터 안전성(Data Safety) 양식 작성 자료 준비
- **관점:** Play 심사관 ★★★
- **근거:** Play Console 제출 시 필수. 누락/허위 신고 시 즉시 reject.
- **작업 내용 (문서 작성):**
  - 수집 항목: 이메일, 이름, 프로필 사진, 반려동물 정보, 위치(대략), 게시글/사진(사용자 콘텐츠), 기기 식별자, Crashlytics 진단
  - 공유 대상: Supabase(클라우드 DB), Google Gemini(감정분석 이미지), Firebase(분석/크래시)
  - 보안 관행: 전송 암호화(TLS), 사용자 데이터 삭제 요청 가능(회원탈퇴), 독립 보안 검토 X
  - **민감 권한 정당화 문구**: 카메라/위치/알림 각각 한 문장씩 준비
- **DoD:** [docs/PLAY_DATA_SAFETY.md](pjh/docs/) 에 양식 초안 commit.

### P0-6. Android 13+ 알림 권한 거부 시 폴백 + Foreground Service 정당화
- **관점:** Play 심사관 / UX
- **현재 상태:** [lib/core/services/local_notification_service.dart:105-117](pjh/lib/core/services/local_notification_service.dart#L105-L117) 권한 요청은 있으나 거부 시 사용자 안내 부재
- **작업 내용:**
  1. 권한 거부 후 알림 메뉴 진입 시 "설정에서 알림을 켜주세요" 가이드 + `openAppSettings()` 버튼
  2. AndroidManifest 의 `WAKE_LOCK` 사용 정당화 (Foreground Service 미사용이면 제거)
- **DoD:** 권한 거부 → 알림 설정 페이지 진입 시 안내 + 버튼 동작 확인.

---

## 3. P1 — Major 작업 (1차 reject 위험)

### P1-1. 차단(Block) 사용자 콘텐츠 DB 레벨 필터링 검증
- **관점:** Play/iOS 심사관 (UGC) / 풀스택
- **현재 상태:** [lib/core/services/block_service.dart:55-89](pjh/lib/core/services/block_service.dart#L55-L89) 존재하나 피드 RPC 가 차단 사용자 게시글을 제외하는지 미확인
- **작업 내용:**
  1. `supabase/petspace_setup.sql` 의 피드 조회 RPC (`get_feed_posts`, `get_following_posts` 등)에 `WHERE author_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE blocker_id = auth.uid())` 추가
  2. 댓글/검색/탐색/채팅 목록에도 동일 필터 적용
  3. 통합 테스트: A 가 B 를 차단 → B 의 신규 게시글이 A 피드에 노출되지 않음
- **DoD:** RPC 단위 테스트 + 실기기 시나리오 1회.

### P1-2. 신고(Report) 후 24시간 응답 SLA 명시 + 모더레이션 정책 페이지
- **관점:** App Store 심사관 (Guideline 1.2) ★★★
- **근거:** Apple 은 UGC 앱에 대해 **24시간 내 신고 처리 + 모더레이션 정책 명시** 를 요구.
- **작업 내용:**
  1. `lib/features/profile/presentation/pages/community_guidelines_page.dart` 신규 생성 (또는 외부 URL)
  2. 내용: 금지 콘텐츠, 신고 처리 절차, 24시간 응답 약속, 차단/탈퇴 안내
  3. 마이페이지 → 약관/정책 섹션에 진입점 추가
  4. App Store Connect 제출 시 "Notes for Reviewer" 에 해당 URL/페이지 명시
- **DoD:** 페이지 빌드 + 약관 섹션에서 진입 가능.

### P1-3. 권한 거부 폴백 UX (카메라/사진)
- **관점:** UI/UX / 한국 20~30대 유저
- **현재 상태:** `CreatePostPage` 에서 권한 거부 시 별도 안내 없음 (UI/UX 리뷰 결과)
- **작업 내용:**
  1. `permission_handler` 결과 `permanentlyDenied` 일 때 BottomSheet 로 "설정에서 권한 허용" 안내 + `openAppSettings()` 버튼
  2. 카메라/사진 모두에 적용 (게시글 작성, 감정분석 사진 업로드, 프로필 사진 변경)
- **DoD:** iOS/Android 실기기에서 권한 거부 → 재시도 동선 확인.

### P1-4. 키워드 필터 + 이미지 모더레이션 전략
- **관점:** Play 심사관 / 콘텐츠 안전
- **현재 상태:** 신고/차단만 존재, 능동적 필터 없음
- **작업 내용 (최소):**
  1. 게시글/댓글 작성 시 클라이언트에서 한국어 비속어/혐오 키워드 1차 필터 (간단한 deny-list, [lib/core/services/content_filter.dart](pjh/lib/core/services/) 신규)
  2. 게시글 사진은 Supabase Edge Function 또는 Gemini Safety 카테고리 검사 후 업로드 (1차로는 Gemini `safetySettings` 활용)
  3. 위반 시 토스트 안내 + 게시 차단
- **DoD:** 비속어 입력 시 게시 불가, Gemini Safety 위반 사진 업로드 차단.

### P1-5. `app_icon.png` 16384×16384 → 1024×1024 최적화
- **관점:** 풀스택 / 빌드 사이즈
- **현재 상태:** [assets/icons/app_icon.png](pjh/assets/icons/app_icon.png) 16384×16384
- **작업 내용:** 1024×1024 PNG 로 재생성, `flutter_launcher_icons` 재실행, IPA/APK 사이즈 비교.
- **DoD:** 앱 번들 사이즈 감소 확인 + 모든 mipmap/AppIcon.appiconset 정상 표시.

### P1-6. 게시글 본문 "더보기" UX
- **관점:** UI/UX / 유저 / Play 심사관 (성능)
- **현재 상태:** 본문 길이 제한 미확인, 긴 글이 그대로 노출되면 피드 스크롤 성능 저하
- **작업 내용:** 피드 카드에서 본문 4~6 줄 초과 시 `…더보기` → 상세 페이지 이동 또는 인라인 확장. [lib/features/social/presentation/widgets/post_card.dart](pjh/lib/features/social/presentation/widgets/post_card.dart) 수정.
- **DoD:** 1000자 더미 게시글에서 카드 높이 일정 + 더보기 동작.

### P1-7. 감정분석 AI 면책(Disclaimer)
- **관점:** App Store 심사관 (의료/건강 카테고리 우려) / 유저
- **근거:** "반려동물 감정분석" 은 의료/진단 오해 소지. Apple 은 의료/심리 진단 표현을 엄격히 본다.
- **작업 내용:**
  1. 분석 결과 화면 하단에 **"본 결과는 참고용이며 수의학적 진단을 대체하지 않습니다"** 배너 추가
  2. 온보딩 튜토리얼에도 동일 면책 1회 노출
  3. 개인정보처리방침에 "감정분석 이미지는 Google Gemini 로 처리되며 30일 후 폐기" 등 처리 기간 명시
- **DoD:** 모든 분석 결과 화면 + 튜토리얼에서 면책 노출.

### P1-8. App Tracking Transparency (ATT) 처리 (iOS)
- **관점:** App Store 심사관
- **근거:** Firebase Analytics 사용 시 IDFA 접근 가능성 → ATT 프롬프트 필요. 미사용 시 `Info.plist` 에 트래킹 안 함을 명시.
- **작업 내용:** 광고 SDK 미통합 가정하에 `NSUserTrackingUsageDescription` 미선언 + Firebase Analytics 의 `setAnalyticsCollectionEnabled` 만 사용. ATT 프롬프트 불필요함을 코드 주석으로 1줄 명시.
- **DoD:** Validate App 시 ATT 관련 경고 없음.

---

## 4. P2 — Minor 작업 (출시 후 단기 패치)

| ID | 항목 | 관점 | 현재 상태 / 위치 | 작업 |
|---|---|---|---|---|
| P2-1 | 다국어(영어) 1차 추가 | UI/UX, 글로벌 확장 | `intl` 만 선언, ARB 미존재 | `lib/l10n/` ARB 골격 + 핵심 화면 영어 번역. 출시 시점은 한국어 단일 OK. |
| P2-2 | 접근성 Semantics 라벨 보강 | UI/UX | `post_card` 일부만 | 좋아요/댓글/공유 버튼에 `Semantics(label:)` 추가 |
| P2-3 | 키보드 회피 / `KeyboardActions` | UI/UX | `resizeToAvoidBottomInset` 만 | 댓글/게시글 작성 화면에 입력창 위 toolbar (Done 버튼) |
| P2-4 | 풀투리프레시 햅틱 통일 | 유저 감성 | RefreshIndicator 사용 | iOS 에서 `HapticFeedback.mediumImpact` 호출 통일 |
| P2-5 | 카카오 공유 / 인스타 스토리 공유 | 한국 20~30대 유저 | 공유 토스트만 | 카카오톡 공유 SDK 통합 (선택) |
| P2-6 | 앱 시작 시간 측정 (Firebase Performance) | 풀스택 | 미통합 | `firebase_performance` 추가 |
| P2-7 | 빈 검색 결과 / 네트워크 오류 EmptyState | UI/UX | 일부만 | 검색·해시태그·위치 페이지에 동일 톤 EmptyState |

---

## 5. 스토어별 제출 체크리스트

### 5.1 Google Play Console
- [ ] `applicationId = com.petspace.app` 변경 불가 — 최종 확인
- [ ] versionCode/versionName 출시 직전 +1
- [ ] 서명: Play App Signing 활성화, upload key 백업
- [ ] **Data Safety 양식** (P0-5)
- [ ] **민감 권한 정당화** (카메라·위치·알림)
- [ ] **콘텐츠 등급 설문** — UGC 포함, 폭력/성적 콘텐츠 없음
- [ ] **타깃 연령**: 만 14세 이상 (앱 약관과 일치)
- [ ] 스크린샷 (폰 4~8장, 7인치 태블릿 1장 권장)
- [ ] 짧은 설명(80자) / 긴 설명 (한국어)
- [ ] 개인정보처리방침 **공개 URL** 필수 — 앱 내 링크만으로는 불충분
- [ ] 광고 포함 여부: "아니요"
- [ ] 64-bit ABI 포함 (Flutter 기본 OK)

### 5.2 App Store Connect
- [ ] **Sign in with Apple 구현** (P0-1)
- [ ] **PrivacyInfo.xcprivacy** (P0-4)
- [ ] **App Privacy 답변** — 수집 데이터 카테고리 정확히
- [ ] **Encryption Compliance**: 표준 암호화만 사용 → "예, 면제 대상" 선택
- [ ] **Sandbox 테스트 계정** (Reviewer 용 demo 계정 필수 — 카카오 로그인 우회 위해 이메일 계정 또는 Apple ID)
- [ ] Reviewer 메모: 펫 사진 분석 데모 흐름 + 신고/차단 위치 + Demo 계정 정보
- [ ] App Icon 1024×1024 (P1-5)
- [ ] 스크린샷 6.7"/6.5"/5.5" (iPhone) + 12.9" (iPad — iPhone-only 면 제외)
- [ ] **Age Rating**: UGC 포함, 의료/약물 정보 없음
- [ ] Export Compliance: HTTPS 만 사용 → 면제

---

## 6. 작업 순서 권장안

```
Day 1-2 (출시 D-5)
  ├─ P0-1 Sign in with Apple (Backend + iOS UI)
  ├─ P0-3 Supabase 키 로테이션 + dart-define 전환
  └─ P0-4 PrivacyInfo.xcprivacy

Day 3 (D-3)
  ├─ P0-2 cleartextTraffic 제거 + 회귀 테스트
  ├─ P0-6 알림 권한 폴백
  ├─ P1-1 차단 DB 필터링
  └─ P1-3 권한 거부 폴백 UX

Day 4 (D-2)
  ├─ P1-2 커뮤니티 가이드라인 페이지
  ├─ P1-4 키워드 필터 + Gemini Safety
  ├─ P1-5 app_icon 최적화
  ├─ P1-6 더보기 UX
  └─ P1-7 감정분석 면책 배너

Day 5 (D-1)
  ├─ P0-5 Data Safety 문서 작성
  ├─ P1-8 ATT 점검
  ├─ TestFlight + 내부 테스트 트랙 업로드
  └─ Reviewer 노트 / 스크린샷 제출

Day 6 (D-0): 심사 제출
```

---

## 7. 머지 / 배포 체크 (참고)

- 현재 `main` 은 `c7f9c2e`, `mac-ios-release` 는 `305ec9f` — 출시 전 `mac-ios-release → main` 머지 (PR 또는 `git merge`) 후 태그(`v1.0.0`).
- 태깅 후 Codemagic / Fastlane / Xcode Cloud 중 어떤 파이프라인을 쓸지 결정. 현재 리포에 명시적 CI 설정이 보이지 않으면 별도 회의 안건으로 분리.

---

## 8. 미해결 / 추가 확인 필요

- 회원탈퇴 시 **Storage(이미지)·Realtime 채팅·포인트 거래내역**까지 cascade 삭제되는지 SQL 검증 필요
- Supabase Auth Admin API 키가 클라이언트에 노출되어 있지 않은지 재확인
- iPad 지원 여부 결정 (지원 시 layout 회귀 테스트, 미지원 시 `UIDeviceFamily` 1 로 고정)
- 한국 개인정보보호법 개정(2024) 반영: 동의 철회 / 삭제 요청 절차를 약관에 명시했는지 법무 검토
