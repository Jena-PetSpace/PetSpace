# lib/features/auth/presentation/pages/password_reset_new_password_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 425줄

---

## 📍 페이지 개요

- **진입 라우트:** `/auth/password-reset/new-password` (app_router.dart:228)
- **BLoC 의존성:** 없음 — **Supabase 직접 호출** (아키텍처 위반)
- **상위 탭:** 비밀번호 재설정 플로우 (3단계 중 3단계)
- **로그인 필요:** ❌ (재설정 OTP 검증 후 진입)
- **Scaffold 구조:** AppBar + body(SingleChildScrollView(Form(Column)))

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 166-174 | AppBar 뒤로가기 | signOut + `/onboarding/login` 이동 | 동일 | ✅ |
| 2 | TextFormField | 233-257 | 새 비밀번호 입력 | 6~72자 검증, obscure 토글 | 동일 | ✅ |
| 3 | IconButton | 243-254 | 새 비밀번호 보기/숨기기 | `_obscurePassword` 토글 | 동일 | ✅ |
| 4 | TextFormField | 261-285 | 비밀번호 확인 입력 | 앞서 입력한 값과 일치 검증 | 동일 | ✅ |
| 5 | IconButton | 271-282 | 확인 비밀번호 보기/숨기기 | `_obscurePasswordConfirm` 토글 | 동일 | ✅ |
| 6 | ElevatedButton | 320-346 | "비밀번호 변경" | `_resetPassword` 호출 → Supabase updateUser | 동일, 성공 시 다이얼로그 표시 | ✅ |
| 7 | ElevatedButton | 86-103 | 성공 다이얼로그 "로그인하러 가기" | signOut + `/onboarding/login` | 동일 | ✅ |

**상호작용 요소 합계:** 7개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold(AppBar + body)
- body: SafeArea → SingleChildScrollView → Form → Column

### 스크롤
- [x] `SingleChildScrollView` (line 182)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 181)

### 리소스 관리
- [x] `_passwordController.dispose()` (line 33)
- [x] `_passwordConfirmController.dispose()` (line 34)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 기본 | 진입 직후 | 두 입력 필드 + 안내 사항 표시 |
| 입력 중 | 입력 변경 | 실시간 검증 없음 (submit 시 validate) |
| Loading | `_isLoading = true` | 버튼 내 CircularProgressIndicator |
| 성공 | updateUser 성공 | 다이얼로그 (barrierDismissible: false) |
| 에러 | AuthException | 빨간색 에러 박스 표시 |

---

## 🔗 외부 의존성

### API 호출
- **Supabase 직접 호출** (line 52-54): `Supabase.instance.client.auth.updateUser(...)` — Clean Architecture 위반
- `signOut()` 직접 호출 (line 89, 170)

### 권한 요청
- 없음

### Deep Link / 다른 페이지 이동
- 진입: `/auth/password-reset/new-password?email=xxx` (password_reset_verification_page에서)
- 진출: `/onboarding/login` (성공 또는 뒤로가기)

---

## 🧪 시뮬레이터 동적 검증

**검증 지연** — OTP 검증 완료 후에만 진입 가능. Phase 12 이후 전체 플로우 테스트 시 재검증.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | Supabase 직접 호출 (아키텍처 위반) | line 52, 89, 170 — `Supabase.instance.client.auth.updateUser` / `signOut` 직접 호출. AuthRepository/UseCase 경유 필요 |
| 2 | 🟡 Medium | 성공 다이얼로그 "로그인하러 가기" 버튼 — context 혼란 | line 87-91: 먼저 signOut, 그 다음 go. signOut은 async지만 await 없음 → 타이밍 문제 가능 |
| 3 | 🟢 Low | AppBar 뒤로가기 signOut 동일 패턴 | line 168-174: async signOut 후 navigation, 여기는 `await` 처리됨 (✅) — 다이얼로그 쪽만 불일치 |
| 4 | 🟢 Low | 에러 메시지 사용자 노출 과다 | line 120 `e.toString()` — 시스템 에러 문자열 그대로 노출, 보안/UX 이슈 |
| 5 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 스크롤 감성 |

---

## ✅ 종합 평가

- **정상 동작:** 7/7
- **버그 발견:** 5건 (High 1 / Medium 1 / Low 3)
- **심각도:** High (아키텍처 위반)
- **iOS 특화 문제:** Low 1건

### 권장 조치
- **다음 이터레이션:** 이슈 #1 (Supabase 직접호출 → Repository), #2 (await signOut)
- 모니터링: 이슈 #3, #4, #5
