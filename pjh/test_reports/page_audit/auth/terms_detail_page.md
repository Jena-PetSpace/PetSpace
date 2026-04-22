# lib/features/auth/presentation/pages/terms_detail_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 95줄

---

## 📍 페이지 개요

- **진입 라우트:** 라우터 미등록 — `MaterialPageRoute`로 직접 push 됨 (terms_agreement_page에서)
- **BLoC 의존성:** 없음
- **상위 탭:** 온보딩 (약관 상세 모달)
- **로그인 필요:** ❌
- **Scaffold 구조:** AppBar + body(Column: Expanded(Scroll) + 하단 버튼)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 22-25 | AppBar 뒤로가기 | `Navigator.of(context).pop()` | 동일 | ✅ |
| 2 | ElevatedButton | 67-87 | "동의" 하단 버튼 | `onAgree()` 콜백 + `pop()` | 동일 | ✅ |

**상호작용 요소 합계:** 2개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold(AppBar + body)
- body: SafeArea → Column(Expanded(SingleChildScrollView) + 하단 버튼 Container)

### 스크롤
- [x] `SingleChildScrollView` (line 39) — 약관 본문
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 35)
- ⚠️ 하단 버튼 Container에 SafeArea.bottom 별도 처리 없음 → iPhone X+ 홈 인디케이터 침범 가능

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 기본 | 진입 | 약관 본문 + (optional) 동의 버튼 |
| 읽기만 | `onAgree == null` | 하단 버튼 숨김 |
| 동의 가능 | `onAgree != null` | "동의" 버튼 노출 |

---

## 🔗 외부 의존성

### API 호출
- 없음 (순수 UI)

### Deep Link / 다른 페이지 이동
- 진입: `MaterialPageRoute` push (terms_agreement_page에서)
- 진출: `Navigator.pop()` (동의 또는 뒤로가기)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — terms_agreement_page → "보기" 클릭.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | GoRouter 미사용 | `MaterialPageRoute`로 직접 push되어 전체 라우팅 시스템과 불일치. 딥링크/복구 지원 안 됨 |
| 2 | 🟢 Low | 하단 버튼 SafeArea.bottom 미적용 | iPhone X+ 홈 인디케이터 침범 가능 |
| 3 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 스크롤 감성 |
| 4 | 🟢 Low | 버튼 색상 하드코딩 (orange) | AppTheme 토큰 미사용 (line 73) |

---

## ✅ 종합 평가

- **정상 동작:** 2/2
- **버그 발견:** 4건 (Medium 1 / Low 3)
- **심각도:** Medium
- **iOS 특화 문제:** Low 2건

### 권장 조치
- 다음 이터레이션: 이슈 #1 (GoRouter로 이전)
- 모니터링: #2, #3, #4
