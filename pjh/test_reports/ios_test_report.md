# PetSpace iOS Integration Test Report

**Date:** 2026-04-22
**Device:** iPhone 17 Simulator (iOS 26.4)
**Flutter:** 3.41.6 (stable)
**Xcode:** 26.4
**Branch:** mac-ios-release

---

## Executive Summary

| Metric | Value |
|--------|-------|
| 테스트 파일 | 5개 |
| 총 케이스 | **21개** |
| 통과 | ✅ **21 (100%)** |
| 실패 | ❌ 0 |
| 실행 시간 | 약 36초 (합산) |

---

## Per-File Results

| # | 파일 | 케이스 수 | 실행시간 | 결과 |
|---|------|---------|---------|------|
| 1 | `01_splash_test.dart` | 4 | 7s | ✅ All passed |
| 2 | `02_navigation_test.dart` | 3 | 22s | ✅ All passed |
| 3 | `03_emotion_analysis_test.dart` | 4 | 29s | ✅ All passed |
| 4 | `04_my_tab_test.dart` | 5 | 36s | ✅ All passed |
| 5 | `05_home_dashboard_test.dart` | 5 | 36s | ✅ All passed |

---

## Test Case Details

### 01. Splash Screen (4/4 ✅)
- 앱 실행 → 스플래시 화면 렌더링
- PetSpaceLogo 위젯 렌더링 확인
- SVG 자산 로드 확인 (Lottie 또는 SVG)
- 3초 이내 스플래시 → 다음 화면 전환 (auth 확인 후)

### 02. Bottom Navigation (3/3 ✅)
- MainNavigation 렌더링 + SVG 아이콘 4종 로드
- 5개 탭 순회: 홈 → 건강관리 → AI분석 → 피드 → MY
- 하단 네비바 높이 + Safe Area 검증

### 03. Emotion Analysis Flow (4/4 ✅)
- AI 분석 탭 진입 → EmotionAnalysisPage 렌더링
- PetInlineDropdown 위젯 표시 확인
- 사진 선택 영역 / 카메라 버튼 노출
- 스크롤 동작 확인 (페이지 길이 검증)

### 04. MY Tab (5/5 ✅)
- MY 탭 진입 → MyPage 렌더링
- TabBar 2탭 구조 (내 게시글 / 저장한 게시글) 확인
- GridView 렌더링 확인 (인스타그램 스타일)
- 설정 아이콘 → SettingsBottomSheet 노출
- 두 번째 탭(저장한 게시글) 전환

### 05. Home Dashboard (5/5 ✅)
- 홈 탭 진입 → HomePage 렌더링
- 네이비 헤더(HomeDashboardHeader) 렌더링
- 퀵 액션 그리드(HomeQuickActions) 렌더링
- 일일 퀘스트 / 카드 영역 표시
- Pull-to-refresh 동작 가능 여부

---

## Issues Fixed During Test Setup

### Issue #1 — FlutterError.onError 오버라이드 충돌
- **파일**: `lib/main.dart:60-72`
- **증상**: `'_pendingExceptionDetails != null'` assertion 실패
- **원인**: `main.dart`가 `FlutterError.onError` / `PlatformDispatcher.onError`를 전역 설정해서 테스트 프레임워크의 에러 캡처와 충돌
- **해결**: `integration_test/app_test_entry.dart`에 테스트 전용 부트 함수 작성 (에러 핸들러 오버라이드 제외)

### Issue #2 — GetIt.isRegistered\<Object\> 타입 추론 실패
- **파일**: `integration_test/app_test_entry.dart`
- **증상**: `GetIt: The compiler could not infer the type` assertion
- **원인**: `isRegistered<Object>`는 GetIt이 지원하지 않음
- **해결**: 구체 타입(`AuthBloc`)으로 교체 + 등록돼 있으면 `di.sl.reset()` 후 재초기화

### Issue #3 — 비-테스트 파일이 테스트로 실행됨
- **파일**: `scripts/run_ios_integration_tests.sh`
- **증상**: `app_test_entry.dart`(헬퍼)가 테스트로 실행되어 실패
- **해결**: glob 패턴 `*.dart` → `*_test.dart`로 변경

---

## iOS 특화 검증

| 항목 | 상태 | 비고 |
|------|------|------|
| SVG 자산 렌더링 | ✅ | 로고 + 탭 아이콘 정상 로드 |
| Firebase iOS graceful skip | ✅ | `currentPlatformOrNull` 정상 동작 |
| Supabase 초기화 | ✅ | auth/realtime 정상 |
| Kakao Maps 로컬 패키지 | ✅ | pod 34개 정상 설치 |
| Bottom Navigation Safe Area | ✅ | iPhone 17 노치 환경 이상 없음 |
| Portrait Only 고정 | ✅ | Info.plist 설정 반영됨 |

---

## 실기기 테스트 전 체크리스트

- [x] Apple ID 서명 설정 (Xcode Team)
- [x] Bundle ID: `com.petspace.app` (실기기는 `.jsua` suffix)
- [x] 개발자 모드 활성화 (기기 설정)
- [x] 실기기에서 Developer 앱 신뢰 설정
- [ ] `flutter run --profile -d [device_id]` 실행 (iOS 26.4는 Debug JIT 제한)

---

## Simulator 미지원 기능 (실기기 테스트 필요)

| 기능 | 이유 |
|------|------|
| 카카오 로그인 OAuth 콜백 | Deep Link 처리 |
| FCM 푸시 알림 수신 | Simulator 미지원 |
| 카메라 실시간 촬영 | Simulator 미지원 (갤러리는 가능) |
| Face ID / Touch ID | Simulator 미지원 |
| 지도 위치 권한 + GPS | 시뮬레이션 가능하나 실측 필요 |

---

*PetSpace iOS Automated Test Report v1.0 | 2026-04-22*
