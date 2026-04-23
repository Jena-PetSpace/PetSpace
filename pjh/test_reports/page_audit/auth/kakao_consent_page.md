# lib/features/auth/presentation/pages/kakao_consent_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 367줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/kakao-consent` (app_router.dart:173)
- **BLoC 의존성:** 없음 (순수 UI 상태만 관리)
- **상위 탭:** 로그인 플로우 (카카오 동의 미리보기)
- **로그인 필요:** ❌ (로그인 중간 플로우)
- **Scaffold 구조:** AppBar + body(Column) + 하단 고정 버튼

**용도:** 카카오 로그인 동의 화면의 UI 미리보기(프로토타입). 실제 OAuth 동의는 Kakao SDK가 처리하고 이 페이지는 교육용/커스텀 동의 UI로 보임.

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 39-44 | AppBar 닫기(×) | `/onboarding/login` 이동 | 동일 | ✅ |
| 2 | GestureDetector | 141-174 | "전체 동의하기" 카드 | 모든 체크박스 토글 | `_toggleAll` 호출 → 모두 true/false | ✅ |
| 3 | GestureDetector | 332-365 (호출: 191) | "프로필 정보(필수)" 체크 | `_profileAgreed` 토글 + 전체동의 상태 갱신 | 동일 | ✅ |
| 4 | GestureDetector | 332-365 (호출: 203) | "카카오계정(이메일, 선택)" 체크 | `_emailAgreed` 토글 + 전체동의 상태 갱신 | 동일 | ✅ |
| 5 | GestureDetector | 253-265 | 제3자 제공 동의 "보기" 링크 | 상세 동의 내용 표시 | **onTap 빈 함수** — 아무 동작 없음 | ❌ |
| 6 | ElevatedButton | 292-317 | "동의하고 계속하기" | 필수항목 동의 시 `/onboarding/terms` 이동 | `_canProceed`는 `_profileAgreed`만 확인 | ✅ |

**상호작용 요소 합계:** 6개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → SafeArea → Column(브랜딩+Expanded(스크롤)+하단 버튼)
- 하단 버튼은 Box 고정 + BoxShadow로 분리

### 스크롤
- [x] `SingleChildScrollView` (line 93) — 중앙 콘텐츠만 스크롤
- [ ] BouncingScrollPhysics 미적용 (iOS 네이티브 감성 부족)

### Safe Area
- [x] SafeArea 적용됨 (line 55)

### 오버플로우 위험 지점
- 하단 버튼 높이 56px + BoxShadow — Safe Area.bottom 추가 처리 없음 → iPhone X+ 홈 인디케이터와 살짝 겹칠 수 있음

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | 모든 체크 해제 | 버튼 비활성화 (disabled) |
| 필수 미체크 | `_profileAgreed == false` | 버튼 회색 + onPressed null |
| 필수 체크 | `_profileAgreed == true` | 버튼 카카오 옐로우 활성화 |

---

## 🔗 외부 의존성

### API 호출
- 없음 (순수 UI 페이지)

### 권한 요청
- 없음

### Deep Link / 다른 페이지 이동
- 진입 경로: `/onboarding/kakao-consent` (app_router에 등록 ✅)
- 진출 경로: `/onboarding/login` (닫기), `/onboarding/terms` (동의하고 계속)

---

## 🧪 시뮬레이터 동적 검증

**검증 스킵** — 이 페이지는 일반 플로우에서 자동 진입되지 않음. 카카오 OAuth는 Kakao SDK가 처리하므로 현재 코드 경로상 진입 여부 자체가 불명확. Phase 2 onboarding 감사 시 진입 트리거 재확인 필요.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | "보기" 링크 onTap 빈 함수 | line 253-256, 제3자 제공 동의 상세 보기 기능 미구현 |
| 2 | 🟡 Medium | 구 앱명 "멍냥 다이어리" 노출 | line 120, "펫페이스"로 교체 필요 |
| 3 | 🟢 Low | 회사명 오타 가능성 "(주)재나" | line 127, "(주)제나"가 맞을 가능성 |
| 4 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 네이티브 스크롤 감성 부족 |
| 5 | 🟢 Low | 하단 버튼 SafeArea.bottom 미반영 | iPhone X+ 홈 인디케이터 침범 가능 |

---

## ✅ 종합 평가

- **정상 동작:** 5/6
- **버그 발견:** 5건 (Medium 2 / Low 3)
- **심각도:** Medium (기능 누락 1건 + 브랜딩 문제 1건)
- **iOS 특화 문제:** Low 2건 (스크롤 physics, Safe Area)

### 권장 조치
- 즉시 수정: 이슈 #1(보기 기능 구현 또는 UI 제거), #2(앱명)
- 다음 이터레이션: 이슈 #3, #4, #5
