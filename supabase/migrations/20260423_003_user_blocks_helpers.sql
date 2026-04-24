-- ============================================================================
-- user_blocks 헬퍼 함수 + 인덱스
-- ============================================================================
-- 피드/검색/댓글 등에서 차단된 사용자를 제외하기 위한 헬퍼.

-- 인덱스: 차단자 기준 조회 (피드 필터)
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker
    ON user_blocks(blocker_id);

-- 인덱스: 피차단자 기준 조회 (역조회)
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked
    ON user_blocks(blocked_id);

-- RLS
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_blocks_select_own ON user_blocks;
CREATE POLICY user_blocks_select_own ON user_blocks
    FOR SELECT USING (blocker_id = auth.uid());

DROP POLICY IF EXISTS user_blocks_insert_own ON user_blocks;
CREATE POLICY user_blocks_insert_own ON user_blocks
    FOR INSERT WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS user_blocks_delete_own ON user_blocks;
CREATE POLICY user_blocks_delete_own ON user_blocks
    FOR DELETE USING (blocker_id = auth.uid());

-- ── RPC: 차단한 사용자 ID 배열 ─────────────────────────────────────────────
-- 클라이언트가 피드 쿼리 시 사용: .not('author_id', 'in', result)
CREATE OR REPLACE FUNCTION get_blocked_user_ids(p_user_id UUID)
RETURNS TABLE(blocked_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT ub.blocked_id
    FROM user_blocks ub
    WHERE ub.blocker_id = p_user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ── RPC: 상호 차단 확인 (A가 B 차단했거나 B가 A 차단한 경우 TRUE) ─────────
-- 프로필 페이지 접근 시 차단 안내 용도
CREATE OR REPLACE FUNCTION is_mutually_blocked(p_user_a UUID, p_user_b UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_blocks
        WHERE (blocker_id = p_user_a AND blocked_id = p_user_b)
           OR (blocker_id = p_user_b AND blocked_id = p_user_a)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
