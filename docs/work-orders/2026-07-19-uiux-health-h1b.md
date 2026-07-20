# PetSpace 건강관리 H1B 작업지시서

## 상태

- H1 기획: Codex·Claude Fable 5 공동 승인
- H1A 데이터·상태 정확성: 동일 16파일 해시 공동 승인
- 실행자: Codex
- Claude 정책: 구현을 막지 않으며 동일 변경 번들을 사후 독립 리뷰
- 운영 DB·Edge·commit·merge·push·deploy: 미실행

## 목표

건강관리 탭 안에서 정보 우선순위와 상호작용을 신뢰 가능한 제품 화면으로 정돈한다.
하단 5탭, 홈, AI 분석 화면은 수정하지 않는다.

1. 선택 반려동물과 다가오는 일정, 기록 목록, 보조 추이 순서로 읽히게 한다.
2. 전체·백신·검진·체중·투약·수술 6개 필터를 모두 제공한다.
3. 유형별 강한 다색 선택 표현을 없애고 브랜드 action 색 하나로 통일한다.
4. 필터, 앱바 action, 기록 카드, CTA의 터치 영역을 최소 44dp로 보장한다.
5. 기록 카드는 button/편집 의미와 선택 피드백을 제공하고 swipe 외 편집 경로를 유지한다.
6. 반려동물 없음, 기록 없음, 필터 결과 없음, 불러오기 실패를 서로 다른 문구와 행동으로 표시한다.
7. 건강 알림과 PDF를 한 `건강 도구` 진입점으로 묶되 기존 기능 의미를 바꾸지 않는다.
8. 감정 추이는 기록보다 뒤의 보조 정보로 유지하고 emotion presentation은 수정하지 않는다.

## 화면 계약

### 건강관리 메인

- 앱바: `건강관리`, `{petName}의 건강 기록`, `건강 도구`.
- 다가오는 일정: 가장 가까운 일정부터 최대 3개, due-date 기반 D-day.
- 기록: 선택 필터 라벨과 해당 결과 건수.
- 필터: 가로 스크롤 6개, 단일 브랜드 선택색, selected semantics.
- 기록 카드: 유형 아이콘·기록 요약·날짜·상태·편집 affordance.
- 보조 영역: 감정 분석 추이는 기록 영역 다음.

### 상태

- 반려동물 없음: 반려동물 등록 CTA.
- 기록 없음: 첫 기록 추가 CTA.
- 필터 결과 없음: 다른 필터 선택 안내.
- 불러오기 실패: 안전한 일반화 문구와 다시 시도 CTA.

### 건강 도구

- 건강 알림 설정: 기존 `/health/alert-settings`로 이동.
- 건강 리포트: 기존 선택 pet PDF 미리보기 흐름 실행.
- 자동 알림 미제공 상태나 PDF 의미는 H1C 전까지 변경하지 않는다.

## 정확한 구현 manifest

### 앱 소스 3개

1. `pjh/lib/features/health/presentation/pages/health_main_page.dart`
2. `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
3. `pjh/lib/features/health/presentation/widgets/health_record_card.dart`

### 테스트 2개

4. `pjh/test/contracts/h1b_health_ui_contract_test.dart`
5. `pjh/test/features/health/presentation/health_record_card_test.dart`

문서와 목업은 검토 증거이며 구현 manifest에 포함하지 않는다.

## 보존·금지

- 기록 유형·validation·data composition·dueDate·BLoC mutation 계약 보존
- 홈, AI 분석, 하단 5탭 UI 보호
- `features/emotion/presentation/**` 수정 금지
- 신규 진단·치료·확률·법무 문구 금지
- 신규 하드코딩 원빨강 금지
- 운영 DB migration·Edge 배포 금지

## 검증

- H1B widget·source contract tests
- 건강관리 전체 테스트
- 작은 화면 320×568, 글자 150%에서 overflow 없음
- 필터·카드·앱바 action 44dp
- `flutter analyze --no-pub`
- 전체 `flutter test`
- `git diff --check`
- 정확한 5파일 manifest와 보호 hash 확인
- Codex 리뷰 후 동일 해시 Claude Fable 5 리뷰

## 실기기 이관

- 6개 필터의 스크롤·선택·건수 일치
- 기록 카드 탭 편집, swipe 삭제
- 건강 도구에서 알림 설정·PDF 진입
- pet 없음·기록 없음·오류·재시도
- 작은 기기·큰 글씨·키보드

