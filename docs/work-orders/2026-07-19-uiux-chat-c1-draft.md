# PetSpace 채팅 C1 공동 기획 합의본

## 상태

- Codex 예비 감사·기획: 완료
- Claude Opus 4.8 검토: `accept`
- 검토 run: `20260719-chat-c1-planning-review-01`
- 검토 manifest SHA-256:
  `d90b45d2106daea7c0790cbe1b74699b1c60a18f2998c6d8c180b3138528091b`
- blocker/high: 0
- Codex 합의 반영: 완료
- 사용자 목업·C1A 정확한 22파일 구현 승인: 대기
- Flutter 구현: 금지
- 운영 DB·Edge·commit·merge·push·deploy: 금지

## 목표

채팅 목록에서 대상을 찾고, 새 대화를 만들고, 메시지를 보내고, 방을
관리하는 흐름을 신뢰 가능한 하나의 경험으로 마감한다. 시각 통일보다
전송 실패 복구, 검색 정확성, 신고·차단 대상, 권한과 알림의 정직성을
먼저 해결한다.

## 핵심 완료 조건

1. 전송 실패 시 작성한 텍스트와 선택한 이미지가 사라지지 않는다.
2. 동일 전송·방 생성·멤버 추가 요청이 중복 제출되지 않는다.
3. 그룹방에서 임의 사용자가 신고·차단 대상이 되지 않는다.
4. 검색 실패와 결과 없음이 구분되고 늦은 응답이 최신 결과를 덮지 않는다.
5. 사용자 화면에 내부 예외가 노출되지 않는다.
6. 관리자만 그룹 이름·사진·멤버를 관리한다.
7. 실제 동작하지 않는 방별 알림을 제공 중인 기능처럼 표시하지 않는다.
8. 목록·대화의 기존 차단·신고·RLS 계약을 보존한다.
9. 320×568, 390×844, 150% 글자 크기에서 overflow가 없고 핵심 행동은
   최소 44dp다.

## 합의가 필요한 제품 결정

### C1-D1 방별 알림

권고안: 서버·기기 알림 경로가 방 설정을 실제로 소비하기 전까지 스위치를
제거하고 `방별 알림은 준비 중` 안내도 기본 화면에는 노출하지 않는다.
기존 `SharedPreferences` 값은 삭제하지 않는다.

### C1-D2 그룹 신고·차단

권고안: 상단 신고·차단은 1:1 방에만 표시한다. 그룹방에서는 상대 메시지
롱프레스의 `메시지 신고`와 참여자 목록의 명시적 사용자 메뉴만 사용한다.
그룹 전체 차단은 제공하지 않는다. 구현 전에 `getChatRoomInfo`의 방 `type`과
참여자 `role`을 확보해 1:1·그룹 및 관리자·일반 참여자 행동을 나눈다.

### C1-D3 목록 확장성

권고안: C1A/B에서는 현재 쿼리 의미를 보존하며 화면 상태를 먼저 닫는다.
C1C에서 `room preview + unread count` batch/cursor RPC를 별도 SQL wave로
설계한다. 운영 DB 적용 전에는 로컬 정본·계약 테스트까지만 진행한다.

## 화면 목업

가시적 초안:
`docs/mockups/2026-07-19-chat-c1-draft.html`

1. 채팅 목록
2. 새 채팅
3. 대화
4. 채팅방 정보

하단 5탭, 홈, AI 분석 화면은 목업과 구현 범위에 포함하지 않는다.

## 구현 순서 초안

### C1A — 정확성·안전

1. Chat BLoC 상태에 전송·생성·추가 로드 outcome과 pending ID를 추가한다.
2. 입력은 성공 뒤에만 비우고 실패하면 재시도 가능한 상태를 유지한다.
3. 다중 이미지 전송을 BLoC mutation으로 통합한다.
4. 검색에 300ms debounce, generation token, error/retry를 추가한다.
5. 그룹/1:1별 신고·차단 행동을 분리한다.
6. Repository 오류를 일반화하고 내부 상세는 logger로 이동한다.
7. 현재 역할을 기반으로 설정 행동을 제한한다.
8. 무효한 방별 알림 UI와 목록 음소거 아이콘을 제거하되 저장된 값은
   보존한다.
9. 실시간 새 메시지는 현재 참여자 캐시로 발신자 이름·사진을 보강한다.
10. 새 메시지마다 실행되는 읽음 처리와 참여자 재조회를 합쳐 호출 폭증을
    막는다.

### C1B — 4화면 UI/UX

1. 목록 검색·상태·명시적 더보기
2. 선택 사용자 요약과 생성 pending
3. 대화 로딩·과거 메시지 실패·전송 실패 복구
4. 참여자·역할 중심 방 정보와 위험 행동 분리
5. 접근성, SafeArea, 키보드, 작은 화면 검증

### C1C — 확장성·운영 게이트

1. 목록 batch/cursor 정본 계약
2. 방별 알림을 실제 제공할 경우 서버 preference·push gate 설계
3. 두 계정 1:1/그룹/차단/신고/읽음 E2E
4. 운영 SQL·Edge는 별도 사람 승인

## Claude 읽기 전용 검토 manifest — 정확한 47파일

### 기획·증거 3

1. `docs/reviews/2026-07-19-chat-c1-preliminary-audit.md`
2. `docs/work-orders/2026-07-19-uiux-chat-c1-draft.md`
3. `docs/mockups/2026-07-19-chat-c1-draft.html`

### Chat 제품·테스트 39

4. `pjh/lib/features/chat/data/datasources/chat_remote_data_source.dart`
5. `pjh/lib/features/chat/data/models/chat_message_model.dart`
6. `pjh/lib/features/chat/data/models/chat_participant_model.dart`
7. `pjh/lib/features/chat/data/models/chat_room_model.dart`
8. `pjh/lib/features/chat/data/repositories/chat_repository_impl.dart`
9. `pjh/lib/features/chat/domain/entities/chat_message.dart`
10. `pjh/lib/features/chat/domain/entities/chat_participant.dart`
11. `pjh/lib/features/chat/domain/entities/chat_room.dart`
12. `pjh/lib/features/chat/domain/repositories/chat_repository.dart`
13. `pjh/lib/features/chat/domain/usecases/add_chat_members.dart`
14. `pjh/lib/features/chat/domain/usecases/create_chat_room.dart`
15. `pjh/lib/features/chat/domain/usecases/get_chat_messages.dart`
16. `pjh/lib/features/chat/domain/usecases/get_chat_rooms.dart`
17. `pjh/lib/features/chat/domain/usecases/get_unread_count.dart`
18. `pjh/lib/features/chat/domain/usecases/leave_chat_room.dart`
19. `pjh/lib/features/chat/domain/usecases/report_chat_target.dart`
20. `pjh/lib/features/chat/domain/usecases/search_users_for_chat.dart`
21. `pjh/lib/features/chat/domain/usecases/send_image_message.dart`
22. `pjh/lib/features/chat/domain/usecases/send_message.dart`
23. `pjh/lib/features/chat/domain/usecases/update_last_read.dart`
24. `pjh/lib/features/chat/presentation/bloc/chat_badge/chat_badge_bloc.dart`
25. `pjh/lib/features/chat/presentation/bloc/chat_badge/chat_badge_event.dart`
26. `pjh/lib/features/chat/presentation/bloc/chat_badge/chat_badge_state.dart`
27. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart`
28. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_event.dart`
29. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_state.dart`
30. `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart`
31. `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_event.dart`
32. `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_state.dart`
33. `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
34. `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
35. `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart`
36. `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
37. `pjh/lib/features/chat/presentation/widgets/chat_bubble.dart`
38. `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart`
39. `pjh/lib/features/chat/presentation/widgets/chat_report_sheet.dart`
40. `pjh/lib/features/chat/presentation/widgets/chat_room_tile.dart`
41. `pjh/test/features/chat/data/repositories/chat_block_filter_test.dart`
42. `pjh/test/features/chat/domain/usecases/report_chat_target_test.dart`

### 경계·계약 5

43. `pjh/lib/config/injection_container.dart`
44. `pjh/lib/core/navigation/app_router.dart`
45. `pjh/lib/core/services/block_service.dart`
46. `supabase/petspace_setup.sql`
47. `supabase/migrations/chat_report.sql`

실제 외부 검토 전 오케스트레이터가 위 47파일의 SHA-256 manifest를 만들고,
파일 변경이 있으면 전송하지 않고 멈춘다. `.env`, `secrets.dart`, 키·토큰,
운영 데이터는 포함하지 않는다.

## Claude 검토 질문

1. C1-H1~H8의 사실과 등급이 코드에 부합하는가?
2. C1-D1~D3 권고안이 기존 P2A/P2B/K1 계약을 보존하는가?
3. 4화면 목업의 정보 구조와 접근성 계약이 충분한가?
4. C1A→C1B→C1C 순서가 안전한가?
5. review manifest 47파일에 빠진 필수 증거나 불필요한 파일이 있는가?
6. 구현 manifest를 C1A와 C1B로 분리할 때 정확한 파일 경계는 무엇인가?

## Claude·Codex 합의 결과

- Claude Opus 4.8: `accept`
- Codex: `accept`
- blocker/high: 0
- 감사 C1-H1~H8, C1-M1~M8: 모두 실제 코드와 일치
- C1-D1·D3: 원안 수용
- C1-D2: 방 `type`과 참여자 `role`을 먼저 확보하는 조건으로 수용
- C1A → C1B → C1C 순서: 수용
- DB/RPC·Edge·운영 적용: C1C 별도 사람 승인 유지

Claude 후보 범위는 다중 이미지 전송을 BLoC로 통합하면서도
`SendMultiImageMessage`와 DI를 가급적 제외했다. 현재 구조에서 Presentation의
Repository 직접 호출을 제거하려면 UseCase 등록이 필요하므로 Codex는 신규
UseCase 1파일과 `injection_container.dart`를 최소 범위로 포함했다. 라우터
변경은 하지 않고 기존 `getChatRoomInfo` 결과에 `type`을 포함하는 방식으로
방 종류를 확보한다.

## C1A 정확한 구현 manifest — 22파일

### 수정 14

1. `pjh/lib/config/injection_container.dart`
2. `pjh/lib/features/chat/data/datasources/chat_remote_data_source.dart`
3. `pjh/lib/features/chat/data/repositories/chat_repository_impl.dart`
4. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart`
5. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_event.dart`
6. `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_state.dart`
7. `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart`
8. `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_state.dart`
9. `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
10. `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
11. `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
12. `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart`
13. `pjh/lib/features/chat/presentation/widgets/chat_room_tile.dart`
14. `pjh/lib/features/chat/domain/usecases/send_multi_image_message.dart`

14번은 신규 파일이다.

### 신규 테스트 8

15. `pjh/test/features/chat/data/repositories/chat_repository_impl_test.dart`
16. `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart`
17. `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart`
18. `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart`
19. `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart`
20. `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart`
21. `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart`
22. `pjh/test/features/chat/presentation/widgets/chat_room_tile_test.dart`

### C1A 변경 금지

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/core/services/block_service.dart`
- `pjh/lib/features/chat/domain/repositories/chat_repository.dart`
- `supabase/petspace_setup.sql`
- `supabase/migrations/chat_report.sql`
- 하단 5탭, 홈, AI 분석
- 운영 DB·Edge·배포

## C1A 구현 완료 조건

1. 정확한 22파일 밖의 변경이 없다.
2. 전송 실패 시 텍스트·선택 이미지가 유지되고 재시도할 수 있다.
3. 텍스트·단일 이미지·다중 이미지가 하나의 BLoC pending/outcome 계약을
   사용한다.
4. 방 생성 중 재제출이 차단되고 새로고침 실패가 기존 목록을 지우지 않는다.
5. 검색은 300ms debounce, 최신 요청 보호, loading·empty·error·retry를
   구분한다.
6. 1:1에서만 상단 사용자 신고·차단을 제공하고 그룹방에서는 명시적
   메시지·참여자 대상을 사용한다.
7. 관리자만 그룹 이름·사진·초대를 관리한다.
8. 내부 예외 문자열이 UI Failure에 포함되지 않는다.
9. 방별 알림 스위치·음소거 아이콘이 사라지고 저장된 로컬 값은 보존된다.
10. 관련 테스트, 전체 `flutter analyze --no-pub`, 전체 `flutter test`,
    `git diff --check`, 범위·보호 경로 검증을 통과한다.
11. 구현 변경 번들을 Claude Opus 4.8이 독립 리뷰하고 blocker/high 0이다.

## C1A 구현 전 게이트

1. 완료: 사용자가 47파일의 Claude Opus 4.8 읽기 전용 검토를 승인했다.
2. 완료: Claude와 Codex가 기획에 합의하고 blocker/high 0을 확인했다.
3. 대기: 사용자가 최종 목업과 정확한 C1A 22파일 구현을 승인한다.
4. 구현 후 변경된 정확한 번들의 Claude Opus 4.8 외부 검토는 별도 명시
   승인 뒤 실행한다.
5. 3번 전에는 Chat Flutter 소스를 수정하지 않는다.
