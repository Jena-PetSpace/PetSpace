# PetSpace iOS Simulator 테스트 최종 리포트

**실행 일시:** 2026-04-22
**Flutter:** 3.41.6 (stable)
**Xcode:** 26.4 (Build 17E192)
**Simulator:** iPhone 17 (iOS 26.4)
**Branch:** `mac-ios-release`

---

## 1. 테스트 개요

| 항목 | 값 |
|------|-----|
| 테스트 유형 | integration_test (통합 테스트) |
| 테스트 파일 | 5개 |
| 테스트 케이스 | 21개 |
| 실행 결과 | **21/21 통과 (100%)** |
| 빌드 시간 | pod install 포함 약 90초 |
| 테스트 실행 시간 | 약 36초 (합산) |

---

## 2. integration_test 결과

| # | 파일 | 케이스 수 | 실행시간 | 결과 |
|---|------|---------|---------|------|
| 1 | `01_splash_test.dart` | 4 | 7s | ✅ |
| 2 | `02_navigation_test.dart` | 3 | 22s | ✅ |
| 3 | `03_emotion_analysis_test.dart` | 4 | 29s | ✅ |
| 4 | `04_my_tab_test.dart` | 5 | 36s | ✅ |
| 5 | `05_home_dashboard_test.dart` | 5 | 36s | ✅ |

### 검증 항목

**01. Splash Screen**
- SplashPage 렌더링
- PetSpaceLogo 위젯
- SVG 자산 로드
- 3초 이내 다음 화면 전환

**02. Bottom Navigation**
- MainNavigation + SVG 아이콘 4종
- 5탭 순회 (홈→건강→AI→피드→MY)
- Safe Area 검증

**03. Emotion Analysis**
- EmotionAnalysisPage 렌더링
- PetInlineDropdown 표시
- 사진 선택 영역 노출
- 스크롤 동작

**04. MY Tab**
- MyPage 렌더링
- TabBar 2탭 구조
- GridView/빈 상태
- 설정 아이콘 → Bottom Sheet
- 저장한 게시글 탭 전환

**05. Home Dashboard**
- HomePage 렌더링
- HomeDashboardHeader
- HomeQuickActions
- 스크롤 영역
- Pull-to-refresh

---

## 3. 기능별 검증 결과

| 기능 | 상태 | 비고 |
|------|------|------|
| 스플래시 (네이티브 + Flutter 2단계) | ✅ | iOS 26.4 정상 |
| 하단 네비게이션 | ✅ | SVG + Safe Area 반영 |
| 감정분석 탭 UI | ✅ | PetInlineDropdown 정상 |
| MY 탭 + 설정 시트 | ✅ | Bottom Sheet 노출 확인 |
| 홈 대시보드 | ✅ | Header/QuickActions 전부 표시 |
| Firebase iOS graceful skip | ✅ | `currentPlatformOrNull` 정상 |
| Supabase 초기화 | ✅ | 세션 관리 정상 |
| Kakao Maps 로컬 패키지 | ✅ | 34 pods 설치 성공 |
| Portrait Only | ✅ | 가로모드 비활성 |

---

## 4. 수정된 오류 목록

### 테스트 인프라 설정 중 수정 (3건)

| # | 이슈 | 파일 | 해결 |
|---|------|------|------|
| 1 | FlutterError.onError 오버라이드 충돌 | `lib/main.dart` | 테스트 전용 부트 함수 `app_test_entry.dart` 작성 |
| 2 | GetIt isRegistered\<Object\> 타입 추론 실패 | `app_test_entry.dart` | `AuthBloc` 타입 + `di.sl.reset()` 조합 |
| 3 | 헬퍼 파일이 테스트로 실행됨 | `scripts/run_ios_integration_tests.sh` | glob 패턴 `*_test.dart` 한정 |

### 코드 품질 개선 (3건)

| # | 이슈 | 파일 | 변경 |
|---|------|------|------|
| 1 | 작성자명 오버플로우 (노치 iPhone) | `post_card.dart:153` | `maxLines: 1, overflow: ellipsis` 추가 |
| 2 | iOS home indicator 침범 | `chat_input_bar.dart:93` | `MediaQuery.padding.bottom` 반영 |
| 3 | Supabase 직접호출 (아키텍처 위반) | `ai_history_page.dart:130` | `TODO(arch):` 기록 |

---

## 5. 단점 이슈 (실기기 테스트 필요)

Simulator로는 검증 불가능한 항목들:

| 기능 | 이유 |
|------|------|
| 카카오 로그인 OAuth 콜백 | Deep Link URL Scheme 처리 |
| FCM 푸시 알림 수신 | Simulator는 APNS 미지원 |
| 카메라 실시간 촬영 | Simulator는 카메라 하드웨어 없음 |
| Face ID / Touch ID | Simulator 미지원 |
| 지도 GPS 실측 | 시뮬레이션은 가능하나 정확도 상이 |
| 네이티브 스플래시 첫 실행 체감 | 앱 아이콘 더블탭 시만 발생 |

---

## 6. 실기기 테스트 전 체크리스트

- [x] Apple ID 서명 설정 (Xcode Team: 25HD944XY3)
- [x] Bundle ID: `com.petspace.app`
- [x] 실기기 Developer Mode 활성화
- [x] VPN 및 기기 관리 → 개발자 앱 신뢰
- [ ] `scripts/run_ios_device.sh` 실행
- [ ] `flutter run --profile -d [device_id]` 실행 (iOS 26.4는 Debug JIT 제한)

---

## 7. 아직 수동 작업 필요한 항목 (향후 과제)

| 이슈 | 예상 공수 | 우선순위 |
|------|---------|---------|
| Supabase 직접호출 11개 → Repository 이전 | 8~12h | High |
| 하드코딩 색상 → AppTheme 토큰 교체 | 6~10h | Medium |
| Dark mode 색상 정의 완성 | 4~6h | Medium |
| BouncingScrollPhysics 전역 적용 | 2~3h | Low |
| 카카오 로그인 실기기 테스트 | 실기기 | High |
| FCM 푸시 알림 실기기 테스트 | 실기기 | High |

---

## 8. 생성된 산출물

```
pjh/
├── integration_test/
│   ├── app_test_entry.dart           (테스트 전용 부트)
│   ├── 01_splash_test.dart
│   ├── 02_navigation_test.dart
│   ├── 03_emotion_analysis_test.dart
│   ├── 04_my_tab_test.dart
│   └── 05_home_dashboard_test.dart
├── scripts/
│   ├── run_ios_integration_tests.sh  (시뮬레이터 자동 테스트)
│   └── run_ios_device.sh             (실기기 빌드/설치)
└── test_reports/
    ├── ios_test_report.md
    ├── final_report.md               (본 문서)
    └── logs/
        └── *.log (5개)
```

---

## 9. 향후 실기기 테스트 진행 순서

1. iPhone USB 연결 + Developer Mode 확인
2. `bash scripts/run_ios_device.sh`
3. 수동 검증:
   - 카카오/구글 로그인 OAuth 플로우
   - FCM 푸시 수신 (Firebase Console에서 발송)
   - 감정 분석 → Gemini API 실호출
   - 병원찾기 → Kakao REST API 실호출
   - 카메라 촬영 → 감정 분석
4. 결과를 `test_reports/device_test_report.md`로 기록

---

*PetSpace iOS Automated Test Final Report v1.0 | 2026-04-22*
