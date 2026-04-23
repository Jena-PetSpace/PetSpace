# lib/features/onboarding/presentation/pages/splash_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 365줄

---

## 📍 페이지 개요

- **진입 라우트:** `/splash` (app_router.dart `initialLocation: '/splash'`)
- **BLoC 의존성:** AuthBloc (리스너만)
- **상위 탭:** 없음 (앱 시작 진입점)
- **로그인 필요:** ❌
- **Scaffold 구조:** BlocListener → Scaffold(body: Stack)

---

## 🎯 상호작용 요소 카탈로그

사용자 직접 인터랙션은 **없음**. 내부 상태 전환 (애니메이션 완료 + Auth 상태)만 존재.

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | Timer | 63-67 | 3초 타임아웃 | `_lottieFinished = true` + `_navigate()` 강제 | 동일 | ✅ |
| 2 | Lottie onLoaded | 79-98 | 애니메이션 로드 완료 | Lottie 재생 → 완료 시 400ms 대기 → 이동 | 동일 | ✅ |
| 3 | Lottie errorBuilder | 175-196 | Lottie 로드 실패 | `splash_char.png` fallback + 600ms 후 이동 | 동일 | ✅ |
| 4 | BlocListener | 134-138 | Auth 확정 상태 감지 | `_authReady = true` + `_tryNavigate()` | AuthAuthenticated/Unauthenticated만 처리 | ✅ |

**상호작용 요소 합계:** 4개 (자동 트리거, 사용자 입력 0개)

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold(backgroundColor: primaryColor) → Stack
- Stack 계층:
  1. 3개 `_DecoRing` (배경 장식)
  2. Center(Column): Lottie 160×160 + 로고 + 슬로건 + AI 뱃지
  3. Positioned bottom: 3dot 로딩 + "by JENA Team"

### 스크롤
- 스크롤 없음 (정적 표시)

### Safe Area
- ❌ SafeArea 미적용 — Stack + Positioned로 직접 배치
- 하단 `bottom: 48.h` 고정값 → iPhone 홈 인디케이터와 겹침 가능성 검토 필요

### 리소스 관리
- [x] `_lottieController.dispose()` (line 72)
- [x] `_logoController.dispose()` (line 73)
- [x] `_maxWaitTimer?.cancel()` (line 74)
- [x] `_LoadingDotState._ctrl.dispose()` (line 344-347)

### 오버플로우 위험 지점
- Center + Column 내부에 sized children만 있어 overflow 위험 낮음
- Lottie 로드 중 `AnimatedOpacity`로 플래시 방지 — 좋은 패턴

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| Lottie 로딩 중 | `_lottieLoaded = false` | opacity 0 (투명) |
| Lottie 표시 | onLoaded 후 | opacity 1 + 재생 |
| 로고 슬라이드인 | Lottie 시작 800ms 후 또는 완료 후 | 로고 + 슬로건 + 뱃지 표시 |
| Lottie 실패 | errorBuilder | `splash_char.png` 표시 → 600ms 후 이동 |
| 이동 결정 | `_lottieFinished && _authReady` | context.go(route) |
| 타임아웃 | 3초 경과 | 강제 이동 |

### 라우팅 분기 (line 112-130)

| AuthBloc 상태 | 이동 경로 | 라우트 등록 확인 |
|--------------|----------|---------------|
| AuthInitial/AuthLoading | 대기 | — |
| AuthAuthenticated + isOnboardingCompleted | `/home` | ✅ |
| AuthAuthenticated + !isOnboardingCompleted | `/onboarding/terms` | ✅ |
| 그 외 (Unauthenticated) | `/onboarding` | ✅ |

---

## 🔗 외부 의존성

### API 호출
- 없음 (AuthBloc이 이미 상태 보유)

### 권한 요청
- 없음

### Deep Link / 다른 페이지 이동
- 진입: initialLocation
- 진출: `/home`, `/onboarding/terms`, `/onboarding`

### 에셋
- `assets/lottie/splash.json` — Lottie 애니메이션
- `assets/icons/splash_char.png` — fallback

---

## 🧪 시뮬레이터 동적 검증

**검증 용이** — 앱 시작 시 자동 진입.

### 검증 포인트
- [ ] Lottie 애니메이션 로드 성공 / 재생 확인
- [ ] 3초 내 다음 화면 전환
- [ ] AuthBloc 상태에 따른 올바른 분기

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | 하단 "by JENA Team" Safe Area 미반영 | line 261-283: `bottom: 48.h` 고정. iPhone X+ home indicator(34pt)와 겹칠 가능성 |
| 2 | 🟢 Low | SystemUIOverlayStyle 전역 설정 충돌 가능 | line 37-42: 스플래시는 transparent+light 설정, main.dart는 흰색+dark 설정. `AnnotatedRegion`으로 감싸는 것이 안전 |
| 3 | 🟢 Low | `_DecoRing` 클래스 명명 규칙 | `private class` 이름 언더스코어 접두사 일관됨 (✅) |
| 4 | 🟢 Low | `_lottieLoaded` 미사용 경로 (line 81) | onLoaded에서만 설정, errorBuilder에서도 true로 설정 — 패턴 상 일관됨. 정보 참고용 |

---

## ✅ 종합 평가

- **정상 동작:** 4/4 (내부 상태 전환)
- **버그 발견:** 4건 (Medium 1 / Low 3)
- **심각도:** Medium (Safe Area)
- **iOS 특화 문제:** 1건 (home indicator)

### 권장 조치
- 다음 이터레이션: 이슈 #1 (SafeArea wrap 또는 MediaQuery.padding.bottom 반영)
- 모니터링: #2 (overlay style wrapping 개선)

### 사용자 인터랙션 없음

이 페이지는 자동 진행만 있고 사용자 조작 요소는 없음. 버그 발견 시 "스플래시가 안 사라진다" / "무한 로딩" / "이동 경로 틀림" 같은 간접 증상으로만 노출됨.
