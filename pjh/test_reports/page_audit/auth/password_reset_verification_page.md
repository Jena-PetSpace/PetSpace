# lib/features/auth/presentation/pages/password_reset_verification_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 482줄

---

## 📍 페이지 개요

- **진입 라우트:** `/auth/password-reset/verify?email=...` (app_router.dart:220)
- **BLoC 의존성:** 없음 — **Supabase 직접 호출**
- **상위 탭:** 비밀번호 재설정 플로우 (3단계 중 2단계)
- **로그인 필요:** ❌
- **Scaffold 구조:** AppBar + body(SingleChildScrollView(Column))

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 198-207 | AppBar 뒤로가기 | signOut + `/auth/password-reset/request` 이동 | 동일 (await 처리됨) | ✅ |
| 2 | TextField × 6 | 268-309 | OTP 숫자 6칸 입력 | 숫자만, maxLength 1, 자동 다음칸 포커스 | 동일 | ✅ |
| 3 | KeyboardListener | 265-267 | Backspace 시 이전 칸 포커스 | 빈 칸일 때 이전 칸 이동 | 동일 | ✅ |
| 4 | ElevatedButton | 348-374 | "인증하기" | `_verifyOtp` → verifyOTP(magiclink) → 성공 시 new-password 페이지 | 동일 | ✅ |
| 5 | TextButton | 390-403 | "재발송" | 60초 카운트다운 후 OTP 재발송 | 카운트다운 작동 | ✅ |

**상호작용 요소 합계:** 5개 (OTP 6칸을 1개로 계산)

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar(투명) + SafeArea → SingleChildScrollView → Column

### 스크롤
- [x] `SingleChildScrollView` (line 210)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 209)

### 리소스 관리
- [x] `_controllers.dispose()` 6개 loop (line 44-46)
- [x] `_focusNodes.dispose()` 6개 loop (line 47-49)
- [x] `_countdownTimer?.cancel()` (line 50)
- ⚠️ **`KeyboardListener`의 내부 `FocusNode()`가 새로 생성됨** (line 266) — dispose 안 됨 (리크 가능)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | 진입 시 | 6칸 빈 입력 + 카운트다운 60초 시작 |
| 입력 중 | 숫자 입력 | 다음 칸 자동 포커스, 모두 채우면 자동 검증 |
| Verifying | `_isVerifying = true` | 버튼 로더 |
| 성공 | verifyOTP → user != null | 스낵바 + 500ms 후 new-password 이동 |
| 실패 | AuthException | 에러 메시지 + 입력 필드 전부 초기화 |
| Resending | `_isResending = true` | 재발송 버튼 비활성 |
| 재발송 성공 | signInWithOtp 성공 | 카운트다운 60초 재시작 + 스낵바 |

---

## 🔗 외부 의존성

### API 호출
- **Supabase 직접 호출** (line 74, 121, 202): 3건
  - `signInWithOtp` (재발송)
  - `verifyOTP` (검증)
  - `signOut` (뒤로가기)

### 권한 요청
- 없음

### Deep Link / 다른 페이지 이동
- 진입: `/auth/password-reset/verify?email=...`
- 진출: `/auth/password-reset/request` (뒤로), `/auth/password-reset/new-password` (성공)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — request 페이지에서 이메일 입력 후 진입.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | Supabase 직접 호출 3건 | line 74, 121, 202 — AuthRepository 경유 필요 |
| 2 | 🟡 Medium | KeyboardListener 내부 `FocusNode()` 리크 | line 266 — `focusNode: FocusNode()` 새로 만들지만 dispose 안 함. 페이지 재진입 반복 시 메모리 누수 |
| 3 | 🟡 Medium | OTP 타입이 magiclink로 하드코딩 | line 123 `type: OtpType.magiclink` — `recovery` 타입이 더 적절할 수 있음 (Supabase 권장) |
| 4 | 🟢 Low | 에러 원문 노출 | line 164 `e.toString()` 그대로 노출 |
| 5 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 감성 |

---

## ✅ 종합 평가

- **정상 동작:** 5/5
- **버그 발견:** 5건 (High 1 / Medium 2 / Low 2)
- **심각도:** High (아키텍처 위반) + Medium (리소스 누수)
- **iOS 특화 문제:** Low 1건

### 권장 조치
- 다음 이터레이션: 이슈 #1 (Repository), #2 (FocusNode dispose)
- 모니터링: 이슈 #3, #4, #5
