# lib/features/onboarding/presentation/pages/onboarding_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 124줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding` (app_router.dart:150)
- **BLoC 의존성:** 없음 (StatelessWidget)
- **상위 탭:** 온보딩 플로우 (최초 실행 환영 페이지)
- **로그인 필요:** ❌
- **Scaffold 구조:** Scaffold + SafeArea → Column(Expanded(환영) + 하단 버튼)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | ElevatedButton | 104-120 | "시작하기" 버튼 | `/onboarding/login` 이동 | 동일 | ✅ |

**상호작용 요소 합계:** 1개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → SafeArea → Column
  - Expanded(Padding → Column): 아이콘 + 제목 + 설명 + 기능 소개 박스
  - _buildStartButton (고정 높이)

### 스크롤
- 스크롤 없음 — 작은 화면에서 overflow 위험

### Safe Area
- [x] SafeArea 적용 (line 13)

### 오버플로우 위험 지점
- Column에 고정 크기 자식만 있음: `Icon 120` + SizedBox + Text + SizedBox + Text + SizedBox + 기능 박스(3개 Row)
- iPhone SE (667pt)에서 총 높이 계산 시 여유 있음 추정 (약 510pt 사용)

---

## 🔄 상태 변화

정적 페이지 — 상태 변화 없음.

---

## 🔗 외부 의존성

### API 호출
- 없음

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding` (splash_page에서 Unauthenticated 상태일 때)
- 진출: `/onboarding/login` (시작하기 버튼)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 앱 첫 실행 시 자동 진입 (Unauthenticated 경로).

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | 스크롤 없음 → iPhone SE overflow 가능 | SingleChildScrollView 래핑 권장 |
| 2 | 🟢 Low | 이모지 텍스트 `🐾` 시스템 폰트 의존 | iOS/Android 이모지 렌더링 차이 — Pretendard 앱 폰트와 불일치 |
| 3 | 🟢 Low | `context.go` 사용 (`push` 아님) | 뒤로가기 불가 — 의도적인지 확인 필요 (백스택 초기화) |

---

## ✅ 종합 평가

- **정상 동작:** 1/1
- **버그 발견:** 3건 (Medium 1 / Low 2)
- **심각도:** Medium (small screen overflow)
- **iOS 특화 문제:** 없음

### 권장 조치
- 다음 이터레이션: #1 (SingleChildScrollView)
- 모니터링: #2, #3
