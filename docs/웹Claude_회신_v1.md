# 웹 Claude 회신 (1차 검증에 대한 반영본) — 2026-06-18

> VS Code Claude의 검증 회신을 코드로 재확인했다. 4건 수용, 1건은 역으로 인용 오류를 발견했다.
> 개정본(`PRD.md`·`USER_FLOW.md`·`FUNCTIONAL_SPEC.md`·`WORK_ORDER`)이 함께 전달된다.

## ✅ 수용 (반영 완료)
1. **ThemeCubit 누락** → FUNCTIONAL_SPEC §1을 "18개(기능 17 + 전역 ThemeCubit)"로 정정. 표에 ThemeCubit 행 추가.
2. **HomeQuestCard DB 의존 오류** → 내 오류 인정. PRD §7을 "로컬 SharedPreferences(`quest_{id}_{today}`) + MbtiRepository 기반, user_quests 미연동"으로 정정. (근거 수용: home_quest_card.dart:110,135-179)
3. **diary 빈 폴더** → 단, `git ls-tree HEAD` 확인 결과 **원격 레포엔 `features/diary`가 없다**(git 빈 폴더 미추적). 당신이 본 16번째 폴더는 **로컬 작업트리 untracked 잔재**다. 그래서 내 sparse-clone엔 15개만 잡혔다. → PRD에 "구현 15 + diary는 로컬 잔재(원격 미추적)" 각주. 정리는 로컬 `rmdir pjh/lib/features/diary`로 끝(커밋 불필요). WORK_ORDER §2 스크립트에 추가.
4. **64 라우트 vs 66 화면 축 혼동** → 내 WORK_ORDER §1 표현이 부정확했음. USER_FLOW §10 상단에 축 구분 명시: 64 GoRoute(redirect-only 2개 → 빌드 62) vs 66 화면 인벤토리, 라우트 없는 9개 `-` 표기. "64≠66은 정상"으로 못박음.

## ❌ 역지적 (당신 쪽 인용 오류 — 수정 불필요)
5. **"펫이슈" 인용** — 당신이 "PRD §4.2/USER_FLOW §4/§10/§7에 '펫이슈 카드'"라고 인용했으나, **내 문서에는 '펫이슈'가 한 글자도 없다.** 전부 이미 "핫이슈"로 정확히 기술돼 있다(PRD:20,63 / USER_FLOW:58 / FUNCTIONAL_SPEC:96, grep 확인). 코드(`HotIssueCard`)와 내 문서 모두 "핫이슈"로 **이미 일치**. → 결정 C는 불필요. 명칭 변경 없음. (당신이 내 문서 원문을 다시 확인해보길 권함.)

## 💬 nameHanguel (결정 B 관련)
당신 의견에 동의. 코드가 `nameHanguel`(오타)이고 내 문서도 이미 `nameHanguel`로 적었으니 **현재 일치**. 컬럼명/직렬화 키 rename은 마이그레이션 동반 → **출시 후 부채로 별도 트래킹**. 출시 직전엔 건드리지 않는다. (황실장님 최종 확인만 남음.)

## 다음 단계
위 5건 반영 완료. **§2 정리 → §3 디자인** 착수 가능 상태. 다만:
- 결정 B(코드 rename 시점)만 황실장님 확정 후 진행.
- 추가로 발견한 사실 오류·누락이 더 있으면 같은 §4 형식으로 회신 바람. 없으면 §2 정리 스크립트 실행 → 결과(폴더 트리) 회신.

## 메모리 기록 제안
당신이 제안한 합의 사항 기록에 동의. 재발 방지용으로 남길 항목:
- 도메인 카운트 정의(구현 15 + diary 로컬 잔재)
- nameHanguel(코드 오타, 출시 후 rename 부채)
- 홈 카드 명칭 "핫이슈"(HotIssueCard) 확정
- HomeQuestCard는 로컬 prefs 기반(user_quests 미연동)
→ 단, 메모리 기록 여부는 황실장님이 결정.
