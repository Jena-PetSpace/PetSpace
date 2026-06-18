# 계정 soft delete E2E 검증 시나리오

## 사전 조건
- [ ] G1_account_soft_delete.sql 대시보드 실행 완료
- [ ] request-account-deletion / purge-deleted-accounts Edge Function 배포 완료
- [ ] PURGE_SHARED_SECRET 설정, pg_cron 등록

## 시나리오 1: 탈퇴 → 재로그인 복구
1. 계정 A로 로그인 → 설정 → 회원탈퇴 → "탈퇴" 입력 → 탈퇴
   - 기대: 로그아웃되어 로그인 화면 이동
   - SQL 확인: SELECT deleted_at FROM users WHERE email='<A>'; → NOT NULL
2. 같은 계정으로 재로그인
   - 기대: "계정 복구" 다이얼로그 (잔여 30일 표시)
3. [복구하기]
   - 기대: 홈 진입, SQL 확인 deleted_at IS NULL

## 시나리오 2: 탈퇴 → 타인 시점 콘텐츠 비노출
1. 계정 A가 게시물·댓글 작성 후 탈퇴
2. 계정 B로 로그인 → 피드/검색/게시물 상세 확인
   - 기대: A의 프로필·게시물·댓글 미노출
   - 기대: A와의 기존 채팅방 메시지는 유지 (작성자명 누락 시 표시 확인 — 이슈 시 보고)

## 시나리오 3: 탈퇴 직후 세션 무효화
1. 기기 2대에 계정 A 로그인 → 기기1에서 탈퇴
   - 기대: 기기2도 다음 API 호출/재시작 시 로그인 화면으로 이동

## 시나리오 4: 30일 경과 영구 삭제 (스테이징)
1. SQL로 deleted_at을 31일 전으로 조작:
   UPDATE users SET deleted_at = NOW() - INTERVAL '31 days' WHERE email='<테스트계정>';
2. purge 함수 수동 호출:
   curl -X POST https://<REF>.supabase.co/functions/v1/purge-deleted-accounts -H "x-purge-secret: <SECRET>"
   - 기대: auth.users·public.users·연관 데이터·Storage 폴더 삭제
   - 기대: 탈퇴자의 chat_messages도 FK CASCADE로 함께 영구 삭제됨
     — **의도된 동작** (30일 유예 기간에만 대화 유지, purge 후에는 미보존)
