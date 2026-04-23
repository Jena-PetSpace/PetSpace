# lib/features/onboarding/presentation/pages/onboarding_login_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 475줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/login` (app_router.dart:160)
- **BLoC 의존성:** AuthBloc
- **상위 탭:** 온보딩 플로우 (실제 사용되는 로그인 페이지)
- **로그인 필요:** ❌
- **Scaffold 구조:** BlocListener → Scaffold → Stack(SafeArea(SingleChildScrollView) + 로딩 오버레이)

**※ 중요:** Phase 1에서 감사한 `auth/login_page.dart`는 DEAD CODE이고, **이 파일이 실제 사용되는 로그인 페이지**임.

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | ElevatedButton.icon | 186-192 | "Google 계정으로 로그인하기" | `AuthSignInWithGoogleRequested` + 로딩 | 동일 | ✅ |
| 2 | ElevatedButton.icon | 194-200 | "카카오톡 계정으로 로그인하기" | `AuthSignInWithKakaoRequested` + 로딩 | 동일 | ✅ |
| 3 | TextFormField | 271-293 | 성명 입력 (회원가입 모드만) | 2~20자 검증 | 동일 | ✅ |
| 4 | TextFormField | 296-314 | 이메일 입력 | `@` 포함 검증 | 동일 | ✅ |
| 5 | TextFormField | 316-334 | 비밀번호 입력 | 최소 6자 | 동일 | ✅ |
| 6 | TextFormField | 338-358 | 비밀번호 확인 (회원가입 모드만) | `_passwordController.text` 일치 | 동일 | ✅ |
| 7 | ElevatedButton | 364-379 | "로그인"/"회원가입" | `_emailLogin` 호출 | 동일 | ✅ |
| 8 | TextButton | 389-402 | 모드 전환 | `_isLogin` 토글 (소셜/Divider/성명/확인필드 숨김/표시) | 동일 | ✅ |
| 9 | TextButton | 404-412 | "비밀번호를 잊으셨나요?" (로그인 모드만) | `/auth/password-reset/request` 이동 | **정상** — auth/login_page의 `/password-reset-request` 버그와 다름 | ✅ |

**상호작용 요소 합계:** 9개

---

## 🎨 UI 요소

### 레이아웃 구조
- BlocListener → Scaffold → Stack
  - SafeArea → SingleChildScrollView → Column: 헤더 + 소셜버튼 + Divider + 이메일폼 + (RateLimit) + 하단버튼
  - 로딩 오버레이 (카카오/구글/이메일 로그인 중)

### 스크롤
- [x] `SingleChildScrollView` (line 106)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 105)

### 리소스 관리
- [x] `_emailController.dispose()` (line 34)
- [x] `_passwordController.dispose()` (line 35)
- [x] `_passwordConfirmController.dispose()` (line 36)
- [x] `_displayNameController.dispose()` (line 37)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 로그인 모드 | `_isLogin = true` (기본) | 소셜 2개 + Divider + 이메일+비번 + 비번 찾기 |
| 회원가입 모드 | `_isLogin = false` | 소셜 숨김 + 성명+이메일+비번+비번확인, 비번찾기 숨김 |
| Kakao 로딩 | `_isKakaoLoginInProgress = true` | 전체 오버레이 + 진행 표시 |
| Google 로딩 | `_isGoogleLoginInProgress = true` | 전체 오버레이 |
| Email 로딩 | `_isEmailLoginInProgress = true` 또는 `_isSigningUp` | 버튼 내 로더 + 비활성 |
| RateLimit | `_rateLimitDuration != null` | RateLimitCountdown 위젯 노출 |

### BlocListener 분기 (line 43-99)
- AuthEmailVerificationRequired → `/onboarding/email-verification?email=...` 이동 + 로딩 초기화
- AuthAuthenticated → 로딩 초기화만 (GoRouter redirect가 `/onboarding/terms` or `/home` 처리)
- AuthError with retryAfter → `_rateLimitDuration` 설정
- AuthError without retryAfter → SnackBar (빈 메시지는 사용자 취소로 간주)

---

## 🔗 외부 의존성

### API 호출
- 간접: AuthBloc → Supabase Auth, Kakao SDK, Google Sign In

### 권한 요청
- 없음 (BLoC에서 처리)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/login` (splash Unauthenticated 경로, `/onboarding` 시작하기)
- 진출:
  - `/onboarding/email-verification?email=...` (회원가입 직후)
  - `/onboarding/terms` or `/home` (GoRouter redirect가 처리)
  - `/auth/password-reset/request` (비밀번호 찾기)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 앱 시작 Unauthenticated 경로로 자동 진입.

### 검증 포인트
- [ ] 소셜 로그인 3종 동작 (Kakao/Google은 시뮬레이터에서 제한)
- [ ] 이메일 로그인/회원가입 모드 전환
- [ ] RateLimit 카운트다운 표시
- [ ] 오버레이 타이밍

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟢 Low | BouncingScrollPhysics 미적용 | SingleChildScrollView iOS 감성 부족 |
| 2 | 🟢 Low | 소셜 로그인 버튼 색상 하드코딩 | `#4285F4` Google, `#FEE500` Kakao — 브랜드 컬러라 변경 불가하나 AppTheme에 상수화 권장 |
| 3 | 🟢 Low | 회원가입 모드에서도 비밀번호 찾기 버튼 표시 고려 | 현재는 `if (_isLogin)` 조건부라 문제 없음 — 회귀 방지 주석 있으면 좋음 |

---

## ✅ 종합 평가

- **정상 동작:** 9/9
- **버그 발견:** 3건 (Low 3)
- **심각도:** Low
- **iOS 특화 문제:** 1건 (Scroll physics)

### 권장 조치
- Phase 1 auth/login_page.dart (dead code)의 버그들이 이 파일에는 **모두 없음** 확인
- `/auth/password-reset/request` 경로 정상 (auth/login_page와 달리 맞음)
- 모니터링: Low 3건

### 감사 하이라이트

이 페이지는 **Phase 1의 `auth/login_page.dart`와 거의 동일한 목적**이지만 훨씬 세련되게 구현됨:
- Rate limit 카운트다운 UI
- 로그인/회원가입 모드에서 소셜 버튼 조건부 숨김
- 3가지 로그인 방식 독립 로딩 상태 관리
- 비밀번호 찾기 경로 **정확함** (Phase 1 버그 재현 안 됨)

→ Phase 12 수정 시 `auth/login_page.dart` 삭제 시 이 파일이 남아 정상 동작 유지.
