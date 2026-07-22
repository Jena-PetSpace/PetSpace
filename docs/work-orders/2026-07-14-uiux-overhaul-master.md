# 작업지시서: UIUX-20260714 — 홈·AI 분석 제외 전 화면 신뢰도 개선

- 상태: Claude Opus 4.8·Codex 3차 합의 완료 — 실제 UI 구현 전 사용자 목업 승인 필수
- 작성자: Codex
- 승인자: 황정현 CTO(양쪽 합의 범위의 단계별 구현 진행 승인)
- 담당: Wave 0 Codex 작성/Claude 검토, Wave 1 Claude 구현/Codex 검토, 이후 단계별 비준
- 교차 리뷰어: 해당 단계 비담당 AI
- 기준 브랜치: `win-android-release@024d685`
- 작업 브랜치: 단계별 `feature/uiux-<wave>`
- 전용 worktree: 실행자별 분리, 같은 파일 동시 수정 금지
- 관련 문서: `docs/reviews/uiux_code_audit_2026-07-13.md`, `docs/DECISION_LOG.md`

## 2026-07-14 사용자 재정렬 — 현재 실행 정본

기존 문서의 기능 묶음형 Wave 2~5는 감사 이력으로 보존하되, 실제 후속 실행은 하단 메뉴 기준 `MY → 피드 → 건강관리 → AI 분석 → 홈` 순서를 우선한다. 각 탭은 화면 인벤토리와 정확한 manifest를 새로 확정하고, 핵심 화면 3~5개만 한 번에 다룬다.

- 목업: Codex 초안 → Claude read-only 리뷰·합의 → 사용자 승인
- 구현: Codex 초안 구현·자체 검증 → Claude 독립 리뷰
- 자동 검증: Codex 실행·판정 초안 → Claude 증거·코드 독립 리뷰
- 실기기: Codex 체크리스트·캡처 비교 초안 → Claude 판정 리뷰 → 사용자 최종 승인
- 한 탭 완료·동결 뒤 다음 탭으로 이동
- AI 분석과 홈은 기존 보호 범위를 자동 해제하지 않으며, 각 탭 시작 전에 사용자 승인을 다시 받음
- 하단 5탭 UI 자체는 별도 기획이 정리될 때까지 수정 금지

현재 첫 작업은 MY 탭이며, 이미 완료된 Wave 1C의 기능 구조는 유지하고 실기기 캡처에서 확인된 반려동물 등록·관리 화면의 시각 밀도만 별도 Visual Polish 작업지시서로 다룬다. 기존 Wave 2~5 제목은 더 이상 실행 순서를 뜻하지 않는다.

## 목표

홈·AI 분석 화면의 현재 디자인은 보존하면서 나머지 58개 페이지를 하나의 신뢰도 높은 PetSpace 디자인 언어로 통일한다. 시각 변경 중 기존 기능·라우팅·상태·법무 문구·데이터 계약을 유지하고, 코드 감사에서 발견한 사용자 신뢰 저해 요소는 별도 합의 가능한 작업으로 분리한다.

## 선행 조건

- [x] 폴더 정리 실행 ID `20260713-PetSpace-Markdown-KEEP-CONSOLI-26f5` 완료 및 Claude·Codex 사후 리뷰 통과
- [x] Claude CLI 모델 `claude-opus-4-8` 확인
- [ ] Claude 기존 컨텍스트에서 비홈 레퍼런스 복구 결과 기록
- [ ] 보호 파일의 변경 전 Git hash와 회귀 캡처/테스트 기준 기록
- [ ] `DESIGN_BASELINE.md`의 v2 드리프트 해소안 양쪽 합의

## 확인된 사실

- 실제 홈 본체는 `features/social/presentation/pages/home_page.dart`이고 `/home` 라우트가 이를 사용한다.
- 보호 범위 제외 page 58개, presentation Dart 180개, 약 40,275줄이다.
- 숫자형 글자 크기 816건, Material 직접 색 658건, 숫자형 여백 403건, Semantics 12건이다.
- lightTheme는 v2, darkTheme와 `DESIGN_BASELINE.md`는 이전 규칙이 남아 있다.
- `flutter analyze --no-pub`는 2026-07-13 기준 0건이다.
- 상세 증거와 제한은 관련 감사서를 따른다.

## 수정 범위

- 허용 후보: 보호 경로 밖 `pjh/lib/features/*/presentation/**`
- 공용 변경 후보: `pjh/lib/shared/themes/**`, `pjh/lib/shared/widgets/**`
- 문서: `docs/design/DESIGN_BASELINE.md`, `docs/reviews/**`, `docs/work-orders/**`, 필요한 QA 체크리스트
- 테스트: 변경 기능의 `pjh/test/**`
- 새 파일: 공용 디자인 토큰·컴포넌트와 해당 테스트, 단계별 감사/검증 문서

직접 수정 금지:

- `pjh/lib/features/social/presentation/pages/home_page.dart`
- `pjh/lib/features/home/**`
- `pjh/lib/features/emotion/presentation/**`
- `/home` 탭 호스트 `pjh/lib/main_navigation.dart`
- `docs/legal/**`의 승인 문구 내용
- DB, migration, RPC, secrets, 인증 계약, 운영 설정
- `docs/archive/**`

공용 테마·컴포넌트 변경으로 보호 화면 렌더가 달라질 수 있으면 변경 전 영향 목록을 만들고 회귀 검증한다. 보호 화면을 직접 보정해야만 통과하는 공용 변경은 자동 진행하지 않는다.

## 요구사항

### Wave 0 — 계약 확정

1. 58개 페이지를 라우트·기능·상태·주요 컴포넌트·위험도와 1:1 매핑한다.
2. Claude 레퍼런스를 출처·적용 화면·채택/비채택 이유와 함께 정리한다.
3. v2 색, 타이포, spacing, radius, elevation, icon, motion, 접근성 계약을 문서와 코드 토큰에 일치시킨다.
4. 화면 상태 계약을 loading/empty/error/offline/content/disabled로 정의한다.
5. 공용 컴포넌트 API와 기존 화면 치환 기준을 먼저 비준한다.

### Wave 1 — 공용 시스템과 저위험 pilot

1. PageScaffold/AppBar/SectionHeader, 버튼, 입력, 선택·칩, 카드·목록, 상태·피드백 컴포넌트를 최소 집합으로 만든다.
2. profile 설정·help와 pets 관리 화면에 pilot 적용한다.
3. 법적 문구는 한 글자도 바꾸지 않고 레이아웃·가독성만 조정한다.
4. pilot 결과가 양쪽 리뷰와 실기기 또는 결정론적 캡처를 통과해야 다음 wave로 간다.

### Wave 2 — auth/onboarding

1. 로그인, 약관, 이메일 인증, 비밀번호 재설정, 프로필·펫 등록의 진행 구조와 CTA 위계를 통일한다.
2. OAuth·인증·온보딩 완료 조건과 라우팅은 변경하지 않는다.
3. 키보드, 작은 화면, text scale, 오류·재시도, 권한 거부 상태를 검증한다.

### Wave 3 — health/my/profile

1. 기록·필터·차트 주변 정보 위계, 편집 시트, 빈 상태, PDF 진입을 공용 패턴으로 통일한다.
2. 기존 건강 의미·면책·데이터 필드·이벤트를 바꾸지 않는다.
3. MY와 프로필 카드의 정보 밀도, 목록, 설정 진입을 같은 shell로 맞춘다.

### Wave 4 — feed_hub/social/chat

1. 발견·라운지, 피드·상세·댓글·검색·알림·프로필, 채팅 목록·상세·설정의 상태 표현을 통일한다.
2. 신고·차단·UGC 안전 기능과 게시물 카테고리·딥링크 계약을 보존한다.
3. 이미지 실패·페이지네이션·입력 중 키보드·네트워크 복구를 검증한다.

### Wave 5 — mbti/quiz/fortune/news

1. 놀이 기능도 공용 typography·spacing·surface 계약 안에서만 도메인 색을 사용한다.
2. 이모지는 종 구분·공유 등 승인된 예외만 유지하고 장식 남용을 금지한다.
3. 결과 공유·리워드 hook의 기존 동작을 바꾸지 않는다.

### 별도 P0 코드 신뢰도 작업지시서

다음은 디자인 파일 수정과 섞지 않고 Claude·Codex가 정확한 목록을 비준한 뒤 별도 실행한다.

- Repository 내부 오류와 사용자 안전 문구 분리
- `offline_manager.dart` placeholder의 제거/비활성/실구현 중 선택
- 미사용 `main_navigation_wrapper.dart` 삭제 증거 확정
- 중복 `@override`, 항상 실패하는 stub 인터페이스 등 정적·계약 부채

DB·기능 의미가 바뀌는 선택은 사용자의 기존 승인 범위를 넘으므로 자동 구현하지 않는다.

## 비요구사항

- 홈 또는 AI 분석 화면 재디자인
- 라우트 구조, BLoC 이벤트, Repository API, DB schema 변경
- 약관·개인정보·수의학 표현 재작성
- 신규 대형 패키지, 3D/일러스트 자산 제작
- 모든 화면을 한 PR/한 실행에서 일괄 치환
- commit, merge, push, deploy

## 단계별 비준과 실행자 결정

각 wave 시작 전에 Claude Opus 4.8과 Codex가 아래 JSON 수준의 동일 사실에 동의해야 한다.

- 정확한 파일 manifest와 보호 파일 hash
- 채택할 디자인 계약과 비채택 대안
- 동작 불변 조건
- 실행자 1명과 교차 리뷰어 1명
- 검증 명령·캡처 목록
- blocker/high 0건

동의하면 해당 wave 구현은 추가 사용자 중계 없이 시작한다. 불일치, 보호 화면 직접 수정 필요, 기능·데이터·법무 변화 또는 blocker/high가 있으면 멈추고 쟁점만 사용자에게 올린다.

마스터 계획 합의 실행은 `.agent-collab/runs/20260714-UIUX-master-plan-review-3943`에 보존한다. 첫 구현 범위는 `docs/work-orders/2026-07-14-uiux-wave1-pilot.md`의 정확한 manifest를 따른다. 합의 과정에 기록된 잘못된 내비게이션 경로 `pjh/lib/core/navigation/main_navigation.dart`는 Wave 0 코드 대조에서 실제 경로 `pjh/lib/main_navigation.dart`로 정정했다.

## 완료 조건

- [ ] 대상 58개 페이지가 화면 감사표와 정확히 대응한다.
- [ ] v2 코드·문서·라이트/다크 의미 토큰이 일치한다.
- [ ] 페이지별 임의 색·타입·spacing은 승인된 예외만 남고 이유가 기록된다.
- [ ] loading/empty/error/offline/content 상태가 공용 언어를 사용한다.
- [ ] 터치 영역, Semantics, text scale, 대비 기준을 충족한다.
- [ ] 보호 화면 파일은 직접 변경되지 않았고 공용 변경 회귀가 통과한다.
- [ ] 기능·라우팅·상태·법무·DB/API 계약 회귀가 없다.
- [ ] 각 wave의 양쪽 교차 리뷰에서 blocker/high 0건이다.

## 검증 명령

```powershell
# pjh/에서 wave마다 실행
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test <wave 관련 테스트>
git diff --check

# 최종 wave 후
flutter test
```

정적 수치 검색은 완전한 품질 기준이 아니라 회귀 추세 확인에만 사용한다. `Colors.white/transparent/black`, 도메인 의미색, PDF·외부 공유 등 승인 예외를 기계적으로 제거하지 않는다.

## 사람/실기기 검증

- Android 기준 360×800급 작은 화면, 기준 390×844, 큰 화면
- 시스템 글자 100%와 130~150%
- 라이트/다크, 키보드, 권한 거부, 오프라인, 느린 이미지
- 로그인→온보딩→펫 등록, 피드·댓글·채팅, 건강 기록·PDF 핵심 플로우
- 보호 홈·AI 분석 화면의 전후 비교

기기 연결이나 레퍼런스 원본이 없어 검증하지 못한 항목은 완료가 아니라 “사람 검증 대기”로 보고한다.

## 위험과 중단 조건

- 보호 파일 직접 수정이 필요함
- 기준 HEAD 또는 사용자 변경이 예상 밖으로 바뀜
- 인증, DB, 개인정보, 법무, 수의학 문구에 영향
- 기존 route/event/state 계약 변경
- Claude와 Codex의 파일 manifest·실행자·완료 조건 불일치
- 테스트 신규 실패, 렌더 overflow, 접근성 악화

## 완료 보고

- 변경 파일·wave:
- 채택한 디자인 계약:
- 기능 불변 증거:
- 검증 결과와 기존 실패 구분:
- 보호 화면 회귀 결과:
- 미실행 실기기 검증:
- 발견 이슈와 다음 wave:
