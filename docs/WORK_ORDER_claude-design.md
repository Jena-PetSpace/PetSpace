# 작업지시서 — 코드 기준 문서 현행화 검증 & 클로드 디자인 준비

> **수신**: VS Code Claude Code
> **발신**: 황정현(CTO) 경유, 웹 Claude(기획·설계 검토)
> **첨부**: `README.md` · `PRD.md` · `USER_FLOW.md` · `design/DESIGN_BASELINE.md` · `FUNCTIONAL_SPEC.md`
> **브랜치**: `win-android-release`

---

## 0. 협업 구조 (중요)

이 작업은 **웹 Claude ↔ VS Code Claude 간 문서 리뷰 핑퐁** 방식이다.

```
웹 Claude (문서 작성)
   → 황정현이 VS Code Claude에 전달
   → VS Code Claude가 코드 대조 검증 + 이견/보완 작성 (아래 §4 형식)
   → 황정현이 그 응답을 웹 Claude에 전달
   → 웹 Claude가 반영/재반론
   → 합의될 때까지 반복
```

VS Code Claude는 **실제 레포 전체에 접근 가능**하므로, 웹 Claude가 sparse-checkout(docs+pjh 일부)으로 본 것보다 정확하다. **틀린 부분을 적극적으로 잡아달라.** 동의만 하지 말고 근거(파일 경로·라인) 들어 반박할 것.

---

## 1. 1단계: 문서 사실 검증 (최우선)

첨부 문서를 **현재 코드와 대조**하여 사실 오류를 잡는다. 특히:

1. **라우트 정확성** — `app_router.dart`의 64개 path와 `USER_FLOW.md §10` 인벤토리 66행이 일치하는가? 누락·중복·이름 불일치?
2. **도메인/화면 수** — 15개 도메인·70개 page가 맞는가? doc-comment 없는 화면의 실제 역할은?
3. **데이터 모델** — `PRD §4`·`FUNCTIONAL_SPEC §2`의 엔티티 필드가 최신 코드와 일치하는가? (특히 EmotionScores 9종, HealthRecordType 5종, Pet 여권 필드)
4. **홈 리디자인 상태** — `home_page.dart`의 "매거진/핫이슈 시안 + 레거시 카드 임시 배치" 기술이 맞는가? 시안 전환 범위는?
5. **상태관리** — BLoC/Cubit 17개 매핑이 맞는가? FeedBloc↔CommunityCubit 분리 의도 기술이 정확한가?
6. **디자인 토큰** — `DESIGN_BASELINE.md`의 컬러/위젯 22개가 `app_theme.dart`·`shared/widgets`와 일치하는가?

> 검증 중 **추가 발견**(문서에 없는 기능·화면·부채)이 있으면 반드시 기록.

---

## 2. 2단계: docs 폴더 정리 (검증 통과 후)

```bash
cd <레포루트>
mkdir -p docs/archive/planning docs/archive/develop docs/archive/plans docs/design docs/legal

git mv "docs/PetSpace+document.md"                  docs/archive/planning/
git mv "docs/PetSpace+document_v2.md"               docs/archive/planning/
git mv "docs/PetSpace+document_updated.md"          docs/archive/planning/
git mv "docs/PetSpace_종합분석리포트.md"             docs/archive/planning/
git mv "docs/PetSpace_작업지시서_전체.md"            docs/archive/planning/
git mv "docs/PetSpace_감정분류개편_검토수정_최종본.md" docs/archive/planning/
git mv docs/develop/*              docs/archive/develop/ 2>/dev/null
git mv docs/superpowers/plans/*    docs/archive/plans/   2>/dev/null
rmdir docs/superpowers/plans docs/superpowers docs/develop 2>/dev/null
git mv "docs/법무검토_약관_개인정보_커뮤니티가이드.md" docs/legal/약관_개인정보_커뮤니티가이드.md

# 죽은 폴더 정리 (원격 미추적 로컬 잔재 — 커밋 무관)
rmdir pjh/lib/features/diary 2>/dev/null

# 검증·수정 완료된 신규 문서 배치
# README.md, PRD.md, USER_FLOW.md, FUNCTIONAL_SPEC.md → docs/
# DESIGN_BASELINE.md → docs/design/
# 이 작업지시서 → docs/WORK_ORDER_claude-design.md

git add docs
git commit -m "docs: 코드 기준 문서 현행화 + 초기 기획 archive 이관, 폴더 재구성"
```

**운영 원칙**: 버전 접미사(`_v2`/`_updated`) 금지 · 현행 사실은 4개 문서만 · archive는 읽기 전용.

---

## 3. 3단계: 클로드 디자인 준비 (정리 후)

`DESIGN_BASELINE.md §4` 비교 프레임으로, 우선 후보 3화면(/home, emotion+health result, /feed-hub)부터:
- 현재 UI 패턴·문제점 기록
- 디자인 토큰 추출본을 클로드 디자인에 등록할 형식(JSON/피그마)으로 정리
- 화면별 "현재 → 개선안" 비교표 초안

---

## 4. VS Code Claude 응답 형식 (이 틀로 회신)

```markdown
## 검증 결과 회신 — [날짜]

### ✅ 확인 (문서가 맞음)
- ...

### ❌ 사실 오류 (수정 필요)
| 위치 | 문서 기술 | 실제 코드 | 근거(파일:라인) |
|---|---|---|---|
| PRD §4.4 | 감정 9종 | ... | ... |

### ➕ 문서 누락 (추가 제안)
- ...

### 💬 이견 / 대안 제시
- (웹 Claude 판단에 대한 반론·다른 접근)

### ❓ 결정 필요 (황정현에게)
- ...
```

이 회신을 황정현이 웹 Claude에 그대로 전달하면, 웹 Claude가 항목별로 수용/재반론하여 다음 개정본을 낸다.

---

## 5. 주의
- 검증 전 정리(2단계)·디자인(3단계) 착수 금지. 사실 검증이 먼저다.
- 코드 변경은 이 작업 범위 아님(문서·정리 한정). 단, 문서와 코드 불일치 시 어느 쪽이 옳은지 의견 제시.
- 출시 리스크 항목(`PRD §7`)은 별도 트랙 — 이 작업에서 건드리지 않음.
