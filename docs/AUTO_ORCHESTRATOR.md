# Claude × Codex 자동 오케스트레이터

> 권장 실행 경로는 `scripts/agent-consensus.mjs` V2다. 기존
> `scripts/agent-collab.mjs`는 진행 중인 기존 run을 재개할 때만 사용한다.

## V2가 고정하는 협업 방식

V2는 역할을 라운드마다 바꾸지 않는다.

```text
Codex 기획·작업지시서 작성
  → 정확한 외부 검토 파일 승인
  → Claude Opus 4.8 독립 검토
  → Codex가 지적 수용·반박·수정
  → Claude가 같은 계획·manifest 해시로 최종 비준
  → 사람의 구현 승인 1회
  → 합의된 실행자가 격리 worktree에서 구현
  → Codex와 Claude가 각각 최종 코드 리뷰
```

- Claude는 Opus 4.8을 기본 모델로 사용한다. 다른 모델 fallback은
  `CLAUDE_FALLBACK_MODEL`을 명시한 경우에만 사용한다.
- Claude가 추가 자료를 요구하면 그 파일을 검토 manifest에 합친 뒤,
  새 해시의 번들을 다시 검토한다. 이전 검토 결과를 재사용하지 않는다.
- 양쪽이 실행자, 계획 해시, 파일 manifest 해시에 동의하고
  `blocker/high`가 0일 때만 구현 승인 단계로 넘어간다.
- 구현은 합의된 정확한 파일 목록만 허용하며, 그 밖의 파일이 바뀌면
  중단한다.
- 구현 전 Git 상태가 기획 시작 시점과 달라지면 중단한다. 최초 도입
  중에는 V2 자체 문서·스크립트·테스트 3개의 미커밋 상태만 예외로
  허용하며 앱 소스의 미커밋 변경은 허용하지 않는다.
- `commit`, `merge`, `push`, 배포, 운영 DB·Edge 변경은 자동화하지 않는다.

## V2 준비와 연결 확인

Codex 앱 내부 샌드박스가 아니라 사용자 로컬 PowerShell에서 실행한다.
그래야 로그인된 Codex CLI와 Claude Code CLI를 같은 로컬 스크립트가
호출할 수 있다.

```powershell
node scripts/agent-consensus.mjs preflight
node scripts/agent-consensus.mjs self-test --local
node scripts/agent-consensus.mjs self-test
```

- `preflight`: CLI 버전, 로그인, Git 상태 확인
- `self-test --local`: 외부 AI 호출 없이 로컬 구성만 확인
- `self-test`: 파일을 읽지 않는 고정 프롬프트로 양쪽 구조화 출력을
  각각 한 번 확인

## V2 주제 시작과 외부 검토 승인

```powershell
node scripts/agent-consensus.mjs start --topic "MY 알림 설정의 다음 구현 범위를 기획해줘"
```

Codex가 초안을 만들고 Claude 검토에 필요한 정확한 파일을 제안한다.
그 파일이 Anthropic 서비스 전송 승인 범위에 없으면 다음 상태에서
자동으로 멈춘다.

```text
awaiting_external_review_approval
```

출력된 경로를 확인한 뒤 같은 run을 다음처럼 재개한다.

```powershell
node scripts/agent-consensus.mjs approve-review <run-id> --code <검토승인코드>
```

이 승인은 출력된 정확한 경로를 해당 run에서 Claude로 전송·열람하는
것만 허용한다. `.env`, `secrets.dart`, 키·토큰·인증서와 비슷한 값은
경로 차단과 내용 검사 두 단계로 제외한다.

반복해서 쓰는 비밀 제외 소스 범위를 사용자가 명시적으로 상시
승인하려면 다음처럼 로컬 정책을 만들 수 있다. 정책은
`.agent-collab/runs/` 아래에 저장되어 Git에 포함되지 않는다.

```powershell
node scripts/agent-consensus.mjs authorize-source-review `
  --include "pjh/lib/**,pjh/test/**,supabase/functions/**" `
  --acknowledge-anthropic-transfer yes
```

상시 승인이 없거나 범위 밖 파일이 추가되면 다시 정확한 파일 승인을
요구한다.

## V2 합의·구현 승인·재개

합의가 끝나면 `awaiting_implementation_approval` 상태와 함께 실행자,
계획 해시, manifest 해시, 정확한 변경 파일, 승인 코드가 출력된다.
이 한 번의 구현 승인은 정확한 변경 결과를 Claude에 최종 read-only
리뷰 번들로 전송하는 것까지 포함한다.

```powershell
node scripts/agent-consensus.mjs approve <run-id> `
  --code <구현승인코드> --execute
```

실행자를 사람이 바꾸면 override 사실을 상태에 남긴다.

```powershell
node scripts/agent-consensus.mjs approve <run-id> `
  --code <구현승인코드> --executor claude `
  --acknowledge-claude-worktree-access yes --execute
```

Claude를 구현 실행자로 선택하면 Claude Code가 비밀 제외 규칙 아래
격리 worktree를 탐색할 수 있으므로 별도 명시 확인이 필요하다. Codex가
실행자일 때 Claude는 구현 후 생성된 정확한 변경 번들만 받는다.

상태 확인과 안전한 재개:

```powershell
node scripts/agent-consensus.mjs status <run-id>
node scripts/agent-consensus.mjs resume <run-id>
node scripts/agent-consensus.mjs execute <run-id>
```

모든 프롬프트, JSON 판정, 해시, 로그, 작업지시서는
`.agent-collab/runs/<run-id>/`에 보관한다. 같은 단계의 완료 산출물이
있으면 다시 호출하지 않으므로 한도 오류나 앱 재시작 뒤에도 같은
run을 이어간다.

---

## Legacy V1

아래 내용은 `scripts/agent-collab.mjs`로 생성한 기존 run의 설명이다.

## 목적

사용자가 한 번 주제를 입력하면 Claude와 Codex가 읽기 전용으로 초안·반론·수정안을 교환하고, 두 AI가 같은 작업지시서와 실행자에 동의했을 때만 사람에게 승인을 요청한다. 승인 후에는 전용 Git worktree에서 선택된 AI가 구현하고 반대 AI가 자동 교차 리뷰한다.

토론 전에 오케스트레이터가 Git 추적 상태, ignored/untracked 항목, 깊이 3의 폴더 구조, Markdown 제목·크기, `docs/README.md`, `.gitignore`를 공통 인벤토리로 만든다. 양쪽 AI는 동일 스냅샷을 사용하므로 서로 다른 탐색 범위로 결론이 흔들리거나 전체 저장소 스캔이 장시간 이어지는 것을 줄인다.

## 상태 흐름

```text
주제 입력
  → AI A 초안
  → AI B 반론·보완
  → 최대 3라운드 교대 토론
  → 합의 실패: 사람에게 쟁점 보고
  → 합의 성공: 작업지시서 + 실행자 + 승인 코드
  → 사람 승인
  → 전용 feature 브랜치/worktree 생성
  → 선택 AI 구현
  → 반대 AI read-only 리뷰
  → 사람 최종 검증·merge·push
```

## 안전 경계

- 토론 단계는 양쪽 모두 read-only다.
- 최대 토론 횟수는 기본 3회, 최대 5회다.
- `blocker/high` 이슈가 남거나 실행자 의견이 다르면 자동 실행하지 않는다.
- 실행 전 임의 승인 코드를 요구한다.
- 토론 이후 기준 브랜치 HEAD가 바뀌면 오래된 계획 실행을 차단한다.
- 실행은 별도 `feature/auto-*` 브랜치와 worktree에서 한다.
- push, merge, rebase, tag, 배포, 운영 DB 실행은 금지한다.
- 구현 후 반대 AI 리뷰가 끝나도 자동 커밋·merge·push하지 않는다.

## 준비 확인

```powershell
node scripts/agent-collab.mjs preflight
```

Claude Code 로그인, Codex 로그인, CLI 버전, Git 상태를 확인한다.

Legacy run은 생성 당시의 스크립트와 환경 변수 설정을 따른다. V2의
Opus 4.8 기본 정책은 기존 run의 과거 검토 기록에 소급 적용하지 않는다.

구조화 출력 연결까지 실제로 시험하려면 다음을 한 번 실행한다. 이 명령은 양쪽 AI를 각각 한 번 호출한다.

```powershell
node scripts/agent-collab.mjs self-test
```

## 주제 시작

```powershell
node scripts/agent-collab.mjs start --topic "산책 기능의 MVP 범위와 구현 계획을 확정해줘"
```

기본 첫 작성자는 Codex다. Claude부터 시작하려면 다음처럼 지정한다.

```powershell
node scripts/agent-collab.mjs start --first claude --topic "카카오 인증 수정 계획을 검토해줘"
```

원본 프롬프트, 구조화된 응답, 합의 작업지시서, 상태는 `.agent-collab/runs/<run-id>/`에 저장된다. 이 폴더는 Git에 커밋하지 않는다.

## 승인과 자동 구현

합의가 끝나면 다음 형식의 명령이 출력된다.

```powershell
node scripts/agent-collab.mjs approve <run-id> --code <승인코드> --execute
```

이 한 번의 승인이 worktree 생성과 구현·교차 리뷰 시작을 허용한다. 기준 저장소가 더럽거나 기준 브랜치가 변경됐으면 실행은 중단된다.

합의된 작업이 삭제 전 조사처럼 읽기 전용 Phase A라면 worktree 없이 조사·교차 리뷰까지만 실행한다.

```powershell
node scripts/agent-collab.mjs approve <run-id> --code <승인코드> --investigate
```

중단된 읽기 전용 조사는 같은 승인 기록으로 다시 실행할 수 있다. 오케스트레이터가 해시·Git 상태·링크·참조 증거를 먼저 생성하고 AI는 그 고정 증거만 분석한다.

```powershell
node scripts/agent-collab.mjs investigate <run-id>
```

## 상태 확인

```powershell
node scripts/agent-collab.mjs status <run-id>
```

최대 라운드에서 합의하지 못했지만 수정 가능한 쟁점이라면 기존 기록을 유지한 채 토론을 이어간다.

```powershell
node scripts/agent-collab.mjs continue <run-id> --rounds 1
```

두 AI가 안전 경계와 실행자에는 동의하면서 문구 개선 때문에 `revise`를 반복하면 마지막 수정안을 고정해 비준한다. 양쪽 모두 blocker/high 문제가 없다고 독립 승인해야 합의가 성립한다.

```powershell
node scripts/agent-collab.mjs ratify <run-id>
```

주요 상태:

- `discussing`: AI 토론 중
- `needs_human_decision`: 합의 실패, 사람 판단 필요
- `awaiting_approval`: 합의 완료, 실행 승인 대기
- `approved`: 승인됐지만 아직 미실행
- `executing`: 전용 worktree에서 구현 중
- `execution_failed`: 실행 중단, 로그 확인 필요
- `awaiting_final_approval`: 구현과 교차 리뷰 완료, 사람의 최종 검증 대기

## 운영 원칙

- 주제 입력은 구현 승인이 아니라 토론 승인이다.
- 승인 코드는 합의된 작업지시서 한 건에만 적용한다.
- 권한·네트워크·도구 문제로 실행이 막히면 자동 우회하지 않고 `execution_failed`로 남긴다.
- 실기기, 운영 DB, 법무 승인, merge·push는 계속 사람이 담당한다.
