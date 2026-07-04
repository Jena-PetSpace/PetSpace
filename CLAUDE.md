# PetSpace (펫페이스 / 멍냥다이어리)

AI 기반 반려동물 감정 분석 + 소셜 네트워킹 Flutter 앱. 백엔드는 Supabase, AI는 Gemini, 푸시는 Firebase FCM.

- 앱 패키지명: Android `com.petspace.app` · iOS 번들 ID `com.jena.petspace` (서로 다름 — Supabase Apple Authorized Client IDs·Apple Developer App ID는 iOS 값 기준) / Flutter 패키지명: `meong_nyang_diary`
- 버전: 1.0.0+1 · Flutter 3.41.6 (stable) · Dart 3.11.4
- Android minSdk 21 / targetSdk 34

## 프로젝트 위치

| 경로 | 내용 |
|------|------|
| `pjh/` | Flutter 앱 루트 (여기서 모든 flutter 명령 실행) |
| `pjh/lib/` | 앱 소스 (Clean Architecture) |
| `supabase/` | Supabase 마이그레이션·Edge Functions |
| `docs/` | 프로젝트 기획·분석·개발 문서 (상세 출처) |

> 빌드/아키텍처/기능 상세는 `docs/PetSpace_종합분석리포트.md`, `docs/DEVELOPER_GUIDE.md` 참조.

## 빌드 · 실행

모든 명령은 `pjh/`에서 실행한다.

```bash
flutter pub get          # 의존성 설치 (패키지 추가 후 필수)
flutter analyze          # 정적 분석 (push 전 통과 필수)
flutter test             # 테스트 (250케이스 — health·feed 사전 실패 일부는 Sprint5 인계 베이스라인)
flutter run              # 디바이스/에뮬레이터 실행
flutter build apk --release --split-per-abi   # Android APK
flutter build appbundle --release             # Play Store AAB
```

> CI 실패 시 main 브랜치 merge 불가. push 전 로컬에서 `flutter analyze` → `flutter test` 통과 확인.

## 아키텍처

Clean Architecture (feature별 3계층) + BLoC + GetIt DI + GoRouter.

```
lib/
├── config/        # app_config, api_config, secrets, injection_container (DI)
├── core/          # cache, error(12 Failure), navigation(50+ 라우트), services, utils
├── features/      # 12개 feature: auth, chat, diary, emotion, feed_hub, health,
│                  #   home, my, onboarding, pets, profile, social
├── shared/        # themes(app_theme 디자인시스템), 공통 위젯 22개
└── main.dart      # 진입점
```

각 feature는 `data/`(datasources·models·repositories) · `domain/`(entities·repositories·usecases) · `presentation/`(bloc·pages·widgets) 3계층으로 분리.

전역 BLoC: AuthBloc, EmotionAnalysisBloc, FeedBloc, ChatBadgeBloc, NotificationBadgeBloc, ThemeCubit, PetBloc.

## 기술 스택 / 컨벤션

- 상태관리: flutter_bloc (BLoC, Event→State, part files) + get_it (`sl` service locator)
- 라우팅: go_router (auth_guard 인증 가드)
- 백엔드: supabase_flutter (PostgreSQL/Auth/Storage/Realtime), Edge Functions
- AI: Google Gemini 2.5 Flash (감정분석·일기 생성)
- 인증: Email/Password, Google OAuth, Kakao Login (PKCE flow)
- 푸시/모니터링: Firebase FCM, Crashlytics, Analytics
- 지도: Kakao Maps Flutter / 함수형: dartz (Either)
- 화면 크기: flutter_screenutil (designSize 390×844, `.w/.h/.sp/.r` 확장)
- 에러 메시지는 한국어, `core/error/error_messages.dart` 중앙 관리
- 디자인: AppTheme JENA 브랜드 (primaryColor 0xFF1E3A5F)

## 작업 규칙

- 브랜치: 윈도우=`win-android-release`, 맥=`mac-ios-release`, 최종=`main`. 이 흐름 준수.
- 커밋: 멀티라인/한글 커밋 메시지는 파일(`-F`)로 작성.

---

# 도입된 에이전트 팀 (harness-100)

[revfactory/harness-100](https://github.com/revfactory/harness-100)에서 도입한 두 팀이
`.claude/agents/`·`.claude/skills/`에 설치되어 있다. 산출물은 `_workspace/` 디렉토리에 저장된다.

## 팀 A — Mobile App Builder (`/mobile-app-builder`)

모바일 앱 UI/UX 설계 → 코드 생성 → API 연동 → 스토어 배포 준비. (PetSpace 앱 본체 작업용)

| 에이전트 | 역할 |
|----------|------|
| `ux-designer` | UX/UI 설계 (와이어프레임, 디자인 시스템, 인터랙션) |
| `app-developer` | 앱 개발 (Flutter/RN/Swift/Kotlin) |
| `api-integrator` | API 연동 (REST/GraphQL, 인증, 캐싱) |
| `store-manager` | 스토어 배포 (메타데이터, 스크린샷, 심사 대응) |
| `qa-engineer` | 품질 검증 (UI 테스트, 성능, 접근성, 보안) |

보조 스킬: `mobile-ux-patterns`(iOS HIG / Material 3), `app-store-optimization`(ASO 키워드·심사)

## 팀 B — Startup Launcher (`/startup-launcher`)

아이디어 검증 → 비즈니스 모델 → MVP → 피칭 → 투자 유치. (스타트업 사업문서 작업용)

| 에이전트 | 역할 |
|----------|------|
| `market-analyst` | 시장 분석 (아이디어 검증, TAM/SAM/SOM, 경쟁분석) |
| `business-modeler` | 비즈니스 모델 (BMC, 수익모델, 유닛이코노믹스) |
| `mvp-architect` | MVP 설계 (기능 우선순위, 기술스택, 로드맵) |
| `pitch-creator` | 피치덱 작성 (투자자 프레젠테이션, 스토리라인) |
| `launch-reviewer` | 런칭 검증 (전체 일관성, 투자 준비도 평가) |

보조 스킬: `unit-economics-calculator`(LTV/CAC/BEP), `pitch-deck-framework`(10-슬라이드)

## 사용법

- 스킬 트리거: `/mobile-app-builder` 또는 `/startup-launcher`
- 자연어: "모바일 앱 만들어줘" / "스타트업 기획해줘"
- 개별 에이전트는 Task(서브에이전트) 호출로 직접 사용 가능
