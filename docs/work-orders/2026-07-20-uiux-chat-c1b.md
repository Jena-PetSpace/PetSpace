# PetSpace Chat C1B UI/UX 작업지시서

## 1. 상태와 권한

- C1A 정확한 22파일 구현: 완료
- C1A 전체 검증: `flutter analyze --no-pub` 통과, 전체 테스트 671개 통과
- C1A 최종 Claude Opus 4.8 리뷰:
  - decision: `accept`
  - blocker/high: 0
  - manifest SHA-256:
    `578a603e65d2ca2f55ad68377992d7d8cf37f9c6eb3175a840fadaa285982a28`
- C1B 4화면 목업 사용자 승인: 2026-07-20
- 목업 정본:
  `docs/mockups/2026-07-19-chat-c1-draft.html`
- C1B 구현 방향: Codex 구현, Claude Opus 4.8 독립 리뷰
- 금지:
  - 하단 5탭 UI
  - 홈 화면
  - AI 분석 화면
  - 라우팅 계약
  - repository 인터페이스
  - 운영 DB, migration, Edge, 배포
  - commit, merge, push

## 2. 목표

C1A에서 확보한 전송·검색·권한·오류 복구 계약을 유지하면서 채팅 목록, 새 채팅,
대화, 채팅방 정보의 시각 체계와 상호작용을 PetSpace 공용 UI 체계로 통일한다.
기능 의미나 데이터 계약을 바꾸지 않고 사용자가 현재 상태, 다음 행동, 위험 행동을
한눈에 이해하도록 한다.

## 3. 합의된 제품 결정

### C1B-D1 채팅 목록 검색

- 서버 검색이나 신규 RPC를 만들지 않는다.
- 이미 로드된 채팅방의 표시 이름과 마지막 메시지를 로컬에서 필터링한다.
- 검색어가 없으면 전체 목록, 결과가 없으면 검색 전용 빈 상태를 보여준다.
- 초기 조회 실패와 검색 결과 없음은 같은 상태로 표현하지 않는다.

### C1B-D2 명시적 방 메뉴

- 길게 누르기는 보조 진입으로 유지할 수 있지만 유일한 진입점으로 사용하지 않는다.
- 각 채팅방 타일에 최소 44dp의 명시적 더보기 버튼을 제공한다.
- 설정과 나가기는 기존 확인·실패 계약을 그대로 사용한다.

### C1B-D3 전송 실패 복구

- C1A의 `ChatSendOutcome`을 정본으로 사용한다.
- 전송 실패는 입력창 위 인라인 복구 카드로 표시한다.
- 원문 또는 이미지 개수의 안전한 요약과 `다시 보내기`를 제공한다.
- Snackbar는 중복 노출하지 않는다.
- 재시도 중에는 입력과 이미지 중복 제출을 막고, 성공하면 복구 카드를 제거한다.

### C1B-D4 과거 메시지 로딩 실패

- 전체 대화 조회 실패와 과거 메시지 추가 조회 실패를 구분한다.
- 기존 메시지를 유지한 채 목록 끝에 인라인 재시도 컨트롤을 제공한다.
- 재시도는 기존 `ChatDetailLoadMoreRequested`를 사용한다.

### C1B-D5 채팅방 정보

- 그룹 정체성, 참여자, 관리 행동, 나가기를 시각적으로 분리한다.
- 서버 `participant.role`이 `admin`인 사용자에게만 이름·사진·초대·저장을 노출한다.
- 이름이나 사진이 실제로 바뀐 경우에만 저장 버튼을 활성화한다.
- 변경되지 않은 방 이름을 다시 저장하지 않는다.
- 신고·차단은 대상 참여자의 명시적 메뉴에만 둔다.

### C1B-D6 접근성·반응형

- 주요 버튼과 메뉴는 최소 44dp 터치 영역을 가진다.
- 320×568, 390×844, 150% 글자 크기에서 overflow가 없어야 한다.
- 하드코딩된 임의 빨강을 추가하지 않고 `AppTheme`와 `ColorScheme`을 사용한다.
- 다크 모드는 이번 wave의 별도 구현 목표가 아니지만 Theme 기반 대비를 훼손하지 않는다.

## 4. 화면별 구현

### 4.1 채팅 목록

- PetSpace 배경·surface·제목·간격 체계 적용
- 상단 검색 필드
- 명시적 방 더보기
- 새로고침 중 기존 목록 유지
- 새로고침 실패 인라인 안내와 재시도
- 초기 loading, initial error, empty, search empty 분리
- unread badge와 시간·미리보기 계층 정돈

### 4.2 새 채팅

- 선택 사용자 chip과 선택 인원 요약
- 검색 loading, error/retry, empty 분리
- 2명 이상 선택 시 그룹명 입력 노출
- 생성 버튼을 하단의 명시적 primary action으로 배치
- 생성 pending 중 선택·검색·버튼 중복 조작 차단
- 기존 300ms debounce와 generation guard 유지

### 4.3 대화

- 날짜 구분, 상대/내 메시지, 시스템 메시지 계층 정돈
- 입력창 SafeArea와 44dp 컨트롤 보장
- 전송 실패 인라인 복구 카드
- 과거 메시지 loading/error/retry를 기존 메시지와 함께 표시
- 그룹방 상단 임의 사용자 신고·차단 금지 유지
- 직접방 사용자 신고·차단, 메시지별 신고 계약 유지

### 4.4 채팅방 정보

- 그룹 정보 요약 카드
- 참여자 수와 역할 badge
- 관리자 전용 편집·초대
- 일반 참여자 신고·차단 메뉴
- 나가기 danger section 분리
- 실제 변경이 없으면 저장 버튼 비활성

## 5. 정확한 구현 manifest — 14파일

### 수정 12파일

1. `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart`
2. `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
3. `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
4. `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
5. `pjh/lib/features/chat/presentation/widgets/chat_bubble.dart`
6. `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart`
7. `pjh/lib/features/chat/presentation/widgets/chat_room_tile.dart`
8. `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart`
9. `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart`
10. `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart`
11. `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart`
12. `pjh/test/features/chat/presentation/widgets/chat_room_tile_test.dart`

### 신규 2파일

13. `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart`
14. `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart`

## 6. 구현 금지 경로

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/main_navigation.dart`
- `pjh/lib/features/chat/data/**`
- `pjh/lib/features/chat/domain/**`
- `pjh/lib/features/chat/presentation/bloc/**`
- `pjh/lib/core/services/block_service.dart`
- `pjh/lib/features/home/**`
- `pjh/lib/features/emotion/presentation/**`
- `supabase/**`

## 7. 테스트 요구사항

1. `chat_rooms_page_test.dart`
   - 검색 필터와 검색 결과 없음
   - 명시적 더보기 44dp
   - 기존 목록을 유지한 refresh error와 retry
2. `create_chat_page_test.dart`
   - 문자열 검사만으로 끝내지 않고 가능한 범위의 widget 행동 테스트 추가
   - 선택 요약과 생성 pending 중 중복 조작 차단
   - 320×568, 150% overflow 없음
3. `chat_detail_page_test.dart`
   - 전송 실패 인라인 카드와 재시도
   - 과거 메시지 실패 시 기존 목록 보존과 재시도
   - 직접방/그룹방 위험 행동 분리 유지
4. `chat_room_settings_page_test.dart`
   - 관리자·일반 참여자 행동 가시성
   - 변경 없음 저장 비활성
   - 나가기 위험 영역
5. `chat_bubble_test.dart`
   - 내 메시지·상대 메시지·시스템 메시지·다중 이미지
   - 150% 글자 크기 overflow 없음
6. 입력창·타일 테스트
   - 44dp, SafeArea, Theme 기반 색상
   - C1A 전송 중 중복 방지와 가짜 알림 아이콘 제거 회귀 없음

## 8. 검증

- `dart format` — 정확한 14파일
- `flutter analyze --no-pub`
- `flutter test test/features/chat`
- `flutter test`
- `git diff --check`
- 정확한 14파일 외 신규 변경 없음
- 금지·보호 경로 hash 불변
- Codex 독립 리뷰
- 변경된 동일 14파일 Claude Opus 4.8 독립 리뷰
- 양쪽 blocker/high 0

## 9. 후속 C1C

다음은 C1B에서 구현하지 않는다.

- 채팅 목록 N+1 제거용 batch/cursor RPC
- 다중 이미지 부분 업로드 orphan 정리 정책
- 실제 방별 알림 preference와 push gate
- 운영 DB·Edge·배포
