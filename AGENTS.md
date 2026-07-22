# AGENTS.md — PetSpace 공용 작업 규칙

이 파일은 Codex와 Claude Code가 공유하는 프로젝트 규칙의 단일 소스다. 제품·기능의 현행 사실은 `docs/README.md`가 지정한 문서를 따른다. 도구별 사용법은 각 도구 설정 파일에만 둔다.

## 우선순위와 작업 범위

- 현재는 출시 안정성을 리팩터링보다 우선한다.
- 승인된 작업지시서의 목표, 수정 허용 범위, 완료 조건 안에서만 구현한다.
- 범위 밖 문제는 수정하지 않고 완료 보고의 `발견 이슈`에 기록한다.
- 기존 사용자 변경과 커밋을 되돌리거나 덮어쓰지 않는다.
- 보안, 인증, DB, 법무, 개인정보, 결제, 배포에 영향을 주는 미확정 사항은 구현 전에 사람의 결정을 받는다.
- 결과에 영향이 작고 되돌릴 수 있는 사항은 가정을 명시하고 진행할 수 있다.

## 프로젝트 기준

- Flutter 앱 루트: `pjh/`
- 앱 소스: `pjh/lib/`
- Supabase: `supabase/`
- 현행 문서 지도: `docs/README.md`
- Android applicationId/namespace: `com.jena.petspace`
- Android targetSdk: 36
- Android 출시 작업 기준 브랜치: `win-android-release`
- iOS 출시 작업 기준 브랜치: `mac-ios-release`
- 최종 통합 브랜치: `main` (양 플랫폼 검증과 별도 사용자 승인 뒤에만 반영)
- 모든 Flutter 명령은 `pjh/`에서 실행한다.

기능·라우트·BLoC 개수처럼 변하는 값은 이 파일에 고정하지 않는다. `docs/FUNCTIONAL_SPEC.md`, `docs/USER_FLOW.md`와 실제 코드를 대조한다.

## 아키텍처

- Clean Architecture의 `presentation → domain → data` 의존 방향을 따른다.
- 신규 Presentation 코드에서는 Supabase 클라이언트를 직접 호출하지 않고 Repository/UseCase를 경유한다.
- 기존 Presentation 직접 호출은 기술부채다. 수정 중인 파일에서 안전하게 개선할 수 있지만, 별도 승인 없이 전역 리팩터링하지 않는다.
- 상태관리는 기존 BLoC/Cubit과 GetIt DI 패턴을 따른다.
- 라우팅은 `pjh/lib/core/navigation/app_router.dart`의 GoRouter 트리에 통합한다.
- 새 기능은 기존 `pjh/lib/features/<name>/`의 data/domain/presentation 구조를 따른다.
- 출시 전에는 요청되지 않은 패키지 교체, 대규모 이름 변경, 구조 재편을 하지 않는다.

## 데이터베이스와 개인정보

- 신규 사용자 FK는 원칙적으로 `public.users(id)`를 참조한다.
- 기존 `auth.users` 직접 FK는 승인된 마이그레이션 없이 변경하지 않는다. 현재 예외는 포인트·퀘스트·구매·뱃지·건강 히스토리 영역에 존재한다.
- 새 테이블과 접근 경로에는 소유권 모델에 맞는 RLS 정책과 검증안을 포함한다. 모든 테이블에 같은 조건을 기계적으로 복사하지 않는다.
- DB 변경은 `supabase/migrations/`에 새 migration을 먼저 작성한다.
- `supabase/petspace_setup.sql` 동기화는 작업지시서가 명시한 경우에만 migration과 함께 수행한다.
- 운영 DB 적용, reset, seed, 원격 RPC 실행은 사람이 수행한다.
- `increment_user_points`, `confirm_kakao_user_by_email` 및 인증·포인트·결제·사용자 연결 RPC는 사전 승인 없이 수정하지 않는다.
- `location_access_log`와 산책 기록 트리거의 기록·보존 동작을 깨뜨리지 않는다.
- 비밀키, 토큰, service role key, 실제 사용자 개인정보를 코드·문서·로그·스크린샷에 넣지 않는다.

## 수정 금지·주의 파일

- 비밀 파일: `.env*`, `pjh/lib/config/secrets.dart`, `pjh/android/key.properties`, `*.jks`, `*.keystore`
- 로컬 도구 설정: `.claude/settings.local.json`
- 역사 문서: `docs/archive/`는 읽기 전용
- 민감 SQL/RPC는 작업지시서에 명시되지 않으면 수정하지 않는다.
- 금지 파일이 작업에 필요하면 먼저 이유와 최소 변경 범위를 보고한다.

## UI, 문구, 법무

- 색상은 `AppTheme`과 기능별 승인 토큰을 사용한다. 신규 임의 빨강 하드코딩을 추가하지 않는다.
- 오류·부정 상태는 승인된 의미 토큰을 사용한다. 기존 색상 부채를 요청 없이 일괄 변경하지 않는다.
- AI 결과의 confidence 수치를 사용자 UI에 노출하지 않는다.
- AI 결과를 `진단` 또는 `diagnosis`로 명명하지 않고 `분석`, `모니터링`, `알림`을 사용한다.
- 승인된 면책·약관에서 수의학적 진단과 구분하기 위한 표현은 허용한다.
- AI 분석 화면의 승인된 면책 고지를 제거하거나 축약하지 않는다.
- 법률 해석을 새로 만들지 않는다. `docs/legal/`의 현행 승인 문구를 사용하거나 검토를 요청한다.

## Git, 병렬 작업, 배포

- 기본 작업은 현재 작업 기기의 로컬 `feature/<작업명>` 브랜치와 전용 worktree에서 수행한다.
- 구현·format·정적 분석·관련 테스트·승인된 교차 리뷰를 통과하면 feature 브랜치에 커밋한다.
- Windows 앱의 승인된 변경은 로컬 `win-android-release`에 merge하고 동일 브랜치에서 재검증한 뒤 `origin/win-android-release`로 push하여 노트북·GitHub·실기기 빌드 소스를 일치시킨다.
- `win-android-release`에서 기능 코드를 직접 편집하지 않는다. merge 충돌 해결과 생성 파일 정리만 허용한다.
- Mac mini에서는 `origin/mac-ios-release`에서 전용 integration/feature worktree를 만들고 최신 `origin/win-android-release`를 먼저 merge한다. 충돌 해결·iOS 수정·검증 뒤 승인된 결과만 로컬 `mac-ios-release`에 merge하고 `origin/mac-ios-release`로 push한다.
- `mac-ios-release`에서 기능 코드를 직접 편집하지 않는다. integration/feature 브랜치의 검증된 변경만 반영한다.
- `main` 직접 커밋·push, rebase, tag 생성, 배포는 별도 사용자 승인 없이는 수행하지 않는다. 최종 반영은 최신 Windows 변경을 포함한 iOS 통합 브랜치의 양 플랫폼 검증 뒤 PR/merge로 진행한다.
- Claude Code와 Codex가 동시에 작업하면 에이전트별 Git worktree를 사용하고 같은 파일을 동시에 수정하지 않는다.
- 다른 에이전트의 브랜치·worktree·커밋을 reset, clean, stash, checkout 등으로 제거하지 않는다.
- 브랜치 생성과 커밋, 플랫폼 release 통합은 작업지시서 또는 사용자의 현재·상시 지시가 허용한 범위에서만 수행한다.
- 커밋 메시지는 `[codex|claude] 영역: 요약` 형식을 사용한다.

## 검증과 완료 보고

- 코드 변경 후 저장소가 지정한 format check, `flutter analyze`, 관련 테스트를 실행한다.
- 기존 실패가 있으면 새 실패와 구분해 기준선과 증거를 보고한다.
- 새 비즈니스 로직에는 위험도에 맞는 테스트를 추가한다.
- DB 변경에는 RLS, 권한 경계, 실패 경로 검증안을 포함한다.
- 완료 보고에는 변경 파일, 동작 요약, 실행한 검증과 결과, 미실행 검증과 이유, 발견 이슈, 사람 검증 항목을 포함한다.
- 검증하지 않은 사항을 완료됐다고 표현하지 않는다.

## 교차 리뷰

- 리뷰는 correctness, 보안·개인정보, 데이터 손실, 법무 문구, 회귀, 테스트 공백 순으로 본다.
- 지적에는 파일·라인, 발생 조건, 영향, 최소 수정안을 포함한다.
- 두 에이전트 의견이 다르면 자동 채택하지 않는다. 확인된 사실, 선택지, 영향, 권고를 정리해 황정현 CTO가 결정한다.
