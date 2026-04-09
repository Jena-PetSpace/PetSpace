# PetSpace 개발자 가이드
**Developer Handbook — Architecture, Convention & Workflow**

| 항목 | 내용 |
|------|------|
| 프로젝트명 | PetSpace (펫페이스) |
| 버전 | 1.0.0 |
| 플랫폼 | Android (iOS 추후 지원) |
| 패키지명 | meong_nyang_diary |
| 기술 스택 | Flutter 3.x / Dart 3.x + Supabase + Firebase FCM |
| 아키텍처 | Clean Architecture + BLoC + GetIt DI |
| 레포지토리 | github.com/Jena-PetSpace/PetSpace |
| 문서 최종 수정 | 2026-03-26 |

---

## 목차

1. [프로젝트 개요 및 서비스 철학](#1-프로젝트-개요-및-서비스-철학)
2. [기술 스택 및 의존성](#2-기술-스택-및-의존성)
3. [디렉토리 구조](#3-디렉토리-구조)
4. [아키텍처 원칙 (Clean Architecture)](#4-아키텍처-원칙-clean-architecture)
5. [상태 관리 (BLoC 패턴)](#5-상태-관리-bloc-패턴)
6. [의존성 주입 (GetIt)](#6-의존성-주입-getit)
7. [라우팅 규칙](#7-라우팅-규칙)
8. [데이터베이스 스키마](#8-데이터베이스-스키마)
9. [브랜드 디자인 시스템](#9-브랜드-디자인-시스템)
10. [유저 플로우](#10-유저-플로우)
11. [기능별 구현 가이드](#11-기능별-구현-가이드)
12. [보안 수칙](#12-보안-수칙)
13. [테스트 작성 규칙](#13-테스트-작성-규칙)
14. [CI/CD 파이프라인](#14-cicd-파이프라인)
15. [커밋 컨벤션](#15-커밋-컨벤션)
16. [신규 기능 개발 체크리스트](#16-신규-기능-개발-체크리스트)
17. [자주 발생하는 실수 & 안티패턴](#17-자주-발생하는-실수--안티패턴)
18. [알림 아키텍처](#18-알림-아키텍처)
19. [환경 설정 가이드](#19-환경-설정-가이드)

---

## 1. 프로젝트 개요 및 서비스 철학

### 1.1 서비스 정의

PetSpace는 반려동물 보호자를 위한 AI 기반 감정 분석 + 소셜 네트워킹 + 건강 관리 올인원 플랫폼입니다. Jena팀이 개발한 두 가지 핵심 특허 AI 기술을 앱 내에 통합합니다.

| 핵심 기술 | 설명 | 정확도 |
|---------|------|--------|
| 감정 분류 시스템 | EfficientNet 멀티스케일 기반 반려동물 감정 분석 | ~96% |
| XAI 피부병 진단 | EfficientNetB3 + Grad-CAM 기반 설명 가능 AI | ~96% |

### 1.2 서비스 철학 및 개발 원칙

- **사용자 데이터 주권** — 모든 반려동물 데이터와 감정 분석 결과는 사용자 소유. 제3자 공유 없음.
- **AI 결과의 투명성** — Grad-CAM을 통해 AI 판단 근거를 시각적으로 보호자에게 설명.
- **반려동물 복지 최우선** — 분석 결과를 불안감이 아닌 실질적 행동 가이드로 제공.
- **접근성** — 디지털 약자(고령자) 포함 모든 보호자가 쉽게 사용할 수 있는 UX.

### 1.3 5탭 네비게이션 구조

| 탭 인덱스 | 이름 | 경로 | 주요 기능 |
|---------|------|------|---------|
| Tab 0 | 홈 🏠 | /home | 피드 미리보기, 반려동물 카드, 카테고리 필터 |
| Tab 1 | 건강관리 ❤️ | /health | 백신/검진/체중/투약/수술 기록 관리 |
| Tab 2 | AI분석 🧠 | /emotion | 감정 분석 (FAB 강조) |
| Tab 3 | 피드 📱 | /feed | 소셜 피드, 팔로잉, 커뮤니티 |
| Tab 4 | MY 👤 | /my | 프로필, 저장글, 알림 설정 |

> **Tab 2(AI분석)** 는 중앙 FAB 버튼으로 강조 표시. `primaryColor → accentColor` 그라데이션 적용.

---

## 2. 기술 스택 및 의존성

### 2.1 핵심 스택

| 분류 | 기술 | 버전 | 용도 |
|------|------|------|------|
| UI | Flutter | ^3.19.0 | 크로스플랫폼 UI 프레임워크 |
| 언어 | Dart | ^3.0.0 | |
| 상태관리 | flutter_bloc | ^8.1.6 | BLoC 패턴 상태 관리 |
| DI | get_it | ^7.7.0 | 의존성 주입 컨테이너 |
| 백엔드 | supabase_flutter | ^2.5.6 | Auth / DB / Storage / Realtime |
| 푸시알림 | firebase_messaging | ^15.1.5 | FCM Android 푸시 알림 |
| AI | Google Gemini API | — | 감정 분석 (secrets.dart에 키 관리) |
| 라우팅 | go_router | ^14.2.7 | 선언적 딥링크 라우팅 |
| 함수형 | dartz | ^0.10.1 | Either<Failure, T> 에러 처리 |
| 반응형 | flutter_screenutil | ^5.9.3 | 다양한 화면 크기 대응 |

### 2.2 의존성 추가 규칙

> ⚠️ `pubspec.yaml`에 패키지 추가 전 반드시 확인: 1) Supabase/Firebase와 충돌 없는지, 2) null safety 지원, 3) 마지막 업데이트 6개월 이내

- 패키지 추가 후 `flutter pub get` → `flutter analyze` 필수
- `dev_dependencies` — 테스트/린트 관련만. 프로덕션 코드에서 dev 패키지 import 금지
- **mocktail 사용 (mockito X)** — 이미 mocktail 기반 테스트가 작성되어 있음

---

## 3. 디렉토리 구조

### 3.1 전체 구조

```
PetSpace/
├── pjh/                        # Flutter 앱 루트
│   ├── lib/
│   │   ├── config/             # DI, API 설정, 라우터
│   │   │   ├── injection_container.dart   # GetIt 등록
│   │   │   ├── api_config.dart            # API 설정 (키 X)
│   │   │   ├── secrets.dart               # ⛔ gitignore (키 보관)
│   │   │   └── secrets.dart.example       # 템플릿
│   │   ├── core/               # 앱 전역 유틸/서비스
│   │   │   ├── cache/          # CacheManager
│   │   │   ├── error/          # Failure 클래스, ErrorMessages
│   │   │   ├── navigation/     # AppRouter (GoRouter)
│   │   │   ├── network/        # NetworkInfo
│   │   │   ├── services/       # FCM, Realtime, Push, Profile
│   │   │   └── usecases/       # UseCase 기본 인터페이스
│   │   ├── features/           # 기능별 모듈
│   │   │   ├── auth/           # 인증 (카카오/구글/이메일)
│   │   │   ├── chat/           # 채팅
│   │   │   ├── emotion/        # AI 감정 분석
│   │   │   ├── feed_hub/       # 피드 탭 (추천/팔로잉/커뮤니티)
│   │   │   ├── health/         # 건강 기록 관리
│   │   │   ├── home/           # 홈 위젯
│   │   │   ├── my/             # MY 탭
│   │   │   ├── onboarding/     # 온보딩 플로우
│   │   │   ├── pets/           # 반려동물 관리
│   │   │   ├── profile/        # 내 프로필 래퍼
│   │   │   └── social/         # 소셜 피드/댓글/팔로우
│   │   ├── shared/             # 공통 위젯/테마
│   │   │   ├── themes/         # AppTheme (브랜드 컬러)
│   │   │   └── widgets/        # 재사용 위젯
│   │   ├── firebase_options.dart
│   │   ├── main.dart
│   │   └── main_navigation.dart
│   ├── test/                   # 단위 테스트
│   └── android/                # Android 설정
├── supabase/
│   ├── petspace_setup.sql      # DB 전체 스키마
│   ├── functions/
│   │   ├── analyze-emotion/
│   │   └── send-notification/
│   └── .env.example
├── docs/                       # 개발 문서
└── .github/workflows/          # CI/CD
```

### 3.2 feature 모듈 내부 구조 (필수 준수)

> 🚨 모든 신규 feature는 반드시 아래 3계층 구조를 따라야 합니다.  
> 계층 간 의존성 방향: **presentation → domain ← data**

```
features/{feature_name}/
├── data/                   # 데이터 계층
│   ├── datasources/        # Supabase API 호출
│   ├── models/             # JSON 직렬화 모델 (Entity 변환)
│   └── repositories/       # Repository 구현체
├── domain/                 # 도메인 계층 (순수 Dart)
│   ├── entities/           # 비즈니스 엔티티 (Equatable)
│   ├── repositories/       # Repository 인터페이스 (abstract)
│   └── usecases/           # 비즈니스 로직 단위
└── presentation/           # UI 계층
    ├── bloc/               # BLoC (event/state/bloc)
    ├── pages/              # 전체 화면
    └── widgets/            # 화면 구성 위젯
```

---

## 4. 아키텍처 원칙 (Clean Architecture)

### 4.1 계층별 책임

| 계층 | 위치 | 책임 | 의존 가능 계층 |
|------|------|------|-------------|
| Presentation | presentation/ | UI 렌더링, 사용자 인터랙션, BLoC 상태 구독 | Domain만 |
| Domain | domain/ | 비즈니스 로직, UseCase, Entity 정의 | 없음 (순수 Dart) |
| Data | data/ | Supabase API 호출, 캐싱, Repository 구현 | Domain |

### 4.2 Entity 작성 패턴

```dart
// ✅ 올바른 Entity 작성법
class Post extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, authorId, authorName, createdAt];

  Post copyWith({String? id, String? authorId, ...}) {
    return Post(id: id ?? this.id, ...);
  }
}
```

> ⚠️ Entity는 순수 Dart만 사용. Flutter import 절대 금지. JSON 직렬화 로직도 Model에서만 처리.

### 4.3 UseCase 패턴

```dart
class GetFeedParams extends Equatable {
  final String? userId;
  final int limit;
  final bool followingOnly;

  const GetFeedParams({this.userId, this.limit = 20, this.followingOnly = false});
  @override List<Object?> get props => [userId, limit, followingOnly];
}

class GetFeed extends UseCase<List<Post>, GetFeedParams> {
  final SocialRepository repository;
  GetFeed(this.repository);

  @override
  Future<Either<Failure, List<Post>>> call(GetFeedParams params) async {
    return await repository.getFeed(userId: params.userId, limit: params.limit);
  }
}
```

### 4.4 Repository 구현 패턴

```dart
// ✅ 네트워크 체크 + Either 반환 필수
class SocialRepositoryImpl implements SocialRepository {
  final SocialRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  @override
  Future<Either<Failure, List<Post>>> getFeed({...}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }
    try {
      final posts = await remoteDataSource.getFeedPosts(userId, limit, lastPostId);
      return Right(posts.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: ErrorMessages.feedLoadFailed));
    }
  }
}
```

> 🚨 에러 메시지는 반드시 `ErrorMessages` 상수를 사용. 한국어 문자열 리터럴 직접 작성 금지.

---

## 5. 상태 관리 (BLoC 패턴)

### 5.1 BLoC 파일 구성

| 파일 | 내용 |
|------|------|
| `{name}_event.dart` | 이벤트 클래스 정의 |
| `{name}_state.dart` | 상태 클래스 정의 |
| `{name}_bloc.dart` | BLoC 구현 |

### 5.2 BLoC 작성 패턴

```dart
// Event
abstract class FeedEvent extends Equatable { const FeedEvent(); }
class LoadFeedRequested extends FeedEvent {
  final String? userId;
  const LoadFeedRequested({this.userId});
  @override List<Object?> get props => [userId];
}

// State — copyWith 패턴 권장
class FeedLoaded extends FeedState {
  final List<Post> posts;
  final bool hasReachedMax;
  const FeedLoaded({required this.posts, this.hasReachedMax = false});
  FeedLoaded copyWith({List<Post>? posts, bool? hasReachedMax}) =>
    FeedLoaded(posts: posts ?? this.posts, hasReachedMax: hasReachedMax ?? this.hasReachedMax);
  @override List<Object?> get props => [posts, hasReachedMax];
}

// BLoC
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeed _getFeed;
  FeedBloc({required GetFeed getFeed}) : _getFeed = getFeed, super(FeedInitial()) {
    on<LoadFeedRequested>(_onLoadFeedRequested);
  }
  Future<void> _onLoadFeedRequested(LoadFeedRequested event, Emitter<FeedState> emit) async {
    emit(FeedLoading());
    final result = await _getFeed(GetFeedParams(userId: event.userId));
    result.fold(
      (failure) => emit(FeedError(failure.message)),
      (posts)   => emit(FeedLoaded(posts: posts)),
    );
  }
}
```

### 5.3 BLoC 등록 규칙

| 등록 방식 | 사용 시점 |
|---------|---------|
| `registerLazySingleton` | 앱 전역 공유 BLoC (AuthBloc, EmotionAnalysisBloc, FeedBloc) |
| `registerFactory` | 화면마다 새 인스턴스가 필요한 경우 (ProfileBloc, CommentBloc) |

> 🚨 전역 `MultiBlocProvider`에서 사용하는 BLoC은 반드시 `registerLazySingleton`. `registerFactory` 사용 시 상태 불일치 버그 발생.

### 5.4 StreamSubscription 처리 규칙

```dart
// ✅ Stream 구독 시 반드시 cancel() 처리
class MyBloc extends Bloc<MyEvent, MyState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  void subscribeToStream() {
    _subscription?.cancel(); // 중복 구독 방지
    _subscription = someStream.listen((data) => add(DataReceived(data)));
  }

  @override
  Future<void> close() {
    _subscription?.cancel(); // 누수 방지
    return super.close();
  }
}
```

---

## 6. 의존성 주입 (GetIt)

### 6.1 신규 feature 추가 패턴

> ⚠️ 신규 feature 추가 시 `injection_container.dart`를 반드시 수정해야 합니다.  
> 등록 순서: **External → Core → DataSource → Repository → UseCase → BLoC**

```dart
// _init{FeatureName}() 함수 추가
Future<void> _initMyNewFeature() async {
  // 1. DataSource
  sl.registerLazySingleton<MyDataSource>(
    () => MyDataSourceImpl(supabaseClient: sl()),
  );

  // 2. Repository
  sl.registerLazySingleton<MyRepository>(
    () => MyRepositoryImpl(dataSource: sl(), networkInfo: sl()),
  );

  // 3. UseCases
  sl.registerLazySingleton(() => GetMyData(sl()));

  // 4. BLoC
  sl.registerFactory(  // 또는 registerLazySingleton
    () => MyBloc(getMyData: sl()),
  );
}

// init() 함수 끝에 추가
Future<void> init() async {
  await _initExternal();
  await _initCore();
  // ... 기존 feature들 ...
  await _initMyNewFeature(); // ← 추가
}
```

---

## 7. 라우팅 규칙

### 7.1 전체 라우트 맵

| 경로 | 이름 | 설명 |
|------|------|------|
| /onboarding | onboarding | 온보딩 스플래시 |
| /onboarding/login | onboarding-login | 로그인/회원가입 |
| /onboarding/terms | onboarding-terms | 약관 동의 |
| /onboarding/profile | onboarding-profile | 프로필 설정 |
| /onboarding/pet-registration | onboarding-pet-registration | 반려동물 등록 |
| /onboarding/complete | onboarding-complete | 온보딩 완료 |
| /home | home | 홈 탭 |
| /health | health | 건강관리 탭 |
| /emotion | emotion | AI 분석 탭 |
| /emotion/result/:analysisId | emotion-result | 감정 분석 결과 |
| /emotion/history | emotion-history | 감정 분석 히스토리 |
| /feed | feed-hub | 피드 탭 |
| /my | my | MY 탭 |
| /my/saved | my-saved | 저장한 글 |
| /post/:postId | post-detail | 게시글 상세 |
| /profile | profile | 내 프로필 |
| /profile/edit | profile-edit | 프로필 편집 |
| /profile/settings | settings | 설정 |
| /user-profile/:userId | user-profile | 타인 프로필 |
| /search | search | 검색 |
| /explore | explore | 탐색 |
| /chat | chat | 채팅 목록 |
| /chat/:roomId | chat-detail | 채팅 상세 |
| /notifications | notifications | 알림 |

### 7.2 라우트 추가 규칙

```dart
GoRoute(
  path: '/my-new-page',
  name: 'my-new-page',   // name은 kebab-case
  builder: (context, state) {
    final param = state.pathParameters['id']!;
    return BlocProvider(
      create: (_) => sl<MyBloc>(),
      child: MyNewPage(id: param),
    );
  },
),

// 화면 이동
context.push('/my-new-page'); // 스택에 추가 (back 버튼 동작)
context.go('/home');          // 스택 교체 (로그인 후 홈 이동 등)
```

> 🚨 `Navigator.push()`, `Navigator.pushNamed()` 사용 금지. 반드시 GoRouter의 `context.push()` / `context.go()` 사용.

---

## 8. 데이터베이스 스키마

### 8.1 테이블 목록

| 테이블 | 주요 컬럼 | 설명 |
|--------|---------|------|
| users | id, email, display_name, is_onboarding_completed | 사용자 프로필 |
| pets | id, user_id, name, type(dog/cat) | 반려동물 정보 |
| posts | id, author_id, image_url, emotion_analysis(JSONB) | 소셜 피드 게시글 |
| emotion_history | id, user_id, pet_id, image_url, emotion_analysis(JSONB) | 감정 분석 히스토리 |
| comments | id, post_id, author_id, content, likes_count | 댓글 |
| follows | follower_id, following_id | 팔로우 관계 |
| likes | user_id, post_id | 게시글 좋아요 |
| notifications | user_id, sender_id, type, title, body, data(JSONB) | 알림 |
| user_devices | user_id, fcm_token, platform | FCM 푸시 토큰 |
| comment_likes | comment_id, user_id | 댓글 좋아요 |
| reports | reporter_id, reported_post_id, reason | 신고 |
| user_blocks | blocker_id, blocked_id | 사용자 차단 |
| health_records | pet_id, user_id, record_type, title, record_date | 건강 기록 |
| saved_posts | post_id, user_id | 북마크 |

### 8.2 DB 수정 규칙

> 🚨 스키마 변경은 반드시 `petspace_setup.sql`에 반영해야 합니다. Dashboard에서만 변경하고 SQL 미반영 시 팀 간 DB 불일치 발생.

- 새 테이블 추가: `CREATE TABLE` → Index → RLS 활성화 → Policy 3단계 필수
- 컬럼 추가: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 사용
- RLS는 모든 테이블에 필수
- Realtime이 필요한 테이블은 `supabase_realtime` publication에 추가

### 8.3 RLS 정책 패턴

```sql
-- 기본 패턴: 본인 데이터만 접근
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own data" ON {table}
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 읽기는 전체, 쓰기는 본인만
CREATE POLICY "Anyone can view" ON {table}
  FOR SELECT USING (true);
CREATE POLICY "Author can write" ON {table}
  FOR INSERT WITH CHECK (auth.uid() = author_id);
```

---

## 9. 브랜드 디자인 시스템

### 9.1 JENA 브랜드 컬러 팔레트

| 토큰 | 헥스 코드 | 용도 |
|------|---------|------|
| `AppTheme.primaryColor` | #1E3A5F | 주요 버튼, AppBar, 강조 요소 |
| `AppTheme.secondaryColor` | #2C4482 | JENA 인디고 — 보조 강조 |
| `AppTheme.accentColor` | #0077B6 | 링크, 아이콘, AI 분석 요소 |
| `AppTheme.highlightColor` | #FF6F61 | Coral Red — CTA, 하트, 알림 |
| `AppTheme.subColor` | #5BC0EB | Sky Blue — 기쁨 감정, 보조 정보 |
| `AppTheme.successColor` | #4CAF50 | 성공, 완료 상태 |
| `AppTheme.errorColor` | #E53935 | 오류, 삭제, 경고 |
| `AppTheme.warningColor` | #FF9800 | 주의 상태 |
| `AppTheme.dividerColor` | #E0E0E0 | 구분선 |
| `AppTheme.hintColor` | #9E9E9E | 힌트 텍스트 |
| `AppTheme.subtleBackground` | #F5F5F5 | 카드 내 보조 배경 |

### 9.2 컬러 사용 규칙

> 🚨 `Colors.red`, `Colors.blue`, `Color(0xFF...)` 직접 사용 금지. 반드시 AppTheme 토큰 사용.

```dart
// ❌ 금지
color: Colors.red
color: Color(0xFF4CAF50)

// ✅ 올바른 방법
color: AppTheme.errorColor
color: AppTheme.successColor
```

### 9.3 간격 및 모서리 토큰

| 토큰 | 값 | 용도 |
|------|-----|------|
| `AppTheme.spacingXs` | 4 | 아이콘과 텍스트 사이 |
| `AppTheme.spacingSm` | 8 | 요소 간 기본 간격 |
| `AppTheme.spacingMd` | 16 | 섹션 내 표준 간격 |
| `AppTheme.spacingLg` | 24 | 섹션 간 간격 |
| `AppTheme.spacingXl` | 32 | 화면 패딩 |
| `AppTheme.radiusSm` | 8 | 칩, 태그 |
| `AppTheme.radiusMd` | 12 | 버튼, 입력필드 |
| `AppTheme.radiusLg` | 14 | 카드 |
| `AppTheme.radiusXl` | 18 | 대형 카드, 바텀시트 |

### 9.4 화면 크기 대응 (flutter_screenutil)

> 기준 사이즈: iPhone 13/14 (390×844). 모든 픽셀 값은 suffix 사용.

```dart
// ✅ 올바른 방법
SizedBox(width: 16.w, height: 8.h)
Text('...', style: TextStyle(fontSize: 14.sp))
BorderRadius.circular(12.r)

// ❌ 하드코딩 금지
SizedBox(width: 16, height: 8)
Text('...', style: TextStyle(fontSize: 14))
```

---

## 10. 유저 플로우

### 10.1 인증 플로우

```
앱 실행
  └→ AuthBloc.AuthStarted 이벤트
       ├→ session 있음 + onboarding 완료
       │    └→ /home
       ├→ session 있음 + onboarding 미완료
       │    └→ /onboarding/terms → profile → pet-registration → complete → /home
       └→ session 없음
            └→ /onboarding/login
                 ├→ 카카오 로그인: KakaoSDK → OAuth → /home
                 ├→ 구글 로그인: GoogleSignIn → Supabase → /home
                 └→ 이메일/비밀번호: Supabase Auth → /home
```

### 10.2 감정 분석 플로우

```
Tab 2 (AI분석 FAB 탭)
  └→ /emotion (EmotionAnalysisPage)
       └→ 사진 선택 (카메라/갤러리, 최대 5장)
            └→ 분석 시작 버튼
                 └→ EmotionAnalysisBloc.AnalyzeEmotionRequested
                      └→ Gemini API 호출 (gemini_ai_service.dart)
                           └→ 분석 완료
                                ├→ /emotion/result/:analysisId (EmotionResultPage)
                                │    ├→ 감정 분포 차트 (차트/바 토글)
                                │    ├→ 스트레스 카드
                                │    ├→ 건강 팁 카드
                                │    ├→ 피드 공유 → 이미지 업로드 → FeedBloc.CreatePostRequested
                                │    ├→ 시스템 공유 (Share.share)
                                │    └→ 히스토리 저장
                                └→ /emotion/history (EmotionHistoryPage)
                                     └→ 캘린더 뷰 + 감정 dot 마커
```

### 10.3 소셜 피드 플로우

```
Tab 3 (피드 탭) → FeedHubPage (3개 탭)
  ├→ 추천 탭: FeedPage(followingOnly: false)
  │    └→ FeedBloc.LoadFeedRequested
  │         └→ 피드 목록 (PostCard)
  │              ├→ 좋아요 → FeedBloc.LikePostRequested → 낙관적 업데이트 → 알림 발송
  │              ├→ 댓글 → /post/:postId (PostDetailPage)
  │              │    └→ CommentBloc + Realtime 구독 (실시간 댓글)
  │              ├→ 북마크 → FeedBloc.SavePostRequested
  │              └→ 더보기 → 신고/차단 (user_blocks 테이블)
  ├→ 팔로잉 탭: FeedPage(followingOnly: true)
  └→ 커뮤니티 탭: posts 테이블 hashtags 기반 필터링
       ├→ 카테고리: 전체 / Q&A / 건강 / 훈련 / 매거진
       └→ FAB → CreateCommunityPostPage (내용/해시태그)
```

### 10.4 건강 관리 플로우

```
Tab 1 (건강관리) → HealthMainPage
  └→ HealthBloc.LoadHealthRecords
       └→ 기록 목록 (유형별 필터: 백신/검진/체중/투약/수술)
            ├→ FAB (+) → AddHealthRecordSheet (바텀시트)
            │    └→ 날짜/제목/설명/다음 예정일 입력
            │         └→ HealthBloc.AddHealthRecordRequested
            ├→ 기록 탭 → HealthBloc.UpdateHealthRecordRequested
            └→ 기록 삭제 → HealthBloc.DeleteHealthRecordRequested
```

### 10.5 알림 플로우

```
이벤트 발생 (좋아요/댓글/팔로우)
  └→ PushNotificationService.send{Type}Notification()
       └→ supabase.functions.invoke('send-notification')
            └→ Edge Function (send-notification/index.ts)
                 ├→ notifications 테이블 INSERT
                 └→ user_devices에서 FCM 토큰 조회
                      └→ Firebase FCM HTTP v1 API
                           └→ 기기 푸시 알림 수신
                                └→ FCMService._routeFromData()
                                     ├→ like/comment → /post/:postId
                                     ├→ follow → /user-profile/:userId
                                     └→ emotion → /emotion/history
```

---

## 11. 기능별 구현 가이드

### 11.1 새 화면(Page) 추가 순서

> ⚠️ 반드시 이 순서를 지키세요. presentation 먼저 작성하면 의존성이 꼬입니다.

1. `domain/entities/` — Entity 정의 (필요 시)
2. `domain/repositories/` — Repository 인터페이스 메서드 추가
3. `data/datasources/` — Supabase 쿼리 구현
4. `data/repositories/` — Repository 구현체 메서드 추가
5. `domain/usecases/` — UseCase 클래스 작성
6. `presentation/bloc/` — Event / State / BLoC 작성
7. `injection_container.dart` — UseCase + BLoC 등록
8. `presentation/pages/` — Page 위젯 작성
9. `app_router.dart` — 라우트 등록

### 11.2 Supabase 쿼리 작성 가이드

```dart
Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId) async {
  // 1. JOIN이 필요하면 select에 명시
  var query = supabaseClient
    .from('posts')
    .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
    .order('created_at', ascending: false)
    .limit(limit);

  // 2. cursor 페이지네이션
  if (lastPostId != null) {
    final lastPost = await supabaseClient
      .from('posts').select('created_at').eq('id', lastPostId).maybeSingle();
    if (lastPost != null) query = query.lt('created_at', lastPost['created_at']);
  }

  // 3. 필터 (차단 사용자 제외 등)
  if (blockedIds.isNotEmpty) {
    query = query.not('author_id', 'in', '(${blockedIds.join(',')})');
  }

  final response = await query;
  return (response as List).map((j) => PostModel.fromJson(j).toEntity()).toList();
}
```

### 11.3 낙관적 업데이트 패턴

```dart
// 좋아요, 팔로우 등 즉시 피드백이 필요한 경우
Future<void> _onLikePost(LikePostRequested event, Emitter<FeedState> emit) async {
  final current = state as FeedLoaded;
  final original = List<Post>.from(current.posts); // 원본 저장

  // 1. 즉시 UI 업데이트 (낙관적)
  final updated = current.posts.map((p) {
    if (p.id == event.postId)
      return p.copyWith(isLikedByCurrentUser: true, likesCount: p.likesCount + 1);
    return p;
  }).toList();
  emit(current.copyWith(posts: updated));

  // 2. 실제 API 호출
  final result = await _likePost(LikePostParams(postId: event.postId, userId: event.userId));

  // 3. 실패 시 롤백
  result.fold(
    (failure) => emit(current.copyWith(posts: original)),
    (_) { /* 성공 — 낙관적 상태 유지 */ },
  );
}
```

---

## 12. 보안 수칙

> 🚨 보안 수칙 위반은 즉각적인 사용자 데이터 유출로 이어집니다. 아래 규칙은 절대 예외 없이 지켜야 합니다.

### 12.1 API 키 관리

| 파일 | Git 추적 | 내용 |
|------|---------|------|
| `secrets.dart` | ❌ gitignore | Supabase URL/Key, Gemini API Key, Kakao Key |
| `firebase_options.dart` | ✅ 추적 | Firebase Android API Key (공개 가능) |
| `.env.example` | ✅ 추적 | 키 형식 예시만 — 실제 값 절대 입력 금지 |
| `google-services.json` | ✅ 추적 | Firebase 설정 (공개 정보) |
| `key.properties` | ❌ gitignore | Play Store 릴리즈 서명 키 |

> 🚨 `secrets.dart`에 있는 키가 git에 커밋되면: 1) 즉시 key revoke 2) `git filter-repo`로 히스토리 삭제 3) force push 순서로 대응.

### 12.2 로깅 규칙

```dart
// ❌ 금지: 프로덕션에서도 출력됨
print('사용자 ID: $userId');
debugPrint('API 키: $apiKey');

// ✅ 올바른 방법
import 'dart:developer' as dev;
dev.log('피드 로드 완료', name: 'FeedBloc');
dev.log('에러 발생', name: 'MyPage', error: e);
```

> 🚨 민감 정보(이메일, 전화번호, API 키, FCM 토큰)는 로그에 절대 포함 금지.

### 12.3 RLS 체크리스트

- 새 테이블 추가 시 RLS 활성화 필수
- Policy: SELECT는 범위를 좁게, INSERT/UPDATE/DELETE는 `auth.uid()` 검증 필수
- `SECURITY DEFINER` 함수는 최소한으로 사용하고 반드시 코드 리뷰
- Service Role Key는 Edge Function 외부에서 절대 사용 금지

---

## 13. 테스트 작성 규칙

### 13.1 테스트 파일 위치 및 현황

```
test/
├── features/
│   ├── auth/presentation/bloc/auth_bloc_test.dart              (11케이스)
│   ├── emotion/presentation/bloc/emotion_analysis_bloc_test.dart (11케이스)
│   ├── health/domain/usecases/health_usecases_test.dart         (9케이스)
│   ├── social/domain/usecases/bookmark_usecases_test.dart       (8케이스)
│   └── social/presentation/bloc/feed_bloc_test.dart             (12케이스)
└── widget_test.dart
```

**누적: 51케이스**

### 13.2 BLoC 테스트 패턴

```dart
// mocktail 사용 (mockito 아님)
class MockGetFeed extends Mock implements GetFeed {}
class FakeGetFeedParams extends Fake implements GetFeedParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGetFeedParams());
  });

  group('LoadFeedRequested', () {
    blocTest<FeedBloc, FeedState>(
      '성공 → FeedLoading → FeedLoaded',
      build: () {
        final mock = MockGetFeed();
        when(() => mock(any())).thenAnswer((_) async => Right([tPost]));
        return FeedBloc(getFeed: mock, ...);
      },
      act: (bloc) => bloc.add(LoadFeedRequested(userId: 'user-1')),
      expect: () => [isA<FeedLoading>(), isA<FeedLoaded>()],
    );
  });
}
```

### 13.3 테스트 작성 의무

| 상황 | 의무 |
|------|------|
| 새 BLoC 추가 | 최소 3케이스: 성공/실패/엣지케이스 |
| 새 UseCase 추가 | 성공/실패 2케이스 최소 |
| 버그 수정 | 해당 버그를 재현하는 테스트 먼저 작성 후 수정 |
| 기존 테스트 수정 | PR 리뷰 필수, 테스트 삭제 금지 |

---

## 14. CI/CD 파이프라인

### 14.1 파이프라인 구성

```
Triggers: push(main, develop) / pull_request(main)

Job 1: Analyze & Test (모든 push)
  1. Flutter SDK 3.22.0 설치
  2. secrets.dart 더미 생성 (CI 전용)
  3. flutter pub get
  4. dart format lib/ test/ → 변경 시 자동 커밋 [skip ci]
  5. flutter analyze --no-pub
  6. flutter test (5개 파일, 51케이스)

Job 2: Build Android APK (main push 시만)
  1. Java 17 + Flutter 설치
  2. secrets.dart 더미 생성
  3. flutter build apk --release --split-per-abi
  4. APK 아티팩트 업로드 (7일 보관)
```

> ⚠️ CI 실패 시 main 브랜치에 merge 불가. 로컬에서 `flutter analyze` → `flutter test` 통과 확인 후 push.

### 14.2 [skip ci] 사용법

```bash
# docs 업데이트, README 수정 등에만 사용
git commit -m "docs: README 업데이트 [skip ci]"
```

---

## 15. 커밋 컨벤션

### 15.1 커밋 메시지 형식

```
{type}({scope}): {설명}

예시:
feat(social): 게시글 북마크 기능 추가
fix(ci): test job secrets.dart 누락 수정
refactor(auth): AuthBloc registerFactory → LazySingleton 변경
docs: 개발자 가이드 문서 추가
security: API 키 노출 제거 및 히스토리 삭제
style: dart format 적용
test(feed): FeedBloc 단위 테스트 12케이스 추가
chore(deps): firebase_messaging 15.1.5 업데이트
```

### 15.2 타입 정의

| 타입 | 용도 |
|------|------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 (기능 변경 없음) |
| `style` | dart format, 코드 스타일만 변경 |
| `docs` | 문서 추가/수정 |
| `test` | 테스트 추가/수정 |
| `security` | 보안 관련 수정 |
| `chore` | 빌드, 의존성, CI 설정 변경 |
| `perf` | 성능 개선 |

---

## 16. 신규 기능 개발 체크리스트

### 설계 단계
- [ ] 기존 feature 모듈에 속하는지, 새 모듈이 필요한지 판단
- [ ] DB 스키마 변경 필요 시 `petspace_setup.sql` 업데이트 계획 수립
- [ ] 알림 필요 시 `PushNotificationService` 메서드 추가 계획

### 구현 단계
- [ ] Entity → Repository 인터페이스 → DataSource → Repository 구현 → UseCase → BLoC → UI 순서 준수
- [ ] Repository 구현: `networkInfo.isConnected` 체크 + Either 반환
- [ ] 에러 메시지: `ErrorMessages` 상수 사용
- [ ] 색상: `AppTheme` 토큰 사용
- [ ] 픽셀 값: `.w` / `.h` / `.sp` / `.r` suffix 사용
- [ ] BLoC 등록: `injection_container.dart`에 추가
- [ ] 라우트 등록: `app_router.dart`에 추가
- [ ] Stream 구독 시 `close()`에서 `cancel()` 처리

### 테스트 단계
- [ ] 새 BLoC/UseCase에 테스트 추가
- [ ] `ci.yml` 테스트 목록에 새 파일 추가
- [ ] `flutter analyze` 통과 확인
- [ ] `flutter test` 통과 확인

### 보안 단계
- [ ] API 키가 코드에 하드코딩되지 않았는지 확인
- [ ] 새 Supabase 테이블에 RLS 정책 적용 확인
- [ ] 민감 정보가 로그에 포함되지 않았는지 확인

### 문서화
- [ ] `docs/` 폴더에 기능 완료 문서 작성
- [ ] 커밋 메시지 컨벤션 준수

---

## 17. 자주 발생하는 실수 & 안티패턴

| ❌ 금지 | ✅ 올바른 방법 | 이유 |
|--------|------------|------|
| `print()` / `debugPrint()` | `dart:developer log()` | 프로덕션 로그 노출 |
| `Colors.red` / `Color(0xFF...)` | `AppTheme.errorColor` | 브랜드 일관성 |
| `Navigator.push()` | `context.push()` | GoRouter 일관성 |
| UI에서 SupabaseClient 직접 사용 | Repository 통해 접근 | 계층 위반 |
| `registerFactory` (전역 BLoC) | `registerLazySingleton` | 상태 불일치 |
| `Stream.listen()` 후 cancel 없음 | `close()`에서 `cancel()` | 메모리 누수 |
| 한국어 에러 메시지 하드코딩 | `ErrorMessages.상수` | 다국어 대비 |
| 픽셀 하드코딩 (`16.0`) | `16.w` / `16.h` | 화면 크기 대응 |
| Entity에 Flutter import | 순수 Dart만 | 도메인 계층 오염 |
| API 키 직접 코드에 작성 | `secrets.dart` | 보안 취약점 |
| `Either` 없이 예외 throw | `Left(Failure(...))` 반환 | 에러 처리 일관성 |
| `context.read()` inside `build()` | `BlocBuilder` / `BlocListener` 사용 | 불필요한 rebuild |

---

## 18. 알림 아키텍처

### 18.1 전체 구조

```
[앱] PushNotificationService.send{Type}Notification()
  └→ supabase.functions.invoke('send-notification')
       └→ [Edge Function: send-notification/index.ts]
            ├→ notifications 테이블 INSERT
            └→ user_devices에서 FCM 토큰 조회
                 └→ Firebase FCM HTTP v1 API
                      └→ [기기] 푸시 수신
                           └→ FCMService._routeFromData()
                                └→ 화면 이동
```

### 18.2 알림 타입

| type 값 | 발생 시점 | 이동 화면 |
|--------|---------|---------|
| `like` | 게시글 좋아요 | `/post/:postId` |
| `comment` | 댓글 작성 | `/post/:postId` |
| `follow` | 팔로우 | `/user-profile/:userId` |
| `mention` | 멘션 | `/post/:postId` |
| `emotionAnalysis` | 감정 분석 완료 | `/emotion/history` |
| `postShare` | 게시글 공유 | `/post/:postId` |

### 18.3 Realtime 댓글 구독

```
PostDetailPage 진입
  └→ CommentBloc._subscribeToRealtime(postId)
       └→ RealtimeService.subscribeToPostComments(postId)
            └→ commentStream.listen
                 ├→ insert 이벤트 → LoadComments 재요청
                 └→ delete 이벤트 → LoadComments 재요청
  └→ BLoC.close() → _commentSub?.cancel()
```

### 18.4 Edge Function Secrets 설정

> 🚨 Supabase Dashboard → Settings → Edge Functions에서 반드시 설정. 없으면 푸시 전송 안 됨.

| Secret 키 | 값 |
|---------|-----|
| `FCM_SERVER_KEY` | Firebase Service Account JSON 전체 문자열 |
| `FIREBASE_PROJECT_ID` | project-5e5638c5-de70-498d-8f2 |

---

## 19. 환경 설정 가이드

### 19.1 개발 환경 초기 세팅

```bash
# 1. Flutter SDK 3.19.0 이상 설치
# 2. 레포 클론
git clone https://github.com/Jena-PetSpace/PetSpace.git
cd PetSpace/pjh

# 3. 의존성 설치
flutter pub get

# 4. secrets.dart 생성 (아래 내용으로)
# 5. 실행
flutter run
```

```dart
// pjh/lib/config/secrets.dart (gitignore — 직접 생성 필요)
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
const String kakaoNativeKey = 'YOUR_KAKAO_NATIVE_KEY';
const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';
```

### 19.2 Supabase 초기 설정

1. Supabase Dashboard → SQL Editor
2. `supabase/petspace_setup.sql` 전체 실행
3. Dashboard → Database → Replication → `supabase_realtime` publication
4. `likes`, `comments`, `notifications` 테이블 추가
5. Storage → `images` 버킷 public 설정 확인

### 19.3 Play Store 릴리즈 빌드

```bash
# 1. 서명 키 생성 (최초 1회)
keytool -genkey -v \
  -keystore android/petspace-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias petspace

# 2. android/key.properties 파일 생성
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=petspace
storeFile=../petspace-release.jks

# 3. AAB 빌드 (Play Store 권장)
cd pjh
flutter build appbundle --release
# 결과: pjh/build/app/outputs/bundle/release/app-release.aab
```

---

*PetSpace Developer Handbook — Jena Team 2026*
