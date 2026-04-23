# lib/features/onboarding/presentation/pages/onboarding_slides_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 300줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/slides` (app_router.dart:158)
- **BLoC 의존성:** 없음
- **상위 탭:** 온보딩 소개 슬라이드
- **로그인 필요:** ❌
- **Scaffold 구조:** AppBar(투명) + SafeArea → Column(Expanded(PageView) + 하단)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | TextButton | 33-42 | AppBar "건너뛰기" | `/onboarding/login` 이동 | 동일 | ✅ |
| 2 | PageView | 49-61 | 좌우 스와이프 슬라이드 | `_currentPage` 갱신 | 동일 | ✅ |
| 3 | OutlinedButton | 240-248 | "이전" (페이지 0 이후) | 이전 슬라이드 애니메이션 | 동일 | ✅ |
| 4 | ElevatedButton | 253-267 | "다음" / "시작하기" | 다음 슬라이드 또는 `/onboarding/login` | 동일 | ✅ |

**상호작용 요소 합계:** 4개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar + SafeArea → Column(Expanded(PageView 3장) + 하단 Indicator/버튼)

### 스크롤
- [x] PageView (가로 스와이프)
- 슬라이드 내부 스크롤 없음 — 각 슬라이드 LOC가 작아 overflow 위험 낮음

### Safe Area
- [x] SafeArea 적용 (line 45)

### 리소스 관리
- [x] `_pageController.dispose()` (line 20)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 슬라이드 1 | `_currentPage == 0` | 이전 버튼 숨김, 다음 버튼만 |
| 슬라이드 2 | `_currentPage == 1` | 이전 + 다음 양쪽 |
| 슬라이드 3 | `_currentPage == 2` | 이전 + "시작하기" (텍스트 변경) |

---

## 🔗 외부 의존성

### API 호출
- 없음

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/slides` (app_router에만 정의, 실제 진입 경로 불명확)
- 진출: `/onboarding/login` (건너뛰기 / 시작하기)

---

## 🧪 시뮬레이터 동적 검증

### 검증 필요
- [ ] `/onboarding/slides` 라우트로 실제 진입되는 플로우가 있는지 확인 필요
- `splash_page`는 → `/onboarding` (slides 아님)로 보냄

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | 실제 진입 경로 불명확 | splash/auth 플로우에서 `/onboarding/slides` 호출 안 됨 → 잠재적 미사용 |
| 2 | 🟡 Medium | 슬라이드 아이콘 하드코딩 색상 | `Icons.pets` primaryColor, `Icons.psychology` orange, `Icons.people` green — AppTheme 토큰 미사용 |
| 3 | 🟢 Low | Expanded flex 의미없음 | line 252 `flex: _currentPage == 0 ? 1 : 1` — 삼항연산자 양쪽이 같음 (무의미) |
| 4 | 🟢 Low | 이미지 대신 아이콘만 사용 | UX 관점: 실제 앱 스크린샷이나 일러스트가 있으면 더 전달력 있음 |

---

## ✅ 종합 평가

- **정상 동작:** 4/4
- **버그 발견:** 4건 (Medium 2 / Low 2)
- **심각도:** Medium
- **iOS 특화 문제:** 없음

### 권장 조치
- 다음 이터레이션: #1 (실제 사용 여부 파악 후 정리 또는 활성화), #2 (AppTheme 색상 토큰)
- 모니터링: #3, #4
