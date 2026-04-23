# lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 365줄

---

## 📍 페이지 개요

- **진입 라우트:** `/onboarding/profile` (app_router.dart:183)
- **BLoC 의존성:** 없음 — **ProfileService 직접 주입** (`di.sl<ProfileService>()`)
- **상위 탭:** 온보딩 플로우 (약관 동의 → 프로필 설정)
- **로그인 필요:** ✅ (로그인 직후)
- **Scaffold 구조:** AppBar + SafeArea → SingleChildScrollView → Form(Column)

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | IconButton | 43-52 | AppBar 뒤로가기 | `canPop()`이면 pop, 아니면 `/onboarding/login` | 동일 | ✅ |
| 2 | GestureDetector | 113-173 | 아바타 영역 탭 | `_pickProfileImage` → ImageSourcePicker (카메라/갤러리) | 동일 | ✅ |
| 3 | TextFormField | 202-222 | 닉네임 입력 (필수) | 2~20자 검증 | 동일 | ✅ |
| 4 | TextFormField | 224-235 | 자기소개 입력 (선택) | maxLength 150, maxLines 3 | 동일 | ✅ |
| 5 | ElevatedButton | 267-285 | "계속하기" | `_continue` → 이미지 업로드 + 프로필 저장 → `/onboarding/pet-registration` | 동일 | ✅ |

**상호작용 요소 합계:** 5개

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → AppBar + SafeArea → SingleChildScrollView → Padding → Form → Column

### 스크롤
- [x] `SingleChildScrollView` (line 62)
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 61)

### 리소스 관리
- [x] `_displayNameController.dispose()` (line 31)
- [x] `_bioController.dispose()` (line 32)
- `_profileService` — singleton이므로 dispose 불필요

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 | 아바타 없음 | `_buildAvatarPlaceholder` (camera 아이콘) |
| 이미지 선택됨 | `_selectedImageFile != null` | 로컬 파일 미리보기 |
| URL 있음 (카카오/구글 사진) | `_avatarUrl != null` | 네트워크 이미지 + errorBuilder |
| Loading | `_isLoading = true` | 버튼 내 로더 |
| 성공 | `_continue` 완료 | SnackBar + `/onboarding/pet-registration` |
| 실패 | catch (e) | 빨간 SnackBar |

---

## 🔗 외부 의존성

### API 호출
- `ProfileService.updateProfileImage(File)` — 이미지 업로드
- `ProfileService.updateProfile(displayName, bio, photoUrl)` — 프로필 저장

### 권한 요청
- 카메라 / 사진 라이브러리 (ImageSourcePicker 경유)

### Deep Link / 다른 페이지 이동
- 진입: `/onboarding/profile` (약관 동의 후 또는 로그인 BlocListener에서)
- 진출: `/onboarding/pet-registration` (성공), `/onboarding/login` (canPop 불가 시 뒤로)

---

## 🧪 시뮬레이터 동적 검증

**검증 가능** — 신규 가입 후 약관 동의하면 진입.

### 검증 포인트
- [ ] 시뮬레이터에서 아바타 탭 → ImageSourcePicker 다이얼로그 표시
- [ ] 시뮬레이터는 카메라 없음 → "사진 보관함" 옵션만 동작
- [ ] 닉네임 검증 에러 표시

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🟡 Medium | ProfileService 직접 주입 (BLoC 미경유) | line 23: `di.sl<ProfileService>()`로 Service 직접 주입. BLoC 패턴 일관성 위반. OnboardingBloc을 만들거나 AuthBloc에 편입 권장 |
| 2 | 🟡 Medium | 닉네임 중복 검사 없음 | validator는 길이만 확인. 회원가입 시 서버에서 체크하지만 즉시 피드백 없음 → UX 저하 |
| 3 | 🟡 Medium | 에러 원문 노출 | line 302, 352: `e.toString()` / `${e.toString()}` 그대로 노출 |
| 4 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 감성 |
| 5 | 🟢 Low | `_avatarUrl`이 초기에 null, 카카오/구글 기존 사진 로드 로직 없음 | line 25: `_avatarUrl` 초기값 null → 이미 로그인한 소셜 계정의 프로필 사진 미표시 |
| 6 | 🟢 Low | 이미지 업로드 진행률 UI 없음 | 업로드 중에는 `_isLoading`만 표시 — 대용량 파일 업로드 시 기다림 |

---

## ✅ 종합 평가

- **정상 동작:** 5/5
- **버그 발견:** 6건 (Medium 3 / Low 3)
- **심각도:** Medium
- **iOS 특화 문제:** 없음

### 권장 조치
- 다음 이터레이션: #1 (BLoC 도입), #2 (닉네임 중복 실시간 검사), #3 (에러 정제)
- 모니터링: #4, #5, #6
