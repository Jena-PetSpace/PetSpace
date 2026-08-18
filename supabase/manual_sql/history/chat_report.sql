-- ============================================================
-- 채팅 신고(Chat Report) 패치 — reports 테이블 메시지 신고 확장
-- ------------------------------------------------------------
-- 작성일: 2026-06-14
-- 목적:
--   1:1/그룹 채팅의 개별 메시지 신고를 받기 위해 reports 테이블에
--   reported_message_id 컬럼을 추가한다. (채팅 사용자 신고는 기존
--   reported_user_id 재사용으로 컬럼 추가 불필요.)
--   App Store Guideline 1.2 / Google Play UGC 정책 컴플라이언스(채팅 출시 전제).
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행하거나
--   `supabase db push` 로 마이그레이션 반영. (멱등 — 재실행 안전)
--
-- 검증:
--   1) reports.reported_message_id 컬럼 존재 + chat_messages(id) FK 확인
--   2) 메시지 신고 insert(reported_message_id 만 채움) 성공
--   3) 기존 social 신고(post/comment/user) insert 여전히 성공(회귀 없음)
--   4) 본인(auth.uid()=reporter_id) 외 insert 차단(기존 RLS 정책 유지)
-- ============================================================

-- 1) 메시지 신고 컬럼 추가 (nullable, 메시지 삭제 시 신고도 정리)
ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS reported_message_id UUID
    REFERENCES chat_messages(id) ON DELETE CASCADE;

-- 2) "신고 대상 중 하나는 반드시 존재" CHECK 를 메시지까지 포함하도록 확장.
--    OR 항목을 추가(widen)하는 변경이라 기존 행(post/comment/user)은 그대로 유효 → 회귀 없음.
--    원본 petspace_setup.sql 은 이름 없는 인라인 CHECK 라 Postgres 가 'reports_check' 로 자동 명명한다.
--    신규 설치본은 'reports_target_check'. 둘 다 제거 후 새 제약을 단다.
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_check;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_target_check;
ALTER TABLE reports
    ADD CONSTRAINT reports_target_check CHECK (
        reported_user_id IS NOT NULL OR
        reported_post_id IS NOT NULL OR
        reported_comment_id IS NOT NULL OR
        reported_message_id IS NOT NULL
    );

-- 3) 조회 성능: 메시지 신고 인덱스
CREATE INDEX IF NOT EXISTS idx_reports_reported_message_id
    ON reports(reported_message_id);

-- 4) RLS: 본인만 신고 insert (기존 정책 재확인 — table-level이라 신규 컬럼도 자동 적용).
--    중복 신고는 social과 동일하게 허용한다(UNIQUE 제약 두지 않음).
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports" ON reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);
