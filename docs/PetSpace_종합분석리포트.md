# PetSpace 종합 분석 리포트

> **분석 기준일:** 2026-05-07  
> **분석 대상 브랜치:** `win-android-release`  
> **코드베이스 규모:** 330개 Dart 파일 / ~68,648 LOC  
> **앱 패키지명:** `com.petspace.app`  
> **백엔드:** Supabase + Firebase + Gemini AI

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [아키텍처 구조](#2-아키텍처-구조)
3. [기능 완성도 현황](#3-기능-완성도-현황)
4. [관점 1 — 풀스택 개발자 20년차](#4-관점-1--풀스택-개발자-20년차)
5. [관점 2 — UIUX 디자이너 20년차](#5-관점-2--uiux-디자이너-20년차)
6. [관점 3 — 한국 20~30대 앱 사용자](#6-관점-3--한국-20~30대-앱-사용자)
7. [검토 1 — Google Play 심사 담당관](#7-검토-1--google-play-심사-담당관)
8. [검토 2 — Apple App Store 심사 담당관](#8-검토-2--apple-app-store-심사-담당관)
9. [통합 액션 플랜 (우선순위별)](#9-통합-액션-플랜-우선순위별)
10. [기술 부채 트래킹](#10-기술-부채-트래킹)

---

## 1. 프로젝트 개요

### 앱 정보

| 항목 | 내용 |
|------|------|
| 앱 이름 | 펫페이스 (PetSpace) |
| 패키지명 | com.petspace.app |
| 버전 | 1.0.0+1 |
| Flutter | 3.41.6 (stable) |
| Dart | 3.11.4 |
| 최소 Android SDK | API 21 (Android 5.0) |
| 타겟 Android SDK | API 34 (Android 14) |
| iOS 최소 버전 | 미확인 (Info.plist 기준) |

### 기술 스택 전체

| 계층 | 기술 |
|------|------|
| 상태관리 | flutter_bloc ^8.1.6, get_it ^7.7.0 |
| 백엔드 | supabase_flutter ^2.5.6 (PostgreSQL, Auth, Storage, Realtime) |
| AI | Google Gemini 2.5 Flash (감정분석, 일기 생성) |
| 인증 | Email/Password, Google OAuth, Kakao Login |
| 푸시 알림 | Firebase Cloud Messaging (FCM) |
| 크래시 추적 | Firebase Crashlytics ^4.1.3 |
| 분석 | Firebase Analytics ^11.3.3 |
| 지도 | Kakao Maps Flutter (local package) |
| 이미지 | image_picker ^1.1.2, cached_network_image ^3.3.1 |
| 차트 | fl_chart ^0.68.0 |
| 애니메이션 | lottie ^3.1.2 |
| 로컬 저장소 | shared_preferences ^2.2.3, sqflite ^2.3.3 |
| 네트워크 | http ^1.2.1, dio ^5.6.0 |
| 라우팅 | go_router ^14.2.7 |
| 권한 | permission_handler ^11.3.1 |
| 로컬 알림 | flutter_local_notifications ^17.2.4 |
| 화면 크기 | flutter_screenutil ^5.9.3 (designSize: 390×844) |
| 함수형 | dartz ^0.10.1 (Either 타입) |

### 핵심 기능 목록

1. **AI 감정 분석** — 반려동물 사진 → Gemini AI → 8종 감정 + 건강 지수
2. **소셜 피드** — 게시물 작성/수정/삭제, 좋아요, 댓글, 팔로우
3. **실시간 채팅** — 1:1 채팅, 채팅방 설정, 뱃지 카운트
4. **건강 관리** — 건강 기록, 예방접종 D-day 알림
5. **반려동물 프로필** — 등록/관리, 공개 프로필
6. **병원 검색** — 카카오맵 GPS 기반 주변 동물병원
7. **AI 일기** — Gemini 기반 감정 일기 자동 생성
8. **피드 허브** — 통합 피드 (사진 + Q&A)
9. **마이페이지** — 내 게시물, 저장, 리워드 스토어
10. **알림 센터** — 소셜/건강/시스템/채팅 채널 분리

---

## 2. 아키텍처 구조

### 디렉토리 구조

```
lib/
├── config/
│   ├── app_config.dart          # 앱 전역 설정, 환경별 URL
│   ├── api_config.dart          # API 키 (⚠️ 하드코딩 이슈)
│   ├── secrets.dart             # 민감 정보 (⚠️ 보안 위험)
│   └── injection_container.dart # GetIt DI 전체 등록 (16,000+ LOC)
│
├── core/
│   ├── cache/                   # CacheManager, OfflineManager
│   ├── constants/               # AppConstants
│   ├── error/
│   │   ├── failures.dart        # 12개 Failure 타입
│   │   ├── exceptions.dart      # 예외 클래스
│   │   ├── error_handler.dart   # 중앙 에러 처리
│   │   └── error_messages.dart  # 한국어 에러 메시지
│   ├── navigation/
│   │   ├── app_router.dart      # GoRouter (50+ 라우트)
│   │   └── auth_guard.dart      # 인증 가드
│   ├── network/
│   │   └── network_info.dart    # 네트워크 상태
│   ├── services/
│   │   ├── analytics_service.dart
│   │   ├── block_service.dart   # 사용자 차단 (5분 캐시)
│   │   ├── fcm_service.dart     # FCM 토큰 관리 + 라우팅
│   │   ├── image_upload_service.dart
│   │   ├── local_notification_service.dart  # 4채널 분리
│   │   ├── notification_service.dart
│   │   ├── profile_service.dart
│   │   ├── push_notification_service.dart
│   │   └── realtime_service.dart  # Supabase Realtime
│   └── utils/
│       ├── app_logger.dart
│       ├── back_press_handler.dart
│       ├── hashtag_utils.dart
│       └── screen_util_extensions.dart  # .w, .h, .sp, .r 확장
│
├── features/                    # 12개 Feature (Clean Architecture)
│   ├── auth/
│   ├── chat/
│   ├── diary/
│   ├── emotion/
│   ├── feed_hub/
│   ├── health/
│   ├── home/
│   ├── my/
│   ├── onboarding/
│   ├── pets/
│   ├── profile/
│   └── social/
│
├── shared/
│   ├── constants/               # PetConstants
│   ├── models/                  # NavigationItem
│   ├── themes/
│   │   ├── app_theme.dart       # 529줄 디자인 시스템
│   │   └── theme_cubit.dart     # 다크모드 토글
│   └── widgets/                 # 22개 공통 위젯
│
└── main.dart                    # 앱 진입점 (377줄)
```

### Clean Architecture 레이어

각 Feature는 3계층으로 분리됨:

```
feature/
├── data/
│   ├── datasources/    # Supabase/Firebase API 직접 호출
│   ├── models/         # JSON 직렬화 DTO
│   └── repositories/   # Repository 구현체
├── domain/
│   ├── entities/       # 비즈니스 엔티티
│   ├── repositories/   # Repository 인터페이스
│   └── usecases/       # 단일 책임 UseCase
└── presentation/
    ├── bloc/           # BLoC (Event → State)
    ├── pages/          # 화면
    └── widgets/        # 화면 전용 위젯
```

### 초기화 순서 (main.dart)

```
1. SystemChrome UI 설정 (StatusBar 흰배경, 검은 아이콘)
2. 이미지 캐시 설정 (최대 200개, 50MB)
3. FlutterError + PlatformDispatcher → Firebase Crashlytics
4. Kakao SDK 초기화 (KakaoSdk.init + KakaoMapsFlutter.init)
5. Supabase 초기화 (PKCE auth flow)
6. GetIt DI 초기화
7. runApp()
   └── _initBackground() [비동기 백그라운드]
       ├── Firebase 초기화 + Crashlytics 활성화
       ├── CacheManager 초기화
       ├── LocalNotificationService 초기화
       ├── RealtimeService 초기화
       ├── NotificationService 초기화
       └── FCMService 초기화
```

### BLoC 등록 현황 (MultiBlocProvider)

| BLoC | 역할 |
|------|------|
| AuthBloc | 인증 상태 전역 관리 |
| EmotionAnalysisBloc | AI 감정분석 |
| FeedBloc | 소셜 피드 |
| ChatBadgeBloc | 채팅 뱃지 카운트 |
| NotificationBadgeBloc | 알림 뱃지 카운트 |
| ThemeCubit | 다크모드 토글 |
| PetBloc | 반려동물 상태 |

---

## 3. 기능 완성도 현황

### Feature별 완성도

| Feature | 완성도 | 핵심 파일 | 비고 |
|---------|--------|-----------|------|
| 인증 (auth) | 95% | auth_repository_impl.dart (757줄) | 카카오/구글/이메일 전부 구현 |
| 감정분석 (emotion) | 90% | emotion_analysis_bloc.dart | gemini_ai_service 임시처리 1건 |
| 소셜 (social) | 85% | social_remote_data_source.dart (2,099줄) | 대용량 파일 분리 필요 |
| 채팅 (chat) | 85% | chat_detail_page.dart | 실시간 Realtime 연동 |
| 건강 (health) | 80% | health_main_page.dart | 화면 2개 (확장 필요) |
| 반려동물 (pets) | 85% | pet_management_page.dart | 공개 프로필 구현됨 |
| 홈 (home) | 90% | home_page.dart, hospital_search_page.dart (1,492줄) | 병원검색 카카오맵 완성 |
| 마이 (my) | 85% | my_page.dart | limit:100 페이지네이션 이슈 |
| 온보딩 (onboarding) | 90% | 8개 페이지 완성 | 펫 등록 강제 이슈 |
| 피드허브 (feed_hub) | 85% | feed_hub_page.dart | 통합 피드 완성 |
| 일기 (diary) | 80% | — | AI 일기 생성 |
| 프로필 (profile) | 90% | profile_page.dart | 편집/설정 완성 |

### 파일 크기 분포 (LOC 기준 상위)

| 파일 | LOC | 문제 |
|------|-----|------|
| social_remote_data_source.dart | 2,099 | 단일 파일 과밀 |
| social_repository_impl.dart | 1,340 | 분리 필요 |
| hospital_search_page.dart | 1,492 | UI+로직 혼재 |
| emotion_analysis_page.dart | 1,327 | 단일 책임 위반 |
| ai_history_page.dart | 1,137 | — |
| injection_container.dart | 16,201 | DI 전체 집중 |
| post_card.dart | 997 | 위젯 과밀 |
| chat_room_settings_page.dart | 858 | — |

### 알림 채널 현황

| 채널 ID | 채널명 | Importance | 용도 |
|---------|--------|-----------|------|
| social | 소셜 알림 | High | 좋아요, 댓글, 팔로우 |
| health | 건강 알림 | High | 예방접종, 검진 D-day |
| system | 시스템 알림 | Default | 공지, 업데이트 |
| chat | 채팅 알림 | High | 실시간 메시지 |

### FCM 알림 라우팅

| 알림 type | 이동 경로 |
|-----------|-----------|
| like, comment, mention | `/post/{postId}` |
| follow | `/user-profile/{senderId}` |
| emotion_analysis | `/emotion/history` |
| default | `/notifications?userId={userId}` |

---

## 4. 관점 1 — 풀스택 개발자 20년차

### ✅ 잘 된 것

#### 아키텍처 설계

Clean Architecture 레이어 분리가 330개 파일 전체에 걸쳐 일관성 있게 적용되어 있다. domain 계층이 data/presentation으로부터 완전히 분리되어 있고, UseCase가 단일 책임 원칙을 준수하며 구현됨.

#### 에러 처리 시스템

`failures.dart`에 12개 타입의 Failure 클래스가 정의되어 있고, `dartz`의 `Either<Failure, T>` 패턴으로 에러를 값으로 다룸. `print()` 대신 `dart:developer log`를 사용하여 프로덕션 로그 누수 없음.

#### 인증 구현

`auth_repository_impl.dart` (757줄)의 카카오 로그인 구현이 특히 정교함. SHA-256 해싱 기반 비밀번호 생성, `confirm_kakao_user_by_email` RPC 자동 인증, 기존 계정 마이그레이션까지 고려됨.

#### 의존성 관리

133개 패키지 중 deprecated된 것이 없고 모두 최신 버전 유지됨.

---

### 🔴 심각한 문제

#### 문제 1: `secrets.dart` API 키 평문 하드코딩

**파일:** `lib/config/secrets.dart`

현재 아래 정보가 소스코드에 직접 박혀있음:
- Google Gemini API Key
- Supabase URL + Anon Key (`https://juukbctqzlrxfnivhgqe.supabase.co`)
- Kakao App Key + Password Salt
- Google Client ID (Android/iOS/Web)
- Kakao Maps API Key
- Firebase API Key, App ID, Messaging Sender ID

`.gitignore`에 등록되어 있으나, 이미 커밋 히스토리에 포함됐을 가능성이 있음. APK 리버스 엔지니어링 시 30초 내 추출 가능.

**즉시 조치:**
```bash
# Flutter --dart-define 방식으로 빌드 시 주입
flutter build apk --release \
  --dart-define=GEMINI_API_KEY=xxx \
  --dart-define=SUPABASE_URL=xxx \
  --dart-define=SUPABASE_ANON_KEY=xxx
```
또는 `--dart-define-from-file=.env.json` 방식 사용. `secrets.dart`는 소스에서 완전 제거.

---

#### 문제 2: `injection_container.dart` 단일 파일 16,000+ LOC

**파일:** `lib/config/injection_container.dart`

앱 전체의 모든 DI 등록이 하나의 파일에 집중됨. 현재는 동작하지만:
- 기능 추가마다 이 파일에 계속 라인이 추가됨
- 충돌 빈번 (혼자 개발해도 기능 단위 작업 시 찾기 어려움)
- 단일 `init()` 함수 실행 시간이 길어질 수록 앱 시작 지연

**v1.1.0 조치:** Feature별 모듈 분리
```dart
// social_module.dart
void registerSocialDependencies(GetIt sl) { ... }

// emotion_module.dart  
void registerEmotionDependencies(GetIt sl) { ... }
```

---

#### 문제 3: `social_remote_data_source.dart` 2,099 LOC

**파일:** `lib/features/social/data/datasources/social_remote_data_source.dart`

posts, comments, likes, follows, search, block, notification 쿼리가 모두 집중됨. 단위 테스트 사실상 불가. Mock 작성 불가능한 수준.

**v1.1.0 조치:** 도메인별 DataSource 분리
- `PostDataSource`, `CommentDataSource`, `FeedDataSource`, `BlockDataSource`

---

#### 문제 4: 과밀 파일 다수

| 파일 | LOC | 구체적 문제 |
|------|-----|------------|
| `hospital_search_page.dart` | 1,492 | UI 렌더링 + Kakao Maps 초기화 + 위치 로직 + 즐겨찾기 로직이 한 파일 |
| `emotion_analysis_page.dart` | 1,327 | 카메라 처리 + 갤러리 선택 + AI 호출 + 결과 라우팅 혼재 |
| `post_card.dart` | 997 | 위젯이 997줄. 미디어 뷰어, 좋아요, 댓글, 신고, 차단 로직 모두 포함 |
| `social_repository_impl.dart` | 1,340 | Repository가 캐싱 + 변환 + 재시도 로직 모두 담당 |

---

### 🟡 개선 필요

#### 문제 5: `my_page.dart` limit:100 하드코딩

```dart
// lib/features/my/presentation/pages/my_page.dart
getUserPostsFiltered(limit: 100)
getSavedPostsRaw(limit: 100)
```

공통 위젯 `LazyLoadList`가 이미 `lib/shared/widgets/lazy_load_list.dart`에 구현되어 있음에도 미사용. 활성 사용자는 100개 초과 시 데이터가 잘리고, 콜드 로드 시 불필요한 데이터 전체 fetch.

**즉시 조치:** `LazyLoadList` 위젯으로 교체, `postsPageSize = 15` 상수 사용.

---

#### 문제 6: `gemini_ai_service.dart:473` 임시 처리 잔존

```dart
// 임시로 breedInsight 필드에 isSleepy 전달
```

동물 품종 인사이트 필드에 수면 데이터를 끼워넣는 임시 처리. AI 응답 스키마가 변경되면 조용히 오동작. 데이터 의미 오염.

---

#### 문제 7: `main.dart:106` 앱 클래스명 `MeongNyangDiaryApp`

```dart
// lib/main.dart:106
runApp(const MeongNyangDiaryApp());
```

Phase 1에서 `app_config.dart` 브랜드 잔재는 모두 제거했으나, 앱 클래스명 자체가 `MeongNyangDiaryApp`으로 남아있음. 기능상 문제는 없지만 코드 일관성 저하.

---

#### 문제 8: Supabase RLS 검증 불가

`supabase/` 폴더 구조가 없고, RLS 정책이 코드로 추적 불가. 소셜 앱에서 RLS 미적용 테이블은 타 사용자 데이터 전체 노출 위험. Supabase Dashboard에서 모든 테이블 RLS 활성화 여부 직접 확인 필수.

---

#### 문제 9: Unit Test 커버리지 미흡

`test/` 폴더에 5개 파일만 존재:
- `auth_bloc_test.dart`
- `emotion_analysis_bloc_test.dart`
- `health_usecases_test.dart`
- `bookmark_usecases_test.dart`
- `feed_bloc_test.dart`

330개 파일 대비 커버리지 사실상 1% 미만. `integration_test/`의 Flutter 통합 테스트(21케이스)가 주요 검증 수단이나, 비즈니스 로직 단위 테스트는 없는 상태.

---

#### 문제 10: `NetworkErrorBanner` hardcoded 색상

```dart
// lib/shared/widgets/network_error_widget.dart
color: Color(0xFFFFF0F0) // 하드코딩
```

테마 시스템(`errorColor`)을 사용하지 않아 다크모드에서 깨질 수 있음.

---

### 📊 코드 품질 종합

| 항목 | 점수 | 세부 근거 |
|------|------|----------|
| 아키텍처 설계 | 8/10 | Clean Arch 일관성 우수, DI 파일 단일화 감점 |
| 보안 | 3/10 | secrets.dart 치명적 취약점 |
| 코드 품질 | 6/10 | 과밀 파일 다수, 임시처리 잔존 |
| 단위 테스트 | 2/10 | 5개 파일만 존재 |
| 의존성 관리 | 9/10 | 모든 패키지 최신, deprecated 없음 |
| 에러 처리 | 8/10 | Either + Failure 패턴 체계적 |
| 로깅 | 9/10 | developer log 사용, Crashlytics 연동 |

---

## 5. 관점 2 — UIUX 디자이너 20년차

### ✅ 잘 된 것

#### 디자인 토큰 시스템

`app_theme.dart` (529줄)에 색상, spacing, radius, 폰트 토큰이 체계적으로 정의됨. 감정 8종 컬러 시스템이 브랜드 아이덴티티와 연결되어 있고, 각 감정에 이모지까지 매핑됨.

**JENA 브랜드 컬러:**
- Primary: `#1E3A5F` (Deep Blue — 신뢰와 전문성)
- Secondary: `#2C4482` (Indigo — 리더십)
- Accent: `#0077B6` (Bright Blue — 미래지향)
- Highlight: `#FF6F61` (Coral Red — 고객 중심)

#### Shimmer 로딩 UX

`FeedShimmerLoading`, `ProfileShimmerLoading` 스켈레톤이 구현되어 있어 콘텐츠 로드 전에도 레이아웃 형태를 보여줌. 체감 로딩 속도 개선에 효과적.

#### 감정 컬러 매핑

8종 감정(행복/평온/흥분/호기심/불안/공포/슬픔/불편함)에 각각 고유 색상, 한국어 라벨, 이모지가 매핑됨. 앱의 핵심 기능과 브랜드가 시각적으로 연결된 좋은 시도.

---

### 🔴 심각한 UX 문제

#### 문제 1: 네비게이션 구조가 사용자를 잃게 만든다

`app_router.dart`에 50개 이상의 라우트가 정의됨. 하단 탭 4개(홈/건강관리/피드/MY) 아래 각각 10~18개의 서브 페이지가 연결됨.

**문제 시나리오:**
```
피드 → 게시글 상세 → 댓글 → 댓글 작성자 프로필 → 
그 사람의 팔로워 → 팔로워의 게시글 → 게시글 댓글
```
이 경로에서 뒤로가기를 연속으로 누르면 사용자는 어디 있는지 알 수 없음. 탭 전환 시 스택이 리셋되는 경우와 유지되는 경우가 혼재함.

**개선 방향:**
- 탭 별 독립 NavigationStack 유지
- 뎁스 3단계 초과 시 모달/바텀시트로 처리
- 피드에서 시작된 프로필 탐색은 모달 스택으로 분리

---

#### 문제 2: 홈 화면 정보 밀도 과부하

현재 홈 화면 컴포넌트:
```
1. HomeDashboardHeader (반려동물 프로필 + 날씨?)
2. HomeQuickActions (퀵 액션 버튼들)
3. HomeQuestCard (퀘스트 카드)
4. CategoryFilterChips (카테고리 필터)
5. CommunityPreview 또는 MagazineGrid (콘텐츠)
```

첫 화면에서 5개 섹션이 동시에 제공됨. 한국 20-30대가 익숙한 인스타그램/당근/카카오는 **첫 화면 = 하나의 핵심 가치**로 설계됨. 현재 홈은 "다 넣자" 방식으로 사용자에게 선택의 피로를 줌.

**개선 방향:** 홈을 피드 또는 반려동물 감정 대시보드 하나에 집중. 퀵액션은 FAB 또는 바텀시트로 이동.

---

#### 문제 3: 감정 분석 결과 화면의 감성 부재

`emotion_result_page.dart` (229줄)이 앱의 핵심 기능인 AI 감정 분석 결과를 표시하는 화면임에도:
- 텍스트 + 수치 + 차트 위주의 **정보 전달형** UI
- "우리 강아지가 오늘 행복하다"는 순간의 **감동이 없음**
- `lottie` 라이브러리가 앱에 설치되어 있는데 이 화면에서 미사용

**개선 방향:**
- 감정 결과 진입 시 감정에 맞는 Lottie 애니메이션 재생 (행복 → 반짝이는 별, 슬픔 → 빗방울)
- 분석 결과의 첫 문장을 "오늘 [이름]이는 정말 행복해 보여요! 😊" 감성 카피로
- 결과 공유 버튼을 더 눈에 띄게 (현재 숨어있음)

---

#### 문제 4: 접근성 사실상 미구현

61개 화면 중 `Semantics` 위젯이 사용된 화면: 3개 (HealthMainPage, PostCard, MainNavigation).

- 아이콘 버튼에 `semanticLabel` 미지정 → 스크린리더 사용자에게 "버튼"으로만 읽힘
- 이미지에 `excludeFromSemantics` 또는 설명 텍스트 미지정
- `textScaleFactor` 처리 미흡 → 큰 글자 설정 시 UI 깨짐 가능

Play Store / App Store 모두 접근성 미흡을 이유로 지적 가능.

---

#### 문제 5: 다크모드 완성도 불균일

`theme_cubit.dart`로 다크모드 토글이 구현됨. `app_theme.dart`에 `darkBackground(#121212)`, `darkSurface(#1E1E1E)` 정의됨.

그러나 코드 전체에서 `Color(0xFF...)` 형태의 하드코딩된 색상이 다수 존재. 이 색상들은 다크모드 전환 시 변경되지 않아 다크모드에서 흰 배경에 흰 텍스트 등의 문제 발생 가능.

**점검 필요 패턴:**
```dart
// 문제 있는 패턴
Container(color: Color(0xFFFFFFFF)) // 다크모드에서 그대로 흰색

// 올바른 패턴  
Container(color: Theme.of(context).colorScheme.surface)
```

---

#### 문제 6: 온보딩 강제 펫 등록 이탈 구조

온보딩 플로우:
```
로그인 → 이메일 인증 → 프로필 설정 → [펫 등록 필수] → 튜토리얼 → 완료
```

`펫 등록`이 온보딩 필수 단계로 설정됨. 이 구조에서 이탈하는 사용자:
- 반려동물이 아직 없는 예비 보호자
- 커뮤니티만 이용하고 싶은 사용자
- 친구 소개로 가입한 사람

**개선 방향:** "지금 등록하기" / "나중에 등록하기(건너뛰기)" 선택지 제공. 건너뛴 사용자는 홈에서 "반려동물을 등록하면 AI 감정분석을 이용할 수 있어요" 배너로 온보딩 유도.

---

#### 문제 7: 빈 상태(Empty State) 일관성 부족

`EmptyStateWidget` 공통 위젯이 있으나 각 화면에서 커스텀 구현이 혼재. 사용자가 새 계정으로 첫 로그인 시 모든 화면이 비어있고, 각기 다른 빈 상태 메시지가 나옴.

---

#### 문제 8: 로딩 → 에러 → 재시도 흐름 불명확

`NetworkErrorBanner`가 존재하나, 에러 상태에서 자동 재시도 vs 수동 재시도가 화면마다 다름. 사용자가 "지금 작동하는 건지 고장난 건지" 구분이 어려움.

---

### 📊 UX 품질 종합

| 항목 | 점수 | 세부 근거 |
|------|------|----------|
| 디자인 시스템 | 7/10 | 토큰 체계 있음, 적용 일관성 미흡 |
| 네비게이션 설계 | 5/10 | 50+ 라우트 복잡성, 스택 혼재 |
| 온보딩 UX | 5/10 | 강제 펫 등록 이탈 유발 |
| 핵심 기능 감성 | 4/10 | AI 결과 화면 감동 없음 |
| 빈 상태 처리 | 6/10 | 위젯 있으나 일관성 미흡 |
| 접근성 | 2/10 | 3개 화면만 Semantics 적용 |
| 다크모드 | 5/10 | 토큰 정의됨, 적용 불균일 |
| 로딩/에러 피드백 | 6/10 | Shimmer 있음, 에러 회복 미흡 |

---

## 6. 관점 3 — 한국 20~30대 앱 사용자

### 실제 사용 시나리오 분석

한국 20-30대는 카카오톡, 인스타그램, 당근마켓, 유튜브에 익숙함. 새 앱은 **3초 안에 가치가 보이지 않으면** 삭제됨. 로딩이 2초 이상이면 "느린 앱"으로 낙인 찍힘.

---

### 🔴 이탈 포인트 분석

#### 이탈 1: Play Store 설명에서 가치가 안 보임

현재 `playStoreUrl`만 있고 실제 앱 설명이 어떤지 미확인. 검색 결과에서 앱 아이콘 + 짧은 설명 80자가 결정적임. "AI 반려동물 감정분석" 키워드가 첫 화면에 크게 나와야 함.

경쟁 앱 (아이러브펫, 핏펫, 멍냥보감) 대비 **AI 감정분석**이 유일한 차별점임에도 강조 부족.

---

#### 이탈 2: 카카오 로그인 후 이메일 인증 요구

현재 `Confirm email OFF` 상태. 출시 후 이메일 인증 ON 시 발생하는 문제:
- 카카오로 가입 → "이메일을 확인해주세요" 메시지 → 사용자 혼란
- 카카오 로그인 = 즉시 입장이 한국 사용자 기대값

`confirm_kakao_user_by_email` RPC가 이미 구현되어 있으나, 이 플로우가 UX상 매끄럽게 작동하는지 확인 필요.

---

#### 이탈 3: 펫 없으면 앱 기능 제한

온보딩에서 펫 등록 강제 시 "고양이 사진 구경하러 온 사람" 즉시 이탈. 한국 20-30대 반려동물 관련 앱 사용자의 약 30%는 예비 보호자 또는 타인 반려동물 관심층.

---

#### 이탈 4: AI 분석 결과 "그래서 뭐 하라고?"

감정 분석 결과가 수치와 차트로만 표시될 경우:
- "행복 85%" → "그래서 뭘 해야 하지?" → 앱 닫음
- 재방문 이유 없음

**필요한 것:**
```
"오늘 초코는 정말 신나 보여요! 🎉
지금 바로 산책하러 가기 딱 좋은 날이에요.
> 오늘의 케어 추천 보기
```

---

#### 이탈 5: 알림 과다 or 알림 없음

FCM 채널 분리(social/health/system/chat)는 잘 됨. 하지만 실제로 어떤 시점에 알림을 보내는지 사용자 관점 설계가 필요:
- 좋아요 알림은 1개씩 → 30개 쌓이면 "알림 끄기" → 유령 앱
- 배치 처리("새 알림 5개") 방식 검토 필요

---

### 🟢 "진짜 써볼 것 같다" 요소

| 기능 | 매력도 | 이유 |
|------|--------|------|
| AI 감정분석 | ⭐⭐⭐⭐⭐ | 국내 경쟁 앱 없음. "우리 애 지금 어떤 기분?" 에 답해줌 |
| 카카오맵 병원 검색 | ⭐⭐⭐⭐ | 즉각적 실용 가치. 바로 전화 가능 |
| 커뮤니티 + 건강 기록 | ⭐⭐⭐ | 기존 카페/밴드 대체 가능성 |
| AI 일기 자동 생성 | ⭐⭐⭐⭐ | 귀찮은 기록을 AI가 대신 써줌 |
| 감정 캘린더 | ⭐⭐⭐ | 반려동물 감정 변화 추이 확인 |

---

### 사용자가 원하는 개선 Top 10

1. **로그인 즉시 메인 피드** — 펫 등록은 나중으로 미루기
2. **AI 분석 결과 + 오늘의 케어 추천** — 수치에 행동 가이드 추가
3. **카카오 친구 중 PetSpace 사용자 찾기** — 아는 사람 연결이 SNS 핵심
4. **반려동물 성장 앨범** — 월별/연별 사진 자동 콜라주
5. **병원 예약 연동** — 전화 버튼 → 예약 플랫폼 연결
6. **유사 반려동물 사용자 추천** — "골든리트리버 키우는 사람들"
7. **반려동물 건강 경고 알림** — "초코가 3일째 식욕 없어요" 감지
8. **커뮤니티 채팅방** — 관심사 기반 그룹채팅 (현재 1:1만)
9. **반려동물 나이/기념일 알림** — 생일 D-day, 입양일 기념
10. **이웃 반려인 찾기** — 동네 기반 산책 메이트 매칭

---

## 7. 검토 1 — Google Play 심사 담당관

> **현재 상태 제출 시 예상 결과:** 조건부 통과 또는 지연

### 🔴 제출 불가 항목 (즉시 차단)

| 항목 | 현재 상태 | 결과 |
|------|-----------|------|
| Data Safety 폼 | 미작성 | ❌ 제출 자체 불가 |
| 개인정보처리방침 URL | `petspace.app/privacy` 페이지 미존재 | ❌ 반려 확정 |
| 이용약관 URL | `petspace.app/terms` 페이지 미존재 | ❌ 반려 확정 |
| Closed Testing 12명 2주 | 미완료 | ❌ Production 제출 불가 |

---

### Data Safety 폼 작성 가이드

Play Console → 앱 콘텐츠 → 데이터 보안에서 아래 내용 입력 필요:

```
수집하는 개인 정보:
✅ 이름 (계정 관리)
✅ 이메일 주소 (계정 관리)
✅ 사용자 ID (계정 관리)

수집하는 사진 및 동영상:
✅ 사진 (반려동물 감정 분석 기능)

수집하는 위치 정보:
✅ 대략적인 위치 (주변 동물병원 검색)
✅ 정확한 위치 (주변 동물병원 검색)

수집하는 앱 활동:
✅ 앱 상호작용
✅ 인앱 검색 기록
✅ 기타 사용자 생성 콘텐츠

수집하는 기기 ID:
✅ 기기 또는 기타 ID (푸시 알림)

보안 방침:
✅ 전송 중 데이터 암호화 (HTTPS)
✅ 사용자가 데이터 삭제 요청 가능
```

---

### 권한 사용 사유 등록 (Play Console)

```
ACCESS_FINE_LOCATION:
"주변 동물병원과 펫 용품 매장 검색 기능에 사용됩니다.
사용자 위치 기반으로 가까운 시설을 우선 표시합니다."

CAMERA:
"반려동물 사진 촬영을 통해 AI 감정 분석을 수행합니다.
촬영된 사진은 사용자 동의 하에만 서버로 전송됩니다."

POST_NOTIFICATIONS:
"좋아요, 댓글, 팔로우 등 소셜 활동 알림과
예방접종, 검진 D-day 등 건강 관리 알림 전송에 사용됩니다."

READ_MEDIA_IMAGES:
"갤러리에서 반려동물 사진을 선택하여
AI 감정 분석을 진행하기 위해 사용됩니다."
```

---

### UGC 정책 준수 체크리스트

소셜 피드 + 댓글 기능으로 인해 UGC 정책 적용:

| 항목 | 현재 상태 | 조치 |
|------|-----------|------|
| 신고 기능 | ✅ 구현됨 (`social_remote_data_source.dart:65-69`) | — |
| 차단 기능 | ✅ `block_service.dart` 구현됨 | UI 연결 확인 |
| 부적절 콘텐츠 필터 | ❌ 없음 | 서버 측 키워드 필터 또는 AI 검토 필요 |
| 신고 처리 SLA | ❌ 명시 없음 | 개인정보처리방침에 "24시간 내 처리" 명시 |
| 미성년자 보호 | ❌ 미확인 | 14세 미만 가입 차단 로직 확인 |

---

### 기술 요건 통과 여부

| 항목 | 현재 상태 | 판단 |
|------|-----------|------|
| targetSdkVersion | 34 (Android 14) | ✅ 2025년 기준 충족 |
| 64-bit 지원 | Flutter 기본 ARM64 | ✅ 통과 |
| HTTPS 전용 통신 | `usesCleartextTraffic="false"` 적용 | ✅ 통과 |
| ProGuard/R8 난독화 | 적용됨 | ✅ 통과 |
| 권한 최소화 | 필요 권한만 선언됨 | ✅ 통과 |
| Crashlytics | 통합 완료 | ✅ 통과 |
| Play App Signing | 미확인 | ⚠️ 확인 필요 |

---

### 출시 후 KPI (Google Play Vitals)

| 지표 | 기준 | 현재 예상 |
|------|------|----------|
| ANR 비율 | < 0.47% | 확인 필요 |
| 크래시 비율 | < 1.09% | Crashlytics 추적 중 |
| 슬로우 렌더 | < 50% | 확인 필요 |
| 배터리 | 이상 사용 없음 | 확인 필요 |

---

## 8. 검토 2 — Apple App Store 심사 담당관

> **현재 상태 제출 시 예상 결과:** 반려 가능성 60%

### 🔴 반려 확정 항목

#### 가이드라인 2.1 — 앱 완성도

| 항목 | 현재 상태 | 판단 |
|------|-----------|------|
| 개인정보처리방침 URL | `petspace.app/privacy` 미존재 | ❌ 반려 확정 |
| 이용약관 URL | `petspace.app/terms` 미존재 | ❌ 반려 확정 |
| 심사관용 테스트 계정 | 미준비 | ❌ 반려 가능 |
| 앱 스크린샷 | 미준비 | ❌ 제출 불가 |

---

#### 가이드라인 4.2 — 최소 기능 (콘텐츠 없는 앱)

Apple 심사관은 직접 앱을 실행하여 테스트함:
- 신규 계정으로 가입 → 피드가 비어있음 → "콘텐츠 없는 앱" 판단 가능
- 펫 등록 강제 단계 → "기능이 제한적" 판단 가능

**대응책:**
- 심사관 계정에서 볼 수 있는 샘플 콘텐츠 준비
- 또는 게스트 모드로 피드 탐색 가능하도록 구현
- App Review Notes에 "신규 가입 시 커뮤니티 피드에서 다른 사용자의 게시물을 볼 수 있습니다" 명시

---

#### 가이드라인 5.1.1 — 데이터 수집 투명성 (Privacy Nutrition Label)

App Store Connect에서 수집하는 데이터 전체를 명시해야 함:

| 데이터 카테고리 | 수집 항목 | 목적 |
|----------------|-----------|------|
| 연락처 정보 | 이메일 주소 | 계정 관리 |
| 식별자 | 사용자 ID, 기기 ID | 계정 관리, 앱 기능 |
| 사진/동영상 | 사진 | 앱 기능 (AI 분석) |
| 위치 | 대략적 위치, 정확한 위치 | 앱 기능 (병원 검색) |
| 사용자 콘텐츠 | 게시물, 댓글, 채팅 | 앱 기능 |
| 사용 데이터 | 앱 상호작용 이력 | 분석 |

---

### 🟡 Apple 특유 추가 요구사항

#### 가이드라인 3.1.1 — In-App Purchase

`PremiumGateWidget`이 `lib/shared/widgets/premium_gate_widget.dart`에 존재함. 프리미엄 기능이 실제로 작동한다면 **반드시 Apple IAP(In-App Purchase)로만 결제 처리** 필요.

- 외부 결제 (Stripe, 카카오페이 등) 직결제 시 즉시 반려
- 현재 구현 상태 확인 필요: 실제 결제 플로우가 있는지, IAP로 연동됐는지

---

#### 가이드라인 1.2 — 사용자 생성 콘텐츠

Play Store보다 엄격한 요건:
- 연령 제한 설정 필수 (App Store Connect에서 12+ 또는 17+ 설정)
- 부적절 콘텐츠 신고 → **24시간 내 처리 메커니즘** 문서화 필요
- Block/Mute 기능 UI 접근성 확인 (프로필에서 쉽게 접근 가능해야 함)

---

#### 가이드라인 2.5.4 — 멀티플랫폼 코드

`macos/Flutter/GeneratedPluginRegistrant.swift`가 git에서 수정됨. iOS 전용 제출 시 macOS 설정이 iOS 빌드에 영향을 줄 수 있음. iOS 빌드와 macOS 빌드 완전 분리 확인 필요.

---

#### Human Interface Guidelines — 뒤로가기 제스처

iOS에서 왼쪽에서 오른쪽으로 스와이프하는 뒤로가기 제스처가 앱 전체에서 자연스럽게 동작해야 함. GoRouter 설정에서 일부 화면이 `fullscreenDialog: true`로 설정되면 제스처 비활성화됨. 심사관이 제스처가 막히는 화면을 발견하면 지적 가능.

---

#### iOS Privacy Manifest (PrivacyInfo.xcprivacy)

iOS 17+부터 `PrivacyInfo.xcprivacy` 파일에서 사용하는 API의 목적을 명시해야 함:
- `NSPrivacyAccessedAPITypeReasons` — UserDefaults, File timestamp 등
- Third-party SDK에서 요구하는 API 포함

---

### App Review Notes 필수 작성 항목

```
테스트 계정:
이메일: test@petspace.app
비밀번호: [심사용 비밀번호]

앱 기능 설명:
- 반려동물 사진으로 AI 감정 분석 수행 (Gemini AI)
- 카카오 로그인 지원 (한국 전용 기능)
- 주변 동물병원 검색 (카카오맵 기반)
- 반려동물 소셜 커뮤니티

참고사항:
- 카카오 로그인은 한국 계정 필요
- 심사관 계정으로 로그인 시 테스트 피드 콘텐츠를 볼 수 있음
```

---

## 9. 통합 액션 플랜 (우선순위별)

### 🚨 P0 — 출시 전 필수 (미완료 시 심사 통과 불가)

| # | 작업 | 예상 시간 | 담당 |
|---|------|----------|------|
| 1 | `petspace.app/privacy` 개인정보처리방침 페이지 생성 | 2-3시간 | 직접 |
| 2 | `petspace.app/terms` 이용약관 페이지 생성 | 2-3시간 | 직접 |
| 3 | Play Console Data Safety 폼 작성 | 1시간 | 직접 |
| 4 | App Store Connect Privacy Nutrition Label 작성 | 1시간 | 직접 |
| 5 | `secrets.dart` API 키 → `--dart-define` 빌드 환경변수 이전 | 2시간 | Claude |
| 6 | Closed Testing 12명 모집 + 2주 운영 | 2주 | 직접 |
| 7 | 심사관용 테스트 계정 생성 + 샘플 콘텐츠 입력 | 1시간 | 직접 |
| 8 | `PremiumGateWidget` → Apple IAP 연동 확인 또는 제거 | 1시간 | Claude |
| 9 | Supabase RLS 전 테이블 활성화 확인 | 1시간 | 직접 |
| 10 | iOS `PrivacyInfo.xcprivacy` 파일 추가 | 1시간 | Claude |

---

### ⚠️ P1 — 출시 전 권장 (이탈률/반려 위험)

| # | 작업 | 예상 시간 | 담당 |
|---|------|----------|------|
| 11 | 온보딩 펫 등록 → "나중에" 선택지 추가 | 2시간 | Claude |
| 12 | AI 감정분석 결과 화면에 케어 액션 추천 추가 | 3시간 | Claude |
| 13 | AI 감정분석 결과 화면에 Lottie 감성 애니메이션 추가 | 2시간 | Claude |
| 14 | `my_page.dart` limit:100 → LazyLoadList 전환 | 1시간 | Claude |
| 15 | `gemini_ai_service.dart:473` 임시 처리 정리 | 1시간 | Claude |
| 16 | `main.dart` `MeongNyangDiaryApp` 클래스명 변경 | 30분 | Claude |
| 17 | App Review Notes 작성 (심사관 설명) | 1시간 | 직접 |
| 18 | `NetworkErrorBanner` hardcoded 색상 → 테마 색상으로 교체 | 30분 | Claude |

---

### 🔧 P2 — 출시 후 v1.0.x (품질 개선)

| # | 작업 | 예상 시간 |
|---|------|----------|
| 19 | `injection_container.dart` feature별 모듈 분리 | 4시간 |
| 20 | `social_remote_data_source.dart` 도메인별 분리 | 6시간 |
| 21 | 접근성 (Semantics + semanticLabel) 전체 61개 화면 적용 | 8시간 |
| 22 | 다크모드 hardcoded Color 전수 조사 + 테마 토큰 교체 | 4시간 |
| 23 | `hospital_search_page.dart` 로직/UI 분리 (BLoC 추출) | 3시간 |
| 24 | `post_card.dart` 997줄 → 서브 위젯 분리 | 3시간 |
| 25 | 알림 배치 처리 (30개 좋아요 → "새 알림 30개") | 3시간 |
| 26 | 네비게이션 스택 UX 개선 (탭 독립 스택) | 4시간 |

---

### 🎯 P3 — v1.1.0 성장 기능

| # | 작업 | 우선순위 |
|---|------|---------|
| 27 | 카카오 친구 중 PetSpace 사용자 찾기 | ⭐⭐⭐⭐⭐ |
| 28 | 반려동물 성장 앨범 (월별 자동 콜라주) | ⭐⭐⭐⭐ |
| 29 | AI 분석 → 오늘의 케어 루틴 추천 | ⭐⭐⭐⭐⭐ |
| 30 | 병원 예약 플랫폼 연동 (폼 제출 방식이라도) | ⭐⭐⭐⭐ |
| 31 | 동네 기반 반려인 찾기 (산책 메이트) | ⭐⭐⭐ |
| 32 | 커뮤니티 그룹채팅 (관심사/품종 기반) | ⭐⭐⭐ |
| 33 | 반려동물 생일/입양일 기념 알림 | ⭐⭐⭐⭐ |

---

## 10. 기술 부채 트래킹

### 즉시 수정 필요 (보안)

| 파일 | 이슈 | 위험도 |
|------|------|--------|
| `lib/config/secrets.dart:11-41` | API 키 전체 평문 노출 | 🔴 Critical |
| `lib/config/app_config.dart` | `MeongNyangDiaryApp` 클래스명 잔재 | 🟡 Low |

### 코드 품질 부채

| 파일 | LOC | 이슈 | 우선순위 |
|------|-----|------|---------|
| `lib/config/injection_container.dart` | 16,000+ | DI 전체 집중 | P2 |
| `lib/features/social/data/datasources/social_remote_data_source.dart` | 2,099 | 단일 파일 과밀 | P2 |
| `lib/features/social/data/repositories/social_repository_impl.dart` | 1,340 | 분리 필요 | P2 |
| `lib/features/home/presentation/pages/hospital_search_page.dart` | 1,492 | UI+로직 혼재 | P2 |
| `lib/features/emotion/presentation/pages/emotion_analysis_page.dart` | 1,327 | 단일 책임 위반 | P2 |
| `lib/shared/widgets/post_card.dart` | 997 | 위젯 과밀 | P2 |

### 임시 처리 잔존

| 파일:라인 | 내용 | 위험도 |
|-----------|------|--------|
| `lib/features/emotion/data/datasources/gemini_ai_service.dart:473` | breedInsight 필드에 isSleepy 임시 전달 | 🟡 Medium |
| `lib/features/emotion/presentation/pages/emotion_result_page.dart:89` | 임시 파일 저장 처리 | 🟡 Medium |

### 미구현 기능 (v1.1.0 예정)

| 기능 | 현재 상태 | 예정 버전 |
|------|-----------|----------|
| `injection_container.dart` 모듈 분리 | 단일 파일 | v1.1.0 |
| 단위 테스트 커버리지 | 5개 파일 (1% 미만) | v1.1.0 |
| 접근성 전체 적용 | 3개 화면만 | v1.1.0 |
| 다크모드 hardcoded 색상 제거 | 다수 존재 | v1.0.x |

---

*최종 업데이트: 2026-05-07*  
*다음 리뷰 예정: Closed Testing 2주 완료 후*
