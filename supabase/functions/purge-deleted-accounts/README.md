# purge-deleted-accounts 운영 준비

30일 유예가 지난 탈퇴 계정의 Storage, 잔존 콘텐츠 스냅샷,
`auth.users`, `public.users`와 연관 데이터를 영구 삭제한다. 실패한
계정은 다음 실행에서 재시도하며 응답에는 사용자 ID나 원문 오류를
포함하지 않는다.

## 로컬 계약

- Storage 폴더를 100개 단위로 페이지네이션하고 삭제한다.
- `notifications.sender_id`가 `ON DELETE SET NULL`로 바뀌기 전에 해당
  발신 알림 행을 삭제해 `title`, `body`, `data`가 남지 않게 한다.
- `chat_rooms.last_message_sender_id`가 사라지기 전에 마지막 메시지,
  시각, 발신자 스냅샷을 함께 비운다.
- `auth.users`가 앞선 부분 실행에서 이미 삭제됐어도 재실행할 수 있다.
- `auth.users` 직접 참조 테이블은 `ON DELETE CASCADE`여야 한다.
- `public.users` 하위 테이블은 기존 FK cascade 계약을 사용한다.
- 위치정보법상 확인자료인 `location_access_log`는 앱 내 위치기반서비스
  약관에 고지된 6개월 동안 분리 보관하는 법정 보존 예외다. 배치가 실행될
  때마다 UTC 달력 기준 6개월이 지난 행을 먼저 삭제하며 실패하면 계정
  purge를 진행하지 않는다.
- 하나라도 실패하면 HTTP 503과 비식별 오류 코드별 개수만 반환한다.

## 운영 적용 전 확인

1. `supabase/manual_sql/history/L1_account_purge_contract.sql`과
   `supabase/manual_sql/history/L2_account_deletion_access_guard.sql`의 변경 대상을 read-only로
   확인한다.
2. `PURGE_SHARED_SECRET`, `SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`의 존재만 확인하고 값을 출력하지 않는다.
3. Edge 함수를 배포한다.
4. pg_cron·pg_net을 활성화하고 매일 03:00 KST 호출을 등록한다. 이 단일
   배치가 30일 계정 purge와 6개월 위치 확인자료 만료 삭제를 함께 수행한다.
5. 30일 경과 전용 테스트 계정으로 Storage와 사용자 연관 테이블의 잔여
   행이 0인지, 발신 알림과 채팅방 미리보기가 남지 않는지 확인한다.
6. 일부 Storage 삭제 실패를 주입해 다음 실행에서 멱등 재시도되는지
   확인한다.
7. 6개월 경계 전·후의 좌표 없는 위치 확인자료를 만들어 만료 전 행은
   유지되고 만료 후 행만 삭제되는지 확인한다.
8. 배치의 비-2xx 응답과 `LOCATION_AUDIT_EXPIRY_FAILED`를 운영 알림에
   연결한다. 감사 로그 만료 삭제가 반복 실패하면 fail-closed로 계정
   purge도 멈추므로 성공률과 마지막 성공 시각을 함께 감시한다.

운영 secret 등록, migration 실행, Edge 배포, cron 등록은 사용자 운영
승인 후에만 수행한다.
