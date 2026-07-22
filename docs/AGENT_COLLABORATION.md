# Claude × Codex 협업 운영

> 공용 규칙은 루트 `AGENTS.md`, 현행 제품 문서는 `docs/README.md`, 도구별 설정은 각 도구 파일에서 관리한다.

## 역할

| 영역 | 주 담당 | 교차 검토 |
|---|---|---|
| 출시 직전 인증·민감 RPC·배포 | 기존 담당 유지 | Codex read-only |
| 독립 신규 기능 | 작업지시서에서 지정 | 반대 에이전트 read-only |
| 제품 요구사항·우선순위 | 웹 Claude 초안 | 필요 시 Codex 허점 검토 |
| 플랫폼 release 브랜치 merge·push | 승인된 담당 에이전트 | 반대 에이전트 diff 리뷰 + 사람 실기기 확인 |
| `main` 최종 반영·운영 DB·Edge·배포 | 황정현 CTO | 에이전트 자동 실행 금지 |

## 표준 사이클

1. `docs/WORK_ORDER_TEMPLATE.md`로 작업지시서를 작성하고 사람이 승인한다.
2. 담당 에이전트가 관련 코드와 문서를 읽고 충돌·미확정 위험을 보고한다.
3. 전용 `feature/<작업명>` 브랜치와 worktree에서 허용 범위만 구현한다.
4. format check, analyze, 관련 테스트를 실행하고 완료 보고를 작성한다.
5. 반대 에이전트가 기준 브랜치 대비 diff를 read-only로 리뷰한다.
6. 의견 충돌은 자동 채택하지 않고 `docs/DECISION_LOG.md` 형식으로 사람에게 올린다.
7. 사람의 실기기 검증과 상시/현재 승인이 있으면 담당 에이전트가 해당 플랫폼 release 브랜치까지만 merge·push한다. `main`, 운영 DB, Edge, 스토어 배포는 황정현 CTO가 별도로 승인한다.

## 플랫폼 통합 사이클

1. Windows 작업은 `feature/*` → `win-android-release` → Android 검증 → push 순서로 진행한다.
2. Mac mini는 `origin/mac-ios-release` 기반 integration worktree를 만들고 최신 `origin/win-android-release`를 merge한다.
3. Mac에서 충돌 manifest를 먼저 확정하고 공용 Dart 계약을 보존하면서 iOS 설정·빌드 차이만 수정한다.
4. `flutter analyze`, 전체 테스트, `flutter build ios --release --no-codesign`, 가능한 iOS 실기기 검증을 통과한 결과만 `mac-ios-release`에 반영한다.
5. `mac-ios-release`가 최신 `win-android-release`를 포함하고 Android·iOS 검증이 모두 끝난 뒤에만 `main` 반영을 제안한다.
6. 자세한 Mac 첫 실행·인계 기준은 `docs/MAC_MINI_HANDOFF.md`를 따른다.

## UI/UX 탭 단위 사이클

2026-07-14 사용자 결정에 따라 앱 전반 UI/UX 개선은 하단 메뉴를 작업 단위로 삼고 `MY → 피드 → 건강관리 → AI 분석 → 홈` 순서로 진행한다. 기존 기능 묶음형 wave보다 이 순서가 우선하며, AI 분석과 홈의 보호 범위는 각 탭 시작 전 사용자가 별도로 해제해야 한다.

각 탭은 다음 게이트를 독립적으로 통과한다.

1. Codex가 해당 탭의 화면·라우트·파일·상태·위험을 조사하고 정확한 manifest와 작업지시서 초안을 작성한다.
2. Codex가 핵심 화면 3~5개의 가시 목업 초안을 만든다. Claude가 같은 manifest·목업·실기기 근거를 read-only로 리뷰하고, 양쪽이 합의한 목업만 사용자에게 제시한다.
3. 사용자가 목업과 정확한 구현 범위를 승인하기 전에는 Flutter UI 코드를 수정하지 않는다.
4. 승인 뒤 Codex가 구현 초안을 작성하고 자체 diff·기능 불변 검사를 수행한다. Claude가 같은 diff를 독립 리뷰한다.
5. Codex가 format/analyze/대상 테스트/전체 기준선/diff/hash 검증을 수행하고 판정 초안을 작성한다. Claude가 검증 증거와 코드를 독립 리뷰한다.
6. Codex가 실기기 체크리스트와 사용자 캡처 비교 초안을 작성하고 Claude가 판정을 리뷰한다. 자동 검증으로 대체할 수 없는 항목은 사람 검증 대기로 유지한다.
7. blocker/high, manifest 불일치, 기능·데이터·법무 변경 또는 양쪽 불일치는 자동 채택하지 않고 사용자에게 쟁점만 보고한다.
8. 한 탭이 사용자 실기기 승인을 받아 동결된 뒤에만 다음 탭으로 이동한다.

하단 5탭 내비게이션 자체의 구조·활성 상태·라벨·색·배지·중앙 버튼은 별도 공통 작업이다. 사용자가 기획 방향을 확정하기 전에는 어떤 탭 wave에서도 수정하지 않는다.

## 병렬 작업

- 같은 작업 폴더에서 두 에이전트를 동시에 실행하지 않는다.
- 병렬 작업은 에이전트별 Git worktree를 만든다.
- 작업지시서에 담당, 브랜치, worktree, 수정 허용 파일을 반드시 기록한다.
- 겹치는 파일이 발견되면 양쪽 모두 수정을 멈추고 담당을 다시 정한다.

## 자동화 단계

### 1단계 — 현재

- 작업지시서, feature 브랜치, worktree, 수동 교차 리뷰를 정착시킨다.
- 첫 Codex 작업은 read-only 코드 감사로 한다.
- 출시 크리티컬 패스의 기존 담당을 바꾸지 않는다.

### 2단계 — 파일럿 후

- 저장소 스크립트로 format check, analyze, unit test, diff check를 한 번에 실행한다.
- 금지어와 Presentation 직접 Supabase 호출 검사는 기존 부채를 기준선으로 두고 report-only로 시작한다.
- 오탐이 충분히 낮은 검사만 차단 게이트로 승격한다.

### 3단계 — 출시 안정화 후

- PR CI에서 같은 검증 스크립트를 실행한다.
- AI 리뷰는 비차단 코멘트로 시작한다.
- API 키 최소 권한, 외부 전송 제외 경로, 로그 보존 정책을 먼저 확정한다.

## 첫 파일럿 후보: 산책

산책은 `supabase/migrations/H1_walk_records.sql`, RLS, `location_access_log`, 약관 문구가 준비됐고 앱 feature는 아직 없어 독립 구현 후보로 적합하다. 다만 개인위치정보 기능이므로 다음 항목을 작업지시서에서 먼저 확정한다.

- LBS 신고 상태와 제공 범위
- 위치 권한 거부·철회 UX
- 백그라운드 위치 수집 여부
- 경로 보존·삭제·탈퇴 처리
- 취급대장 기록 검증
- Android/iOS 실기기 검증 조건

확정 전에는 스키마나 위치 수집 코드를 변경하지 않는다.
