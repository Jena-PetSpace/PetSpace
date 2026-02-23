-- RLS Policies for Social Features Extension Tables
-- comment_likes, reports, user_blocks

-- =====================================================
-- COMMENT_LIKES 테이블 RLS
-- =====================================================
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all comment likes"
  ON comment_likes FOR SELECT USING (true);

CREATE POLICY "Users can create comment likes for themselves"
  ON comment_likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comment likes"
  ON comment_likes FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- REPORTS 테이블 RLS
-- =====================================================
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT USING (auth.uid() = reporter_id);

CREATE POLICY "Users can create reports"
  ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- =====================================================
-- USER_BLOCKS 테이블 RLS
-- =====================================================
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own blocks"
  ON user_blocks FOR SELECT USING (auth.uid() = blocker_id);

CREATE POLICY "Users can create blocks for themselves"
  ON user_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can delete their own blocks"
  ON user_blocks FOR DELETE USING (auth.uid() = blocker_id);

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE 'RLS 정책 설정 완료!';
  RAISE NOTICE '  - comment_likes';
  RAISE NOTICE '  - reports';
  RAISE NOTICE '  - user_blocks';
END $$;
