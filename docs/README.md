# 펫페이스 문서 지도 (docs/README.md)

> **단일 진실 원칙**: 현행 사실은 아래 현행 문서만 본다. 나머지는 `archive/`(역사 자료)·`qa/`·`legal/`.
> **기준 시점**: 2026-07-23 / `codex/post-merge-full-app-audit-20260722` 로컬 브랜치 / UI/UX W0~W6 로컬 구현·검증 완료
> **검증 기준**: iPhone 17 Simulator light/dark 실화면, 320×568·200% 글자 widget 회귀, `flutter analyze --no-pub`, 전체 `flutter test --no-pub` 788건, iOS release no-codesign build.

## 현행 문서 (수정 대상)
| 문서 | 역할 |
|---|---|
| `PRD.md` | 제품 요구사항 — 현재 구현 기준 |
| `USER_FLOW.md` | 사용자 플로우 — 실제 라우팅 기준 (핵심 66행 화면 인벤토리 포함) |
| `FUNCTIONAL_SPEC.md` | 기능명세 — 도메인별 상태·데이터·인터랙션 |
| `design/DESIGN_BASELINE.md` | 디자인 토큰 + 공용 컴포넌트 + 화면 비교 프레임 |
| `DEVELOPER_GUIDE.md` | 개발 가이드 (기존 유지) |

## 작업 협업 문서
| 문서 | 역할 |
|---|---|
| `AGENT_COLLABORATION.md` | Claude × Codex 역할·브랜치·worktree·리뷰·자동화 운영 |
| `MAC_MINI_HANDOFF.md` | Mac mini Codex 첫 실행·Windows→iOS 통합·검증·인계 정본 |
| `AUTO_ORCHESTRATOR.md` | 한 주제 입력부터 AI 토론·합의·승인·구현·교차 리뷰까지 자동화 |
| `WORK_ORDER_TEMPLATE.md` | 공통 작업지시서 템플릿 |
| `DECISION_LOG.md` | 에이전트 의견 충돌과 중요 결정 기록 |
| `work-orders/` | Claude·Codex별 승인된 작업지시서와 교차 검토 요청 |
| `reviews/uiux_code_audit_2026-07-13.md` | 홈·AI 분석 제외 전 화면 UI/UX·코드 사전 감사 |
| `work-orders/2026-07-14-uiux-overhaul-master.md` | 전 화면 신뢰도 개선 단계별 마스터 작업지시서 |
| `reviews/2026-07-22-uiux-product-trust-audit.md` | 홈·AI 콘텐츠를 제외한 UI/UX 신뢰도 감사와 구현 후 재검토 |
| `mockups/2026-07-22-uiux-direction-discussion.md` | 사용자 승인 Set A~D 목업과 구현 대응 기록 |
| `work-orders/2026-07-22-uiux-trust-redesign-master.md` | W0~W6 exact manifest·보호 계약·검증 정본 |
| `WORK_ORDER_claude-design.md` | VS Code Claude Code 작업지시서 + 웹↔VS Code 협업 프로토콜 |
| `웹Claude_회신_v1.md` | 1차 검증 핑퐁 회신 (작업 산출물) |

## 폴더 구조
```
docs/
├── README.md / PRD.md / USER_FLOW.md / FUNCTIONAL_SPEC.md   (현행)
├── WORK_ORDER_claude-design.md / 웹Claude_회신_v1.md          (협업)
├── DEVELOPER_GUIDE.md                                       (기존 유지)
├── design/DESIGN_BASELINE.md
├── archive/   planning(초기기획 6종) · develop(작업일지) · plans(sprint)
├── legal/     약관_개인정보_커뮤니티가이드.md
└── qa/        검증 체크리스트 6종
```
- `archive/`는 **읽기 전용**(역사 자료). 수정 대상 아님.

## 운영 원칙
1. 버전 접미사(`_v2`/`_updated`) 금지 — 파일 하나를 git 히스토리로 관리.
2. 현행 사실은 위 현행 문서만 본다.
3. 코드와 문서 불일치 시 근거(파일:라인)로 판정 후 문서 갱신.
4. 홈·AI 분석의 콘텐츠 재설계는 이번 W0~W6 범위 밖이다. 공용 5탭 shell 회귀만 검증한다.
5. 운영 DB/RPC·Edge·APNs·signing·TestFlight·스토어 배포는 로컬 UI/UX 검증 완료와 별개의 승인 단계다.

## 작성 근거 (코드 역추출)
- 라우팅: `core/navigation/app_router.dart` — GoRoute 선언 **66개**. 화면 인벤토리 66행과 숫자가 같아도 라우트와 핵심 화면 목록은 별개 축이다.
- 화면: `features/*/presentation/pages` — **78개 page source**. `USER_FLOW.md`의 핵심 66행은 전체 파일 인벤토리가 아니다.
- 도메인: 원격 `features/` 기준 **구현 15개**(auth·chat·emotion·feed_hub·fortune·health·home·mbti·my·news·onboarding·pets·profile·quiz·social). `diary`는 원격 미추적 빈 폴더(로컬 잔재)라 제외. CLAUDE.md 12개는 부가기능(fortune·mbti·news·quiz) 누락분 수정 필요.
- 상태: BLoC/Cubit **18개** = 기능 17개 + 전역 ThemeCubit.
- 데이터: domain/entities (Pet·EmotionAnalysis·HealthRecord 등). ※ `Pet.nameHanguel`은 코드 오타이나 출시 후 부채로 보류(문서를 코드에 맞춤).
- 디자인: `shared/themes/app_theme.dart` · `shared/widgets`(공용 위젯 22개).

## 2026-07-22 UI/UX 구현 상태

- W0 공용 shell: 루트 5화면에만 동일 위계 하단 탭을 표시하고 task/detail에서는 숨긴다.
- W1 인증·온보딩: Apple/Google/Kakao/이메일 계약, 약관 실패 복구, 첫 펫 등록 건너뛰기와 재진입을 보존한다.
- W2 MY·반려동물: 대표 반려동물을 계정 단위로 선택하고 다음 건강 일정을 연결한다. M1 migration은 로컬 파일만 작성했으며 운영 DB에 적용하지 않았다.
- W3 피드·커뮤니티: 사진 중심 `피드`와 주제 중심 `커뮤니티`를 구분하고 스토리·동영상·안전하지 않은 팔로워 전용 공개를 약속하지 않는다.
- W4 건강: 다음 케어 중심 루트와 5종 full task editor, 안전한 의료 문구, PDF/알림 상태를 정리했다.
- W5 채팅·알림: 1:1/그룹 생성, 사진 최대 10장과 동일 요청 재시도, 관리자/멤버 권한, 나가기 pending, dark mode를 검증했다.
- W6 정본·회귀: 레거시 작성의 안전하지 않은 팔로워 공개 선택을 제거하고 빈 피드 CTA를 canonical 작성 화면에 연결했다. 레거시 편집은 기존 audience 값을 보존하며, 전체 788건과 iOS no-codesign build를 재검증했다.

## 핑퐁 합의 기록 (2026-06-18, 역사 근거)
도메인 카운트 정의 / `nameHanguel` 부채 보류 / 홈 카드 명칭 "핫이슈"(HotIssueCard) / HomeQuestCard 로컬 prefs 기반(user_quests 미연동) / BLoC 18개. 당시 라우트·화면 수치는 역사 기록이며 위 2026-07-22 코드 역추출 수치를 우선한다.
