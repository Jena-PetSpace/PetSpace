# Codex 온보딩 읽기 전용 감사

- 기준일: 2026-07-13
- 기준 브랜치: `win-android-release` at `024d685`
- 감사 범위: 저장소 구조, 공용 문서, Flutter 아키텍처, Supabase 스키마, CI, Claude 설정
- 코드 변경: 없음

## 확인된 구조

- Flutter 앱 루트: `pjh/`
- 실제 feature 폴더: 15개
- `GoRoute(` 선언: 64개
- `pjh/lib/` Dart 파일: 475개
- `supabase/` SQL 파일: 12개
- `docs/` Markdown 파일: 39개
- `*_bloc.dart`/`*_cubit.dart` 파일: 21개. 문서의 18개 정의와 재대조 필요

## 협업 설정에서 반영한 사항

- 공용 규칙을 루트 `AGENTS.md`로 단일화
- `CLAUDE.md`에서 `@AGENTS.md`를 불러오고 Claude 전용 설명만 유지
- Android applicationId, 앱 버전, targetSdk, feature 목록 현행화
- 기존 `docs/` 정본 체계를 유지하고 중복 agent-context 문서 생성 방지
- 공통 작업지시서, 결정 기록, 교차 리뷰·worktree 운영 문서 추가
- Codex 프로젝트 설정을 workspace-write, network off, on-request 승인으로 제한

## 후속 결정 필요

### CI 자동 push

`.github/workflows/ci.yml`은 `contents: write` 권한으로 포맷 변경을 커밋하고 push한다. 에이전트와 자동화 모두 push 금지로 통일하려면 별도 CI 작업에서 검사 전용 포맷 단계와 `contents: read`로 바꿔야 한다.

### 기존 Presentation의 직접 Supabase 호출

인증 OTP, chat 설정, 위치·해시태그, MY·프로필 등 기존 Presentation 코드에 직접 호출이 존재한다. 신규 코드부터 금지하고 기존 호출은 기술부채 기준선으로 관리한다.

### 기존 auth.users FK

`supabase/petspace_setup.sql`의 포인트 거래, 퀘스트 진행, 구매, 뱃지, 건강 히스토리 테이블은 `auth.users`를 직접 참조한다. 마이그레이션 또는 예외 유지 결정을 받기 전에는 자동 변경하지 않는다.

### 사용자 노출 진단 문구

AI 결과의 `진단 소견`, `종합 진단`은 제품·법무 정책 검토가 필요하다. 반면 “수의학적 진단을 대체하지 않는다”는 면책 문구는 허용 대상으로 분리한다.

### Claude 로컬 ADB 명령

추적되지 않는 `.claude/settings.json` 일부 명령은 이전 패키지명 `com.petspace.app`을 사용한다. 로컬 설정 소유자가 `com.jena.petspace`로 갱신해야 한다.

## 산책 파일럿 판단

`supabase/migrations/H1_walk_records.sql`, RLS, 취급대장 트리거, 위치 약관은 준비됐고 앱의 `features/walk/`와 라우트는 아직 없다. 독립 신규 기능 후보이지만 개인위치정보를 다루므로 LBS 신고, 권한 철회, 백그라운드 수집, 보존·삭제, 실기기 검증 조건이 승인된 작업지시서가 먼저 필요하다.
