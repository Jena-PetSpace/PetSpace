-- ================================================================
-- PetSpace P0 수정 SQL
-- Supabase SQL Editor에서 실행해주세요
-- 날짜: 2026-03-18
-- ================================================================

-- ================================================================
-- 1. RLS 수정 — user_blocks DELETE 정책 추가
-- ================================================================
CREATE POLICY "Users can delete their own blocks" ON user_blocks
    FOR DELETE USING (auth.uid() = blocker_id);

-- ================================================================
-- 2. 성능 인덱스 추가
-- ================================================================

-- notifications: 알림 목록 조회 최적화
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at
    ON notifications(user_id, created_at DESC);

-- emotion_history: 감정 히스토리 조회 최적화
CREATE INDEX IF NOT EXISTS idx_emotion_history_user_created_at
    ON emotion_history(user_id, created_at DESC);

-- comments: 댓글 정렬 최적화
CREATE INDEX IF NOT EXISTS idx_comments_created_at
    ON comments(created_at DESC);
