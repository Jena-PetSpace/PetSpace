# 펫페이스 문서 지도 (docs/README.md)

> **단일 진실 원칙**: 현행 사실은 아래 현행 문서만 본다. 나머지는 `archive/`(역사 자료)·`qa/`·`legal/`.
> **기준 시점**: 2026-06-18 / `win-android-release` 브랜치 / Sprint 2 완료
> **검증**: 웹 Claude ↔ VS Code Claude 양방향 핑퐁으로 §1 사실검증 종료(커밋 `52f4657`).

## 현행 문서 (수정 대상)
| 문서 | 역할 |
|---|---|
| `PRD.md` | 제품 요구사항 — 현재 구현 기준 |
| `USER_FLOW.md` | 사용자 플로우 — 실제 라우팅 기준 (66행 화면 인벤토리 포함) |
| `FUNCTIONAL_SPEC.md` | 기능명세 — 도메인별 상태·데이터·인터랙션 |
| `design/DESIGN_BASELINE.md` | 디자인 토큰 + 공용 컴포넌트 + 화면 비교 프레임 |
| `DEVELOPER_GUIDE.md` | 개발 가이드 (기존 유지) |

## 작업 협업 문서
| 문서 | 역할 |
|---|---|
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

## 작성 근거 (코드 역추출)
- 라우팅: `core/navigation/app_router.dart` — GoRoute **64개**(redirect-only 2개 제외 시 빌드 62). 화면 인벤토리 66행은 별개 축(64≠66 정상).
- 화면: `features/*/presentation/pages` — **70개 page**.
- 도메인: 원격 `features/` 기준 **구현 15개**(auth·chat·emotion·feed_hub·fortune·health·home·mbti·my·news·onboarding·pets·profile·quiz·social). `diary`는 원격 미추적 빈 폴더(로컬 잔재)라 제외. CLAUDE.md 12개는 부가기능(fortune·mbti·news·quiz) 누락분 수정 필요.
- 상태: BLoC/Cubit **18개** = 기능 17개 + 전역 ThemeCubit.
- 데이터: domain/entities (Pet·EmotionAnalysis·HealthRecord 등). ※ `Pet.nameHanguel`은 코드 오타이나 출시 후 부채로 보류(문서를 코드에 맞춤).
- 디자인: `shared/themes/app_theme.dart` · `shared/widgets`(공용 위젯 22개).

## 핑퐁 합의 기록 (2026-06-18)
도메인 카운트 정의 / `nameHanguel` 부채 보류 / 홈 카드 명칭 "핫이슈"(HotIssueCard) / HomeQuestCard 로컬 prefs 기반(user_quests 미연동) / BLoC 18개 / 라우트 64≠화면 66 축 구분. VS Code 측 `project_docs_verification_consensus.md`와 동일 내용.
