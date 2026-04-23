# lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 569줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/tutorial` (app_router.dart:196)
- **BLoC 의존성:** 없음 (StatefulWidget + PageController)
- **상위 탭:** 감정 분석 튜토리얼 (4페이지 슬라이드)
- **로그인 필요:** ✅
- **Scaffold 구조:** AppBar + SafeArea → Column(진행바 + Expanded(PageView 4장) + 하단 버튼)

> ⚠️ **실제 진입 경로 없음**: `grep '/onboarding/tutorial'` 결과 라우트 등록만 있고 `context.go/push`로 이 경로를 부르는 코드 없음. pet-registration → complete로 직접 이동하는 플로우라 **튜토리얼이 실제로 표시되지 않을 가능성** 있음.

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 32-41 | AppBar 뒤로가기 | canPop이면 pop, 아니면 `/onboarding/pet-registration` | 동일 | ✅ |
| 2 | TextButton | 50-59 | AppBar "건너뛰기" | `_skip` → `/onboarding/complete` | 동일 | ✅ |
| 3 | PageView | 67-80 | 가로 스와이프 (4페이지) | `_currentPage` 갱신 + progress indicator | 동일 | ✅ |
| 4 | OutlinedButton | 516-519 | "이전" (page > 0) | `_previousPage` | 동일 | ✅ |
| 5 | ElevatedButton | 524-532 | "다음" / "첫 분석 시작하기" (마지막) | `_nextPage` 또는 `_startFirstAnalysis` | 동일 | ✅ |

**상호작용 요소 합계:** 5개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar + SafeArea → Column
  - `_buildProgressIndicator` (4칸 bar + "N/4" 텍스트)
  - Expanded(PageView 4장)
  - `_buildNavigationButtons`

### 스크롤
- [x] PageView (가로) — 페이지 내부는 스크롤 없음
- 각 페이지에 긴 콘텐츠 있을 시 overflow 위험 (Photo tips 페이지 등)

### Safe Area
- [x] SafeArea 적용 (line 62)

### 리소스 관리
- [x] `_pageController.dispose()` (line 21)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 페이지 0 (환영) | `_currentPage = 0` | 이전 버튼 숨김, "다음" |
| 페이지 1 (사진 팁) | `_currentPage = 1` | 이전 + 다음 |
| 페이지 2 (분석 과정) | `_currentPage = 2` | 이전 + 다음 |
| 페이지 3 (결과) | `_currentPage = 3` | 이전 + "첫 분석 시작하기" |

---

## 🔗 외부 의존성

### API 호출
- 없음 (정적 튜토리얼)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/tutorial` — **실제 진입 트리거 없음** (잠재적 미사용)
- 진출: `/onboarding/pet-registration` (뒤로), `/onboarding/complete` (건너뛰기/시작하기)

---

## 🧪 시뮬레이터 동적 검증

**검증 불가** — 진입 경로가 없어 수동으로 `/onboarding/tutorial` URL 이동해야만 확인 가능.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | 진입 경로 없음 (잠재 미사용 페이지) | 라우트는 있으나 호출하는 곳 0. pet-registration → complete 플로우에 튜토리얼 생략됨. 의도적으로 비활성화인지 확인 필요 |
| 2 | 🟡 Medium | `_startFirstAnalysis`가 AI 분석 시작하지 않음 | line 563-568: 이름은 `_startFirstAnalysis`지만 실제로는 `/onboarding/complete`로 이동할 뿐. `context.go('/emotion')` 또는 분석 페이지로 연결 필요 |
| 3 | 🟢 Low | `Expanded flex: 0 ? 1 : 1` 무의미한 삼항 | line 523, slides와 동일 패턴 |
| 4 | 🟢 Low | 각 페이지 콘텐츠 스크롤 없음 | 작은 화면에서 overflow 가능 |

---

## ✅ 종합 평가

- **정상 동작:** 5/5
- **버그 발견:** 4건 (High 1 / Medium 1 / Low 2)
- **심각도:** High (진입 경로 부재)
- **iOS 특화 문제:** Low 1건

### 권장 조치
- **즉시 판단:** #1 — 튜토리얼 활성화(pet-registration 이후 삽입) 또는 파일 삭제
- 다음 이터레이션: #2 (`_startFirstAnalysis`가 이름값 하도록 수정)
- 모니터링: #3, #4
