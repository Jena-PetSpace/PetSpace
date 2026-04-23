# lib/features/auth/presentation/pages/login_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 341줄

---

## 📍 페이지 개요

- **진입 라우트:** ⚠️ **없음 — 라우터에 등록되지 않은 DEAD CODE**
- **BLoC 의존성:** AuthBloc
- **상위 탭:** 없음
- **로그인 필요:** N/A

> ⚠️ **중요 발견:** 이 파일은 프로젝트 전체에서 **자기 자신 외에는 참조되지 않음**. `grep -rn "LoginPage"` 결과가 정의 자체만 나옴. 실제 사용되는 로그인 페이지는 `lib/features/onboarding/presentation/pages/onboarding_login_page.dart` (route: `/onboarding/login`).
>
> 이 파일은 동일한 기능의 중복 구현이거나 legacy 잔여물로 추정.

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | ElevatedButton.icon | 121-127 | "카카오로 시작하기" | `AuthSignInWithKakaoRequested` 이벤트 | 동일 | ✅ |
| 2 | ElevatedButton.icon | 129-136 | "구글로 시작하기" | 데스크톱이면 안내 다이얼로그, 아니면 `AuthSignInWithGoogleRequested` | 동일 | ✅ |
| 3 | TextFormField | 199-217 | 이메일 입력 | `@` 포함 검증, 빈값 검증 | 동일 | ✅ |
| 4 | TextFormField | 219-237 | 비밀번호 입력 | 최소 6자 검증 | 동일 | ✅ |
| 5 | ElevatedButton | 242-245 | "로그인"/"회원가입" | `_isLogin`에 따라 SignIn/SignUp 이벤트 | 동일 | ✅ |
| 6 | TextButton | 255-268 | "계정 없으신가요/있으신가요" | `_isLogin` 토글 | 동일 | ✅ |
| 7 | TextButton | 270-278 | "비밀번호를 잊으셨나요?" | `/password-reset-request` push | **라우트 불일치** — 실제는 `/auth/password-reset/request` | ❌ |
| 8 | ElevatedButton | 310-313 | 데스크톱 다이얼로그 "확인" | 다이얼로그 닫기 | 동일 | ✅ |

**상호작용 요소 합계:** 8개

---

## 🎨 UI 요소

### 레이아웃 구조
- Stack(Scaffold + 로딩 오버레이)
- Scaffold → SafeArea → Column
- 하단 `Expanded(SingleChildScrollView(이메일 폼))`로 키보드 오버플로우 대응

### 스크롤
- [x] `SingleChildScrollView` (line 71) — 이메일 폼 영역
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용됨 (line 57)

### 리소스 관리
- [x] `_emailController.dispose()` (line 23)
- [x] `_passwordController.dispose()` (line 24)

### 오버플로우 위험 지점
- `resizeToAvoidBottomInset: true` + `Expanded(SingleChildScrollView)` 조합으로 키보드 처리 양호

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 기본 | 진입 시 | `_isLogin = true` (로그인 모드) |
| 회원가입 모드 | 토글 TextButton 클릭 | 헤더/버튼 텍스트 변경, "비밀번호 잊으셨나요" 숨김 |
| Loading | AuthLoading | 전체 화면 반투명 오버레이 + CircularProgressIndicator |
| Authenticated | AuthAuthenticated | isOnboardingCompleted 분기 → `/home` or `/onboarding/profile` |
| Error | AuthError | 빨간 스낵바 |

---

## 🔗 외부 의존성

### API 호출
- 간접적 (AuthBloc 경유): Supabase Auth, Kakao SDK, Google Sign In

### 권한 요청
- 없음 (직접) — BLoC에서 처리

### Deep Link / 다른 페이지 이동
- 진입: **없음** (dead code)
- 진출: `/home`, `/onboarding/profile`, `/password-reset-request` (**잘못된 경로**)

---

## 🧪 시뮬레이터 동적 검증

**검증 스킵** — 라우터에 등록되지 않아 시뮬레이터에서 진입 불가.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | **DEAD CODE** — 파일 전체 미사용 | 라우터에 등록되지 않음. `onboarding_login_page.dart`가 실제 사용됨. 유지 비용 증가, 수정 시 혼동 유발 |
| 2 | 🟠 High | `/password-reset-request` 라우트 불일치 | line 338, 실제 등록 라우트는 `/auth/password-reset/request` — 파일 삭제하면 해결되지만 코드 복사/활성화 시 동일 버그 재현 |
| 3 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 감성 부족 (dead code이므로 실제 영향 없음) |

---

## ✅ 종합 평가

- **정상 동작:** 7/8 (dead code 관점)
- **버그 발견:** 3건 (High 2 / Low 1)
- **심각도:** High (dead code + 라우트 버그)
- **iOS 특화 문제:** 실제 영향 없음

### 권장 조치
- **즉시 수정:** 이슈 #1 — 파일 삭제 또는 `onboarding_login_page.dart`와 통합
  - 삭제가 안전한지 확인: `grep -rn "LoginPage" lib/` 결과에 정의만 있음 → 삭제 가능
- 모니터링: 이슈 #2 (파일 삭제 시 자동 해결)
