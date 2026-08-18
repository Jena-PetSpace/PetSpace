# 채팅 신고·차단 검증 가이드

채팅(1:1) UGC 안전장치(신고·차단)의 검증 절차. App Store Guideline 1.2 / Google Play UGC
정책 대응. 실기기 검증 묶음 항목.

- 대상 커밋: `chatsafety-STEP1`(c13c5f5) · `STEP2`(403fbeb) · `STEP3`(1c2e19f)
- 선행 조건: **`supabase/manual_sql/history/chat_report.sql` 운영 반영 확인 완료**(메시지 신고 컬럼).
  미실행 시 메시지 신고는 컬럼 부재로 실패. 사용자 신고·차단은 기존 테이블로 동작.

---

## ⚠️ Apple 1.2 핵심 — "차단 시 콘텐츠 즉시 비노출"
차단하면 그 사용자의 메시지가 **즉시**(앱 재시작 없이) 사라져야 한다. 초기 로드뿐 아니라
**실시간으로 들어오는 새 메시지도** 차단 직후부터 보이지 않아야 한다. (스냅샷 캐시가 아니라
emission마다 갱신된 차단 목록을 반영하도록 구현 — repository `subscribeToRoomMessages`.)

---

## 1. 사용자 신고 → reports 적재
1. 1:1 채팅방 진입 → AppBar 우측 ⋮ → "신고하기".
2. 사유 선택(스팸/광고·폭력위험·허위정보·혐오차별·개인정보침해·기타) → "신고".
3. "신고가 접수되었습니다" 스낵바 확인.
4. DB 확인:
   ```sql
   SELECT reporter_id, reported_user_id, reason, status, created_at
   FROM reports WHERE reported_user_id = '<상대 user_id>' ORDER BY created_at DESC LIMIT 1;
   ```
   **합격:** `reported_user_id` 채워짐, `status='pending'`.

## 2. 메시지 신고 → reports 적재 (migration 실행 후)
1. 상대 메시지 **롱프레스** → "메시지 신고" → 사유 선택 → 접수 안내.
2. DB 확인:
   ```sql
   SELECT reporter_id, reported_message_id, reason FROM reports
   WHERE reported_message_id = '<메시지 id>' ORDER BY created_at DESC LIMIT 1;
   ```
   **합격:** `reported_message_id` 채워짐. (내 메시지는 롱프레스 메뉴 없음 — 정상)

## 3. 차단 → 상대 메시지 즉시 비표시
1. ⋮ → "차단하기" → 확인 다이얼로그("OOO님을 차단하시겠어요?…") → "차단".
2. **즉시(앱 재시작 없이)** 차단 상대의 기존 메시지가 화면에서 사라지고 목록으로 복귀.
   - 내부: `blockUser` → `getBlockedUserIds(forceRefresh:true)` → `ChatDetailBlockApplied` 재로드.
3. **실시간 검증(핵심):** 차단한 상대가 새 메시지를 보내도 **내 화면에 나타나지 않아야** 함.
   (다른 기기/계정으로 상대가 차단 후 메시지 전송 → 내 채팅방에 미표시 확인.)
   **합격:** 기존·신규 메시지 모두 비표시. "차단했는데 새 메시지가 옴"이면 불합격.

## 4. 차단 상대 방 목록 숨김
1. 차단 후 채팅방 목록(`/chat`)으로 이동.
2. **합격:** 차단 상대와의 1:1 방이 목록에서 사라짐. (그룹 방은 유지)

## 5. 차단 해제 → 복원
1. 내 정보 → 설정 → 차단 목록(`privacy_settings_page`)에서 차단 사용자 확인
   (채팅 차단도 `user_blocks` 동일 테이블 → 기존 차단 목록에 함께 표시됨).
2. "차단 해제" → 해제.
3. **합격:** 다음 채팅 로드 시 해당 사용자 메시지·방이 다시 표시됨(복원).

---

## 회귀 확인
- [ ] social 신고/차단 기존 동작 무변경(social 파일 미수정 — 채팅용 사유 시트는 별도 복제).
- [ ] 그룹 채팅: 차단/신고 메뉴 동작 시 1:1 상대가 없으면 "상대를 찾을 수 없습니다" 안내(크래시 없음).
- [ ] `flutter analyze` 0 / `flutter test` 262 pass·14 baseline.

## 자동화 테스트 커버리지(이미 통과)
- `test/.../report_chat_target_test.dart` — 사용자/메시지 신고·실패·중복 신고(5).
- `test/.../chat_block_filter_test.dart` — 초기/실시간 필터·**동적 반영**·방 숨김(5).

## 후속 TODO
- 신고 운영자 검토 화면(어드민)은 앱 범위 밖.
- gemini-proxy처럼 채팅 신고 rate limit은 미적용(필요 시 v2).
