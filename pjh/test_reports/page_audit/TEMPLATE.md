# [페이지 파일 경로]

> 예: lib/features/auth/presentation/pages/login_page.dart

**감사일:** YYYY-MM-DD
**감사자:** Claude Code
**페이지 LOC:** N줄

---

## 📍 페이지 개요

- **진입 라우트:** `/path/to/page`
- **진입 경로:** app_router.dart:L
- **BLoC 의존성:** XxxBloc, YyyBloc
- **상위 탭:** 홈/건강/AI분석/피드/MY/기타
- **로그인 필요:** ✅/❌
- **Scaffold 구조:** AppBar / body / FAB / BottomNav 유무

---

## 🎯 상호작용 요소 카탈로그

| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | ElevatedButton | 45 | "로그인 버튼" | signIn() 호출 후 /home | - | ⏳ |
| 2 | InkWell | 78 | "회원가입 링크" | /onboarding/register 이동 | - | ⏳ |
| 3 | TextField | 62 | 이메일 입력 | onChanged → email state | - | ⏳ |
| 4 | IconButton | 32 | AppBar 뒤로가기 | context.pop() | - | ⏳ |

**상태 범례:** ⏳ 미검증 / ✅ 정상 / ❌ 버그 / ⚠️ 개선필요

---

## 🎨 UI 요소

### 레이아웃 구조
- Scaffold → [describe outer structure]
- 주요 위젯 계층: Column/ListView/Stack 등

### 스크롤
- [ ] 스크롤 가능
- [ ] SingleChildScrollView / ListView / CustomScrollView
- [ ] BouncingScrollPhysics 적용 (iOS 네이티브 감성)

### Safe Area
- [ ] SafeArea 적용됨
- [ ] bottom: true/false
- [ ] 노치 / 홈 인디케이터 침범 위험 여부

### 오버플로우 위험 지점
- Row 내 고정 너비 + 가변 텍스트 → Flexible/Expanded 사용 확인
- Column 내 고정 높이 + 가변 높이 자식 → Expanded/SingleChildScrollView
- iPhone SE(375px), iPhone 17 Pro Max(430px) 양극단 시뮬레이션 필요

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| Initial | 페이지 진입 직후 | CircularProgressIndicator |
| Loading | 데이터 fetch 중 | Shimmer 또는 로더 |
| Loaded | 데이터 수신 완료 | 실제 콘텐츠 |
| Empty | 데이터 0건 | EmptyState 위젯 + 안내 문구 |
| Error | API 실패 | 재시도 버튼 + 에러 메시지 |
| Unauthenticated | 로그인 안 됨 | 로그인 안내 또는 리다이렉트 |

---

## 🔗 외부 의존성

### API 호출
- Supabase: [테이블명, RPC명]
- Gemini API: 호출 엔드포인트
- Kakao REST API: 사용 여부

### 권한 요청
- [ ] 카메라 (NSCameraUsageDescription)
- [ ] 사진 라이브러리 (NSPhotoLibraryUsageDescription)
- [ ] 위치 (NSLocationWhenInUseUsageDescription)
- [ ] 알림 (UserNotifications)
- [ ] 마이크

### Deep Link / 다른 페이지 이동
- 진입 가능 경로: [어디서 이 페이지로 오는가]
- 진출 경로: [이 페이지에서 어디로 가는가]

---

## 🧪 시뮬레이터 동적 검증

### 검증 방법
1. 시뮬레이터에서 해당 페이지로 라우팅
2. 카탈로그의 모든 상호작용을 순서대로 탭/입력
3. 기대 동작과 실제 동작 비교
4. 스크린샷: `test_reports/page_audit/{feature}/screenshots/{page_name}.png`

### 스크린샷
![screenshot](./screenshots/page_name.png)

---

## 🐛 발견된 이슈

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🔴/🟠/🟡/🟢 | 이슈 요약 | 상세 설명 + 재현 단계 |

> 이슈 발견 시 `BUG_LOG.md`에 추가 후 여기서는 요약만 기록.

---

## ✅ 종합 평가

- **정상 동작:** N/M
- **버그 발견:** N건
- **심각도:** Critical / High / Medium / Low / 없음
- **iOS 특화 문제:** 있음/없음

### 권장 조치
- 즉시 수정: [이슈 #N]
- 다음 이터레이션: [이슈 #N]
- 모니터링: [이슈 #N]
