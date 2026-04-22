# 발견된 버그 통합 로그

> 모든 Phase에서 발견된 버그를 통합 관리합니다. Phase 12에서 일괄 수정 대상.

**시작일:** 2026-04-22

---

## 심각도 정의

| 심각도 | 기준 |
|-------|------|
| 🔴 **Critical** | 앱 크래시 / 데이터 손실 / 보안 문제 / 주요 기능 완전 마비 |
| 🟠 **High** | 주요 기능 동작 안 함 / 라우팅 실패 / BLoC 상태 불일치 |
| 🟡 **Medium** | UI 오버플로우 / 빈 상태 누락 / 일부 엣지 케이스 실패 |
| 🟢 **Low** | 사소한 UX 개선 / 스타일 조정 / 불필요 코드 |

---

## 수정 상태 정의

- ⏳ **Reported**: 신규 기록, 미수정
- 🔨 **In Progress**: 수정 작업 중
- ✅ **Fixed**: 수정 완료, 검증됨
- 📌 **Deferred**: 이번 이터레이션에서 제외 (다음 작업)
- ❌ **Wont Fix**: 수정하지 않기로 결정

---

## 버그 목록

| # | 페이지 | 요소 | 심각도 | 증상 | 수정 상태 | Phase | 파일:라인 |
|---|--------|------|-------|------|---------|------|---------|
| 001 | my_page.dart | _buildEmptyState | 🟡 Medium | 하단 6.1px overflow | ✅ Fixed | Pre-audit | my_page.dart:251 |
| 002 | feed_page.dart | 좋아요 버튼 | 🟠 High | widget.userId 빈 문자열로 서버 거절 → 원상복귀 | ✅ Fixed | Pre-audit | feed_page.dart:144 |
| 003 | post_card.dart | 작성자명 탭 | 🟠 High | `/profile/:id` push했으나 등록된 라우트는 `/user-profile/:userId` | ✅ Fixed | Pre-audit | post_card.dart:143 |
| 004 | kakao_consent_page | "보기" 링크 | 🟡 Medium | onTap 빈 함수 — 제3자 제공 동의 상세 보기 미구현 | ⏳ Reported | Phase 1 | kakao_consent_page.dart:253 |
| 005 | kakao_consent_page | 앱명 "멍냥 다이어리" | 🟡 Medium | 구 앱명 노출, "펫페이스"로 교체 필요 | ⏳ Reported | Phase 1 | kakao_consent_page.dart:120 |
| 006 | kakao_consent_page | "(주)재나" | 🟢 Low | 회사명 오타 가능성 ("(주)제나"?) | ⏳ Reported | Phase 1 | kakao_consent_page.dart:127 |
| 007 | kakao_consent_page | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 (iOS 감성) | ⏳ Reported | Phase 1 | kakao_consent_page.dart |
| 008 | kakao_consent_page | 하단 버튼 Safe Area | 🟢 Low | SafeArea.bottom 미반영, home indicator 침범 가능 | ⏳ Reported | Phase 1 | kakao_consent_page.dart:276 |
| 009 | login_page (auth) | 파일 전체 | 🟠 High | **DEAD CODE** — 라우터에 등록되지 않음. onboarding_login_page가 실제 사용 | ⏳ Reported | Phase 1 | login_page.dart:전체 |
| 010 | login_page (auth) | "비밀번호 잊으셨나요" | 🟠 High | `/password-reset-request` push, 실제는 `/auth/password-reset/request` | ⏳ Reported | Phase 1 | login_page.dart:338 |
| 011 | login_page (auth) | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 | ⏳ Reported | Phase 1 | login_page.dart |
| 012 | password_reset_new_password | updateUser | 🟠 High | Supabase 직접 호출 — Clean Arch 위반 | ⏳ Reported | Phase 1 | password_reset_new_password_page.dart:52 |
| 013 | password_reset_new_password | 성공 다이얼로그 signOut | 🟡 Medium | `signOut()` async이지만 await 없음 → 타이밍 이슈 가능 | ⏳ Reported | Phase 1 | password_reset_new_password_page.dart:87 |
| 014 | password_reset_new_password | 에러 노출 | 🟢 Low | `e.toString()` 원문 노출 (보안/UX) | ⏳ Reported | Phase 1 | password_reset_new_password_page.dart:120 |
| 015 | password_reset_new_password | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 | ⏳ Reported | Phase 1 | password_reset_new_password_page.dart |
| 016 | password_reset_request | signInWithOtp | 🟠 High | Supabase 직접 호출 — Clean Arch 위반 | ⏳ Reported | Phase 1 | password_reset_request_page.dart:43 |
| 017 | password_reset_request | 안내 문구 모순 | 🟡 Medium | "가입하지 않은 이메일은 받을 수 없음" vs 주석 "에러 반환 안 함" | ⏳ Reported | Phase 1 | password_reset_request_page.dart:41,268 |
| 018 | password_reset_request | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 | ⏳ Reported | Phase 1 | password_reset_request_page.dart |
| 019 | password_reset_request | 에러 원문 | 🟢 Low | `$error` 원문 노출 | ⏳ Reported | Phase 1 | password_reset_request_page.dart:78 |
| 020 | password_reset_verification | Supabase 직접호출 3건 | 🟠 High | signInWithOtp / verifyOTP / signOut 직접 호출 | ⏳ Reported | Phase 1 | password_reset_verification_page.dart:74,121,202 |
| 021 | password_reset_verification | KeyboardListener FocusNode | 🟡 Medium | 내부 `FocusNode()` dispose 안 됨 → 메모리 누수 가능 | ⏳ Reported | Phase 1 | password_reset_verification_page.dart:266 |
| 022 | password_reset_verification | OTP 타입 magiclink | 🟡 Medium | Supabase 권장은 `recovery`, `magiclink`는 의미상 부적절 | ⏳ Reported | Phase 1 | password_reset_verification_page.dart:123 |
| 023 | password_reset_verification | 에러 원문 | 🟢 Low | `e.toString()` 노출 | ⏳ Reported | Phase 1 | password_reset_verification_page.dart:164 |
| 024 | password_reset_verification | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 | ⏳ Reported | Phase 1 | password_reset_verification_page.dart |
| 025 | register_page | 파일 전체 | 🟠 High | **DEAD CODE** — 미사용 | ⏳ Reported | Phase 1 | register_page.dart:전체 |
| 026 | register_page | SafeArea | 🟡 Medium | SafeArea 미적용 | ⏳ Reported | Phase 1 | register_page.dart |
| 027 | register_page | 스크롤 없음 | 🟡 Medium | 작은 화면 overflow 위험 | ⏳ Reported | Phase 1 | register_page.dart |
| 028 | register_page | 이메일 옵션 없음 | 🟢 Low | 소셜만 제공 (dead code라 무관) | ⏳ Reported | Phase 1 | register_page.dart |
| 029 | terms_agreement | 뒤로가기 signOut 누락 | 🟠 High | `/onboarding/login` go하지만 session 유지 → redirect loop 가능 | ⏳ Reported | Phase 1 | terms_agreement_page.dart:47 |
| 030 | terms_agreement | 스크롤 없음 | 🟡 Medium | iPhone SE 작은 화면에서 overflow 위험 | ⏳ Reported | Phase 1 | terms_agreement_page.dart |
| 031 | terms_agreement | MaterialPageRoute | 🟡 Medium | "보기"에서 직접 push, GoRouter 시스템과 불일치 | ⏳ Reported | Phase 1 | terms_agreement_page.dart:136,196,254 |
| 032 | terms_agreement | 약관 하드코딩 | 🟢 Low | DB/원격 로딩 없이 소스에 박힘 — 개정 시 재배포 필요 | ⏳ Reported | Phase 1 | terms_agreement_page.dart |
| 033 | terms_detail | GoRouter 미사용 | 🟡 Medium | MaterialPageRoute로 push, 딥링크 미지원 | ⏳ Reported | Phase 1 | terms_detail_page.dart |
| 034 | terms_detail | 하단 버튼 Safe Area | 🟢 Low | home indicator 침범 가능 | ⏳ Reported | Phase 1 | terms_detail_page.dart:52 |
| 035 | terms_detail | 하드코딩 색상 orange | 🟢 Low | AppTheme 토큰 미사용 | ⏳ Reported | Phase 1 | terms_detail_page.dart:73 |
| 036 | terms_detail | Scroll physics | 🟢 Low | BouncingScrollPhysics 미적용 | ⏳ Reported | Phase 1 | terms_detail_page.dart |

---

## Phase별 버그 집계

| Phase | Critical | High | Medium | Low | 합계 |
|-------|---------|------|--------|-----|------|
| Pre-audit | 0 | 2 | 1 | 0 | 3 |
| Phase 1 (auth) | 0 | 8 | 11 | 14 | 33 |
| Phase 2 (onboarding) | - | - | - | - | - |
| Phase 3 (home) | - | - | - | - | - |
| Phase 4 (health) | - | - | - | - | - |
| Phase 5 (emotion) | - | - | - | - | - |
| Phase 6 (feed_hub) | - | - | - | - | - |
| Phase 7 (social) | - | - | - | - | - |
| Phase 8 (my) | - | - | - | - | - |
| Phase 9 (profile) | - | - | - | - | - |
| Phase 10 (pets) | - | - | - | - | - |
| Phase 11 (chat) | - | - | - | - | - |
| **합계** | **0** | **10** | **12** | **14** | **36** |

---

## 자주 발견되는 패턴 (Top Patterns)

> Phase 진행하며 발견된 공통 이슈 패턴을 누적 기록. 구조적 리팩토링 판단에 활용.

| 패턴 | 발생 횟수 | 예시 페이지 |
|------|---------|-----------|
| **Supabase 직접 호출 (아키텍처 위반)** | 4 | password_reset_new_password, request, verification, ai_history |
| **BouncingScrollPhysics 미적용 (iOS 감성)** | 6 | kakao_consent, login, 3x password_reset, terms_detail |
| **에러 원문 `e.toString()` 노출** | 3 | 3x password_reset_* |
| **DEAD CODE (미사용 파일)** | 2 | login_page.dart, register_page.dart |
| **SafeArea.bottom 미적용 (홈 인디케이터)** | 3 | kakao_consent, register, terms_detail |
| **하드코딩 색상 (AppTheme 토큰 미사용)** | 1 | terms_detail (orange) |
| **라우팅 경로 불일치** | 2 | post_card, login (`/profile/` vs `/user-profile/`, `/password-reset-*`) |
| **BLoC 이벤트에 빈 userId 전달** | 1 | feed_page |
| **EmptyState 오버플로우** | 1 | my_page |
| **GoRouter 대신 MaterialPageRoute** | 2 | terms_agreement (3곳), terms_detail |
| **signOut 누락 or 비동기 처리 미흡** | 2 | terms_agreement, password_reset_new_password |

---

## 이슈 상세 기록 템플릿

```markdown
### #NNN — [한줄 요약]

- **페이지:** lib/features/xxx/presentation/pages/yyy_page.dart
- **라인:** 123
- **심각도:** 🔴/🟠/🟡/🟢
- **수정 상태:** ⏳/🔨/✅/📌/❌
- **발견 Phase:** Phase N
- **발견일:** YYYY-MM-DD

**증상:**
[사용자 관점에서 어떤 증상이 나타나는지]

**재현 단계:**
1. ...
2. ...

**원인 분석:**
[코드 레벨에서 왜 이 증상이 나타나는지]

**제안 수정안:**
[어떻게 고칠지 — diff 또는 서술]

**영향 범위:**
[이 이슈가 다른 페이지/기능에 미치는 영향]
```

---

*마지막 업데이트: 2026-04-22 준비 완료*
