# lib/features/auth/presentation/pages/terms_agreement_page.dart

**감사일:** 2026-04-22
**감사자:** Claude Code
**페이지 LOC:** 399줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/terms` (app_router.dart:178)
- **BLoC 의존성:** 없음 (순수 UI 상태)
- **상위 탭:** 온보딩 플로우 (로그인 직후)
- **로그인 필요:** ✅ (로그인 후 첫 진입)
- **Scaffold 구조:** AppBar + body(Padding → Column)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 47-53 | AppBar 뒤로가기 | `/onboarding/login` 이동 | 동일 | ⚠️ |
| 2 | GestureDetector | 74-108 | "네, 모두 동의합니다" 전체동의 | `_toggleAll` → 4개 체크박스 일괄 | 동일 | ✅ |
| 3 | GestureDetector | 350-381 (호출 112) | "만 14세 이상" (필수) | `_ageAgreed` 토글 + 전체상태 갱신 | 동일 | ✅ |
| 4 | GestureDetector | 350-381 (호출 124) | "서비스 이용약관" (필수) | `_termsAgreed` 토글 | 동일 | ✅ |
| 5 | GestureDetector | 384-394 | 서비스 약관 "보기" | `TermsDetailPage` push + `onAgree` 콜백 | 동일 | ✅ |
| 6 | GestureDetector | 350-381 (호출 184) | "개인정보 수집·이용" (필수) | `_privacyAgreed` 토글 | 동일 | ✅ |
| 7 | GestureDetector | 384-394 | 개인정보 "보기" | `TermsDetailPage` push + onAgree | 동일 | ✅ |
| 8 | GestureDetector | 350-381 (호출 242) | "마케팅 수신" (선택) | `_marketingAgreed` 토글 | 동일 | ✅ |
| 9 | GestureDetector | 384-394 | 마케팅 "보기" | `TermsDetailPage` push + onAgree | 동일 | ✅ |
| 10 | ElevatedButton | 305-329 | "다음" | 필수 3개 체크 시 `/onboarding/profile` | 동일 (`_canProceed`는 필수 3개만 확인) | ✅ |

**상호작용 요소 합계:** 10개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold(AppBar + body)
- body: SafeArea → Padding → Column (Spacer로 하단 고정)

### 스크롤
- [ ] 스크롤 없음 — Spacer 사용으로 모든 약관이 화면 안에 들어간다는 가정
- ⚠️ iPhone SE(667pt)처럼 작은 화면에서 overflow 위험

### Safe Area
- [x] SafeArea 적용 (line 55)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | 진입 | 모든 체크 해제, "다음" 비활성 |
| 필수 체크 | 3개 필수 체크 | "다음" 활성 |
| "보기" 탭 | TermsDetailPage 네비게이션 | 약관 본문 표시 후 onAgree로 복귀 |

---

## 🔗 외부 의존성

### API 호출
- 없음 (순수 UI, BLoC/Supabase 호출 없음)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/terms` (kakao_consent_page 또는 로그인 후 자동 redirect)
- 진출: `/onboarding/login` (뒤로), `/onboarding/profile` (동의 후)

---

## 🧪 시뮬레이터 동적 검증

**검증 필요** — 로그인 플로우 중간 단계. Phase 2 onboarding 감사 시 실제 진입 경로 확인.

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟠 High | 뒤로가기 signOut 누락 | line 47-53: `context.go('/onboarding/login')`만 하고 Supabase session은 유지됨. GoRouter redirect 로직이 다시 /onboarding/terms로 되돌릴 가능성 있음 (약관 미동의 유저) |
| 2 | 🟡 Medium | Scrollable 없음 → iPhone SE overflow 위험 | Column + Spacer로 고정 레이아웃, 작은 화면에서 overflow 가능 |
| 3 | 🟡 Medium | "보기" `Navigator.of(context).push` 사용 | GoRouter 프로젝트에서 MaterialPageRoute 직접 사용 → 라우팅 일관성 부족 |
| 4 | 🟢 Low | 약관 본문이 하드코딩 | line 140-171 (서비스 약관), line 200-229 (개인정보), line 258-269 (마케팅) — DB/원격 로딩 미사용, 개정 시 재배포 필요 |
| 5 | 🟢 Low | BouncingScrollPhysics 미적용 | 스크롤 자체가 없어 해당 없음 |

---

## ✅ 종합 평가

- **정상 동작:** 9/10 (뒤로가기는 명확히 ⚠️)
- **버그 발견:** 5건 (High 1 / Medium 2 / Low 2)
- **심각도:** High (약관 페이지 → 뒤로가기 redirect loop 가능)
- **iOS 특화 문제:** Medium 1건 (작은 화면 overflow)

### 권장 조치
- 즉시 수정: 이슈 #1 (뒤로가기 시 signOut 추가)
- 다음 이터레이션: #2 (SingleChildScrollView 래핑), #3 (GoRouter 통일)
- 모니터링: #4 (약관 원격 로딩)
