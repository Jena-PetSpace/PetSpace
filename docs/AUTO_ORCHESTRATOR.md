# Claude × Codex 자동 오케스트레이터

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

Claude 호출의 기본 모델은 `claude-opus-4-8`이다. 계정에서 다른 정확한 모델 ID를 써야 할 때만 `CLAUDE_MODEL` 환경 변수로 덮어쓴다. 별도 지정 없이 Fable 계열 모델로 대체하지 않는다.

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
