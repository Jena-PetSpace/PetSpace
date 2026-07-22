# 작업지시서: AGENT-SETUP-001 — Claude Code 교차 검토

- 상태: 승인
- 작성자: Codex
- 승인자: 황정현 CTO
- 담당: claude-code
- 교차 리뷰어: human
- 기준 브랜치: `win-android-release`
- 작업 브랜치: `feature/agent-setup`
- 작업 방식: read-only 검토
- 관련 문서: `AGENTS.md`, `docs/AGENT_COLLABORATION.md`, `docs/reviews/codex_onboarding_audit_2026-07-13.md`

## 목표

Codex가 추가한 Claude × Codex 협업 설정이 기존 Claude Code 작업 방식, PetSpace 실제 코드, 출시 운영 원칙과 충돌하지 않는지 검토한다. 이번 작업에서는 파일을 수정하거나 커밋하지 않는다.

## 검토 대상

- `AGENTS.md`
- `.codex/config.toml`
- `CLAUDE.md` 변경분
- `docs/README.md` 변경분
- `docs/AGENT_COLLABORATION.md`
- `docs/WORK_ORDER_TEMPLATE.md`
- `docs/DECISION_LOG.md`
- `docs/reviews/codex_onboarding_audit_2026-07-13.md`

기준 브랜치와의 전체 변경은 다음 명령으로 확인한다.

```powershell
git diff win-android-release -- AGENTS.md .codex/config.toml CLAUDE.md docs/README.md docs/AGENT_COLLABORATION.md docs/WORK_ORDER_TEMPLATE.md docs/DECISION_LOG.md docs/reviews/codex_onboarding_audit_2026-07-13.md
```

## 검토 기준

1. `CLAUDE.md`의 `@AGENTS.md` import가 현재 Claude Code 환경에서 정상 동작하는가?
2. 공용 규칙과 `.claude/`의 기존 agents·skills·권한 설정이 충돌하는가?
3. package ID, 버전, targetSdk, feature 구조가 실제 코드와 일치하는가?
4. push·merge·배포·운영 DB 실행을 사람만 수행한다는 경계가 명확한가?
5. 신규 코드 규칙과 기존 기술부채가 적절히 분리됐는가?
6. 작업지시서 → 구현 → 교차 리뷰 → 사람 결정 흐름에 빠진 단계가 있는가?
7. 민감 RPC, 비밀 파일, 법무·위치정보 제약에서 누락된 항목이 있는가?
8. Claude Code가 실제 작업을 수행할 때 모호하거나 서로 충돌하는 문장이 있는가?

## 수정 금지

- 모든 파일
- Git index, 커밋, 브랜치, stash
- 앱 코드, Supabase, CI

문제를 발견해도 이번 검토에서는 직접 고치지 않는다.

## 결과 형식

```markdown
# Claude Code 교차 검토 결과

## 차단 이슈
- [심각도] 파일:라인 — 문제, 영향, 최소 수정안

## 개선 권고
- 파일:라인 — 개선 이유와 제안

## 확인 완료
- 충돌 없이 확인된 항목

## Codex 의견과 다른 부분
- 확인된 사실
- Claude Code 의견
- 선택지별 영향
- 황정현 CTO 결정 필요 사항

## 최종 판정
- 승인 가능 | 수정 후 재검토 | 적용 보류
```

차단 이슈가 없으면 `발견된 차단 이슈 없음`이라고 명시하고, 검증하지 못한 항목은 별도로 기록한다.
