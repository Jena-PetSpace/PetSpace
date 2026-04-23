# lib/features/auth/presentation/pages/password_reset_request_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 309줄

---

## 📍 페이지 개요

- **진입 라우트:** `/auth/password-reset/request` (app_router.dart:215)
- **BLoC 의존성:** 없음 — **Supabase 직접 호출**
- **상위 탭:** 비밀번호 재설정 플로우 (3단계 중 1단계)
- **로그인 필요:** ❌
- **Scaffold 구조:** AppBar + body(SingleChildScrollView(Form(Column)))

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 88-91 | AppBar 뒤로가기 | `/onboarding/login` 이동 | 동일 | ✅ |
| 2 | TextFormField | 149-169 | 이메일 입력 | `@` 포함 검증 | 동일 | ✅ |
| 3 | ElevatedButton | 204-230 | "인증 코드 발송" | OTP 발송 + `/auth/password-reset/verify?email=...` 이동 | 동일 | ✅ |

**상호작용 요소 합계:** 3개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar(투명) + SafeArea(SingleChildScrollView(Form))

### 스크롤
- [x] `SingleChildScrollView` (line 98)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 97)

### 리소스 관리
- [x] `_emailController.dispose()` (line 23)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 기본 | 진입 시 | 입력 필드 + "발송" 버튼 |
| Loading | `_isLoading = true` | 버튼 내 CircularProgressIndicator |
| 성공 | OTP 발송 완료 | `/auth/password-reset/verify?email=...` 이동 |
| 에러 | AuthException | 빨간 에러 박스 표시 |

---

## 🔗 외부 의존성

### API 호출
- **Supabase 직접 호출** (line 43-46): `Supabase.instance.client.auth.signInWithOtp(...)` — Clean Architecture 위반

### 권한 요청
- 없음

### Deep Link / 다른 페이지 이동
- 진입: `/auth/password-reset/request` (login 페이지에서 "비밀번호를 잊으셨나요" 클릭)
- 진출: `/onboarding/login` (뒤로), `/auth/password-reset/verify?email=...` (다음 단계)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 로그인 페이지의 "비밀번호를 잊으셨나요" 버튼으로 진입.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | Supabase 직접 호출 (아키텍처 위반) | line 43 — AuthRepository.sendPasswordResetEmail() 같은 메서드 필요 |
| 2 | 🟡 Medium | 안내 문구 모순 | line 268 "가입하지 않은 이메일은 코드를 받을 수 없습니다" vs line 41-42 주석 "등록되지 않은 이메일에도 에러를 반환하지 않아" — 사용자가 실패 원인 판단 불가 |
| 3 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 감성 |
| 4 | 🟢 Low | 에러 문구 일부 정규화 필요 | line 78 `$error` 원문 노출 |

---

## ✅ 종합 평가

- **정상 동작:** 3/3
- **버그 발견:** 4건 (High 1 / Medium 1 / Low 2)
- **심각도:** High (아키텍처 위반)
- **iOS 특화 문제:** Low 1건

### 권장 조치
- 다음 이터레이션: 이슈 #1 (Repository 이전)
- 모니터링: 이슈 #2, #3, #4
