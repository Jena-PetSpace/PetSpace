# lib/features/auth/presentation/pages/register_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 76줄

---

## 📍 페이지 개요

- **진입 라우트:** ⚠️ **없음 — DEAD CODE**
- **BLoC 의존성:** AuthBloc
- **상위 탭:** 없음
- **로그인 필요:** N/A

> ⚠️ **DEAD CODE** — `grep -rn "RegisterPage"` 결과 정의만 나옴. 라우터에 등록되지 않고 호출되는 곳도 없음. 실제 회원가입은 `login_page`/`onboarding_login_page`의 `_isLogin` 토글을 통해 동일 화면에서 처리됨.

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | SocialLoginButton (Google) | 39-49 | "Google로 시작하기" | `AuthSignInWithGoogleRequested` | 동일 | ✅ |
| 2 | SocialLoginButton (Kakao) | 51-61 | "Kakao로 시작하기" | `AuthSignInWithKakaoRequested` | 동일 | ✅ |

**상호작용 요소 합계:** 2개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold(AppBar + body(Padding → Column))

### 스크롤
- [ ] 스크롤 없음 — 작은 화면에서 overflow 위험

### Safe Area
- ❌ SafeArea 미적용

### 리소스 관리
- StatelessWidget — 리소스 관리 불필요

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 기본 | 진입 | 2개 소셜 로그인 버튼 |
| Loading | AuthLoading | CircularProgressIndicator 하단 추가 |

---

## 🔗 외부 의존성

### API 호출
- 간접적 (AuthBloc 경유): Google/Kakao SDK

### Deep Link / 다른 페이지 이동
- 진입: **없음** (dead code)
- 진출: 성공 시 AuthBloc 리스너가 전역 라우팅 처리 (`/home` or `/onboarding/profile`)

---

## 🧪 시뮬레이터 동적 검증

**검증 스킵** — 라우터 미등록으로 진입 불가.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | **DEAD CODE** — 미사용 | 라우터 미등록, 어디서도 호출되지 않음. login_page와 기능 중복. 삭제 권장 |
| 2 | 🟡 Medium | SafeArea 미적용 | notch/home indicator 침범 가능 |
| 3 | 🟡 Medium | 스크롤 없음 | iPhone SE 가로모드/작은 화면에서 overflow 위험 |
| 4 | 🟢 Low | 이메일 회원가입 옵션 없음 | 실제 login_page에는 있으나 여기에는 소셜만 존재 (dead code여서 무관) |

---

## ✅ 종합 평가

- **정상 동작:** 2/2 (dead code 기준)
- **버그 발견:** 4건 (High 1 / Medium 2 / Low 1)
- **심각도:** High (dead code)
- **iOS 특화 문제:** Medium 1건 (SafeArea)

### 권장 조치
- **즉시 수정:** 이슈 #1 — 파일 삭제 (login_page와 동일 처리)
