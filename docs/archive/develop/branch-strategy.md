# 브랜치 전략 및 작업 정리

**PetSpace (펫페이스)** | Jena Team | 2026-04-01

---

## 브랜치 전략

### 브랜치 구조

| 브랜치 | 담당 기기 | 역할 |
|--------|----------|------|
| `main` | 공통 (안정 버전) | 프로덕션 배포용 안정 브랜치 |
| `mac-ios-release` | 맥미니 (macOS) | iOS 앱 준비, 전체 코드 수정, UI/UX 개선 |
| `win-android-release` | 윈도우 노트북 | Android Play Store 적용, UI/UX 테스트 |

### 작업 흐름

1. **맥미니**에서 `mac-ios-release` 브랜치에서 코드 수정 + UI/UX 개선 작업
2. 작업 완료 후 GitHub에 `push`
3. **윈도우 노트북**에서 `win-android-release` 브랜치 생성 (`mac-ios-release` 기반)
4. Android Play Store용 빌드 및 UI/UX 테스트
5. 양쪽 브랜치를 `main`에 merge하여 최종 배포

### 충돌 방지 규칙

- 작업 시작 전 항상 `git pull`로 최신 코드 동기화
- 각 기기별 담당 영역을 명확히 분리 (iOS 설정 vs Android 설정)
- 공통 코드(`lib/`) 수정은 `mac-ios-release`에서 먼저 진행 → `win-android-release`에서 merge
- 작업 끝나면 바로 `commit + push`하여 다른 기기에서 pull 가능하게 유지

---

## mac-ios-release 완료 작업 내역

### 코드 품질 개선

| 작업 항목 | 상세 내용 | 상태 |
|---------|---------|------|
| 컴파일 에러 확인 | 이전 커밋에서 이미 해결됨 확인 (emotion_trend_service, pet repository) | ✅ 완료 |
| deprecated API 수정 | `emotion_result_page.dart`에서 `withOpacity()` → `withValues(alpha:)` 2건 수정 | ✅ 완료 |
| print문/미사용 import 확인 | 이미 깨끗한 상태 확인 (`dart:developer.log` 사용 중) | ✅ 완료 |

### 앱 아이콘 최적화

| 항목 | 변경 전 | 변경 후 |
|------|--------|--------|
| 파일 크기 | 11.4 MB | **211 KB (55배 압축)** |
| 해상도 | 16,384 × 16,384 px | 1,024 × 1,024 px |
| 호환성 | 불필요하게 높은 해상도 | App Store / Play Store 최적 |

### iOS 출시 설정

- `Info.plist`: `ITSAppUsesNonExemptEncryption = false` 추가 (App Store 심사 간소화)
- `Info.plist`: `CFBundleName` → `펫페이스` 통일
- `Info.plist`: Kakao `LSApplicationQueriesSchemes` 화이트리스트 추가
- `Info.plist`: `NSAppTransportSecurity` 프로덕션 보안 설정
- `AndroidManifest.xml`: `usesCleartextTraffic=true` 제거 (보안 강화)

### UI/UX 개선 계획서 수립

665줄 분량의 상세 UI/UX 개선 계획서 작성 완료 (`UI_UX_IMPROVEMENT_PLAN.md`)

- 디자인 시스템 통일 (컬러, 타이포그래피, 스페이싱, 컴포넌트)
- 내비게이션 플로우 개선 (GoRouter 통일, 로딩 상태, 브레드크럼)
- 화면별 상세 개선사항 (Home, Emotion, Feed, Health, My, Onboarding)
- 4단계 구현 로드맵 (6주 예상 기간)

### 변경된 파일 목록

| 파일 경로 | 변경 내용 |
|---------|---------|
| `pjh/assets/icons/app_icon.png` | 11.4MB → 211KB 최적화 |
| `pjh/ios/Runner/Info.plist` | +28줄 (출시 설정 추가) |
| `pjh/android/app/src/main/AndroidManifest.xml` | cleartext 제거 (-1줄) |
| `pjh/lib/.../emotion_result_page.dart` | `withOpacity` → `withValues` (2건) |

---

## 윈도우 노트북 작업 가이드

### 1단계 — 프로젝트 세팅

윈도우 노트북의 VSCode 터미널에서 아래 명령어를 실행합니다.

```bash
cd ~/Desktop
git clone https://github.com/Jena-PetSpace/PetSpace.git
cd PetSpace
git fetch origin mac-ios-release
git checkout -b win-android-release origin/mac-ios-release
```

### 2단계 — Android Play Store 적용 작업

1. Android Studio에서 `pjh/` 폴더 열기
2. `flutter pub get` 실행하여 의존성 설치
3. `android/key.properties` 파일 생성 (keystore 경로 설정)
4. `flutter build appbundle --release`로 릴리즈 빌드
5. 에뮬레이터 및 실기기에서 UI/UX 변경사항 테스트
6. Play Console에 AAB 업로드 및 내부 테스트 트랙 배포

### 3단계 — key.properties 설정

`android/key.properties` 파일을 생성하고 아래 내용을 입력합니다.

```
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=petspace
storeFile=<keystore 파일 경로>
```

### 4단계 — UI/UX 테스트 체크리스트

| 테스트 항목 | 확인 사항 | 결과 |
|---------|---------|------|
| 온보딩 플로우 | 첫 실행 → 온보딩 → 홈 화면 정상 이동 | ☐ |
| 감정 분석 화면 | 사진 선택 → 분석 → 결과 표시 정상 동작 | ☐ |
| 피드/커뮤니티 | 게시물 작성, 좋아요, 댓글 정상 동작 | ☐ |
| 채팅 기능 | 채팅방 생성, 메시지 송수신, 나가기 정상 | ☐ |
| 건강관리 탭 | 건강 기록 추가/수정/삭제 정상 동작 | ☐ |
| 로그인/회원가입 | Google/Kakao 로그인, 계정 삭제 정상 동작 | ☐ |
| 푸시 알림 | FCM 푸시 알림 수신 및 탭 이동 정상 | ☐ |
| 다크모드 | 라이트/다크 모드 전환 시 UI 정상 표시 | ☐ |

---

## iOS 앱 테스트 방법 (맥미니)

### 방법 1 — iOS 시뮬레이터 (추천)

맥미니에 Xcode가 설치되어 있으므로 iOS 시뮬레이터로 바로 테스트할 수 있습니다.

```bash
cd ~/Desktop/PetSpace/pjh
flutter pub get
open ios/Runner.xcworkspace
flutter run -d "iPhone 16 Pro"
```

또는 Xcode에서 직접 Runner 타겟을 선택하고 시뮬레이터를 골라 실행할 수 있습니다.

### 방법 2 — 실제 iPhone 연결 테스트

iPhone을 USB로 맥미니에 연결하여 실기기 테스트도 가능합니다.

- Xcode → Window → Devices and Simulators에서 iPhone 확인
- Apple Developer 계정으로 Signing & Capabilities 설정
- `flutter run -d <device-id>`로 실행

### 방법 3 — TestFlight 배포 (출시 전 베타 테스트)

- `flutter build ipa --release`로 IPA 빌드
- Xcode → Product → Archive → Distribute App (App Store Connect)
- App Store Connect에서 TestFlight 빌드 확인 후 테스터 초대

---

## 다음 단계 (예정 작업)

| 우선순위 | 작업 | 상세 |
|--------|------|------|
| 🔴 높음 | UI/UX 개선 적용 | 디자인 시스템 통일, 화면별 수정 |
| 🔴 높음 | emotion_result_page 리팩토링 | 2,561줄 → 500~700줄 컴포넌트로 분할 |
| 🟡 중간 | 추가 기능 개발 | 북마크, 알림 내비게이션, 감정 결과 공유 |
| 🟡 중간 | 스플래시 화면 개선 | Lottie 애니메이션 추가, 브랜드 로고 표시 |
| 🟢 마지막 | 빌드 및 출시 | iOS IPA / Android AAB 빌드 및 스토어 제출 |
