# lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 492줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/email-verification?email=...` (app_router.dart:165)
- **BLoC 의존성:** 없음 — **Supabase 직접 호출**
- **상위 탭:** 온보딩 플로우 (회원가입 직후 이메일 인증)
- **로그인 필요:** 이메일 가입 직후 (session 있을 수 있음)
- **Scaffold 구조:** AppBar + SafeArea → SingleChildScrollView → Column

> **Phase 1 `auth/password_reset_verification_page.dart` 와 거의 동일 구조.** (OTP 타입만 `signup`으로 다름)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 215-220 | AppBar 뒤로가기 | `/onboarding/login` 이동 | 동일 | ⚠️ |
| 2 | TextField × 6 | 281-322 | OTP 6칸 숫자 입력 | 숫자만 maxLength 1, 자동 다음칸 | 동일 | ✅ |
| 3 | KeyboardListener | 278-280 | Backspace → 이전 칸 | 빈 칸에서 Backspace 시 이전 포커스 | 동일 | ✅ |
| 4 | ElevatedButton | 361-384 | "인증하기" | `_verifyOtp` → OTP 검증 (signup 타입) → signOut + `/onboarding/login` | 동일 | ✅ |
| 5 | TextButton | 400-413 | "재발송" (60초 카운트다운) | 60초 후 OTP resend → 카운트다운 재시작 | 동일 | ✅ |

**상호작용 요소 합계:** 5개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar(투명) + SafeArea → SingleChildScrollView → Column

### 스크롤
- [x] `SingleChildScrollView` (line 223)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 222)

### 리소스 관리
- [x] 6개 `_controllers.dispose()` (line 60-62)
- [x] 6개 `_focusNodes.dispose()` (line 63-65)
- [x] `_countdownTimer?.cancel()` (line 66)
- ⚠️ **`KeyboardListener`의 내부 `FocusNode()` 리크** (line 279) — Phase 1 password_reset_verification과 동일 이슈

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | `_resendCountdown = 60` 카운트다운 시작 | 재발송 "60초" 비활성 |
| 입력 중 | TextField 입력 | 자동 다음칸 이동, 모두 입력 시 자동 `_verifyOtp` |
| Verifying | `_isVerifying = true` | 버튼 내 로더 |
| 성공 | verifyOTP → user != null | SnackBar + signOut + 500ms 후 `/onboarding/login` |
| 실패 | AuthException | 에러 메시지 + 입력 초기화 + 첫 칸 포커스 |
| Resending | `_isResending = true` | 재발송 버튼 비활성 |

---

## 🔗 외부 의존성

### API 호출
- **Supabase 직접 호출 3건:**
  - `auth.resend(type: signup)` (line 79-82)
  - `auth.verifyOTP(type: signup)` (line 132-136)
  - `auth.signOut()` (line 150)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/email-verification?email=...` (회원가입 직후 login_page가 보냄)
- 진출: `/onboarding/login` (뒤로 또는 성공 후)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 회원가입 → OTP 수신 후 진입.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | Supabase 직접 호출 3건 | Clean Architecture 위반 (Phase 1 password_reset_verification와 동일 패턴) |
| 2 | 🟠 High | 뒤로가기 시 signOut 누락 | line 215-220: `/onboarding/login` go만 하고 session 유지 — 회원가입 미완료 유저가 session 보유 상태로 머무는 문제 발생 가능 |
| 3 | 🟡 Medium | KeyboardListener 내부 FocusNode 리크 | line 279: `focusNode: FocusNode()` dispose 없음 |
| 4 | 🟡 Medium | OTP 검증 성공 후 로그아웃 처리 흐름 | line 150: 회원가입 완료 시 의도적 signOut → 재로그인 유도. UX상 불편할 수 있으나 정책 판단 필요 |
| 5 | 🟢 Low | 에러 원문 노출 `e.toString()` | line 108, 178 — 사용자 노출 문자열 정제 필요 |
| 6 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 감성 |

---

## ✅ 종합 평가

- **정상 동작:** 5/5
- **버그 발견:** 6건 (High 2 / Medium 2 / Low 2)
- **심각도:** High
- **iOS 특화 문제:** Low 1건

### 권장 조치
- 다음 이터레이션: #1 (AuthRepository 이전), #2 (뒤로가기 signOut), #3 (FocusNode dispose)
- 검토: #4 (인증 성공 후 signOut 정책)
- 모니터링: #5, #6

### Phase 1 password_reset_verification_page와 비교

| 항목 | email_verification (이것) | password_reset_verification |
|------|--------------------------|----------------------------|
| OTP 타입 | `signup` | `magiclink` |
| 뒤로가기 signOut | ❌ 없음 | ✅ 있음 (await 처리됨) |
| FocusNode 리크 | ❌ 동일하게 있음 | ❌ 동일 |
| Supabase 직접 호출 | 3건 | 3건 |

→ **공통 이슈 패턴 확정**: 6자리 OTP UI 전용 위젯으로 추출 + FocusNode dispose 수정 권장
