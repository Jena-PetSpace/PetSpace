-- ================================================================
-- PetSpace P2 Fixes: Soft Delete + Storage RLS Notes
-- 날짜: 2026-03-18
-- ================================================================
--
-- 이 파일을 Supabase SQL Editor에서 실행하세요.
-- 기존 데이터에 영향 없이 soft delete 기능을 추가합니다.
--
-- ================================================================


-- ================================================================
-- TASK 1: Soft Delete for posts and comments
-- ================================================================

-- 1-1. posts 테이블에 deleted_at 컬럼 추가
ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 1-2. comments 테이블에 deleted_at 컬럼 추가
ALTER TABLE comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 1-3. soft delete 조회 성능을 위한 partial index
CREATE INDEX IF NOT EXISTS idx_posts_deleted_at ON posts(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_comments_deleted_at ON comments(deleted_at) WHERE deleted_at IS NULL;


-- ================================================================
-- 1-4. Posts RLS 정책 업데이트 (soft delete 반영)
-- ================================================================

-- SELECT: 삭제되지 않은 게시물만 조회 가능
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (deleted_at IS NULL);

-- INSERT: 변경 없음 (본인 게시물만 작성)
DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
CREATE POLICY "Users can insert own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

-- UPDATE: 삭제되지 않은 본인 게시물만 수정 가능
DROP POLICY IF EXISTS "Users can update own posts" ON posts;
CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = author_id AND deleted_at IS NULL);

-- DELETE: 삭제되지 않은 본인 게시물만 삭제 가능
-- (hard delete도 여전히 가능하지만, 앱에서는 soft delete 사용 권장)
DROP POLICY IF EXISTS "Users can delete own posts" ON posts;
CREATE POLICY "Users can delete own posts" ON posts
    FOR DELETE USING (auth.uid() = author_id AND deleted_at IS NULL);


-- ================================================================
-- 1-5. Comments RLS 정책 업데이트 (soft delete 반영)
-- ================================================================

-- SELECT: 삭제되지 않은 댓글만 조회 가능
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (deleted_at IS NULL);

-- INSERT: 변경 없음
DROP POLICY IF EXISTS "Users can insert comments" ON comments;
CREATE POLICY "Users can insert comments" ON comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

-- UPDATE: 삭제되지 않은 본인 댓글만 수정 가능
DROP POLICY IF EXISTS "Users can update own comments" ON comments;
CREATE POLICY "Users can update own comments" ON comments
    FOR UPDATE USING (auth.uid() = author_id AND deleted_at IS NULL);

-- DELETE: 삭제되지 않은 본인 댓글만 삭제 가능
DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
CREATE POLICY "Users can delete own comments" ON comments
    FOR DELETE USING (auth.uid() = author_id AND deleted_at IS NULL);


-- ================================================================
-- 1-6. get_feed_posts 함수 업데이트 (soft delete 반영)
-- ================================================================

DROP FUNCTION IF EXISTS get_feed_posts(uuid, integer, integer);
CREATE OR REPLACE FUNCTION get_feed_posts(user_uuid UUID, limit_count INTEGER DEFAULT 20, offset_count INTEGER DEFAULT 0)
RETURNS TABLE (
    id UUID,
    author_id UUID,
    author_name VARCHAR,
    author_photo TEXT,
    pet_id UUID,
    pet_name VARCHAR,
    pet_type VARCHAR,
    image_url TEXT,
    emotion_analysis JSONB,
    caption TEXT,
    hashtags TEXT[],
    likes_count INTEGER,
    comments_count INTEGER,
    created_at TIMESTAMPTZ,
    is_liked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id, p.author_id,
        u.display_name as author_name, u.photo_url as author_photo,
        p.pet_id, pet.name as pet_name, pet.type as pet_type,
        p.image_url, p.emotion_analysis, p.caption, p.hashtags,
        p.likes_count, p.comments_count, p.created_at,
        EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = user_uuid) as is_liked
    FROM posts p
    LEFT JOIN users u ON p.author_id = u.id
    LEFT JOIN pets pet ON p.pet_id = pet.id
    WHERE p.deleted_at IS NULL
    AND (
        p.author_id IN (
            SELECT following_id FROM follows WHERE follower_id = user_uuid
            UNION
            SELECT user_uuid
        ) OR user_uuid IS NULL
    )
    ORDER BY p.created_at DESC
    LIMIT limit_count OFFSET offset_count;
END;
$$ language 'plpgsql' SECURITY DEFINER;


-- ================================================================
-- 1-7. Soft delete helper 함수들
-- ================================================================

-- 게시물 soft delete
CREATE OR REPLACE FUNCTION soft_delete_post(post_uuid UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE posts
    SET deleted_at = NOW()
    WHERE id = post_uuid
    AND author_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$;

-- 댓글 soft delete
CREATE OR REPLACE FUNCTION soft_delete_comment(comment_uuid UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE comments
    SET deleted_at = NOW()
    WHERE id = comment_uuid
    AND author_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$;


-- ================================================================
-- TASK 2: Storage RLS 확인 및 노트
-- ================================================================
--
-- petspace_setup.sql에서 이미 설정된 Storage 구성:
--
--   버킷: 'images' (public: true)
--   폴더 구조: images/{folder}/{user_id}/{filename}
--
--   SQL로 설정된 Storage RLS 정책 (PART 8):
--     - profiles/   : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - pets/       : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - posts/      : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - emotion_analysis/ : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--
--   현재 상태: Storage RLS가 SQL로 올바르게 설정되어 있음.
--   모든 폴더가 user_id 기반으로 격리되어 있어 보안 구성이 적절함.
--
--   [추가 확인/개선 사항 - Supabase Dashboard에서 확인 필요]
--
--   1. 파일 크기 제한:
--      Dashboard > Storage > Settings에서 max file size 설정 권장
--      - 프로필/펫 이미지: 5MB 제한 권장
--      - 게시물 이미지: 10MB 제한 권장
--
--   2. MIME 타입 제한:
--      Dashboard > Storage > Policies에서 allowed MIME types 설정 권장
--      - image/jpeg, image/png, image/webp만 허용 권장
--      - 악성 파일 업로드 방지
--
--   3. 버킷 public 설정 확인:
--      현재 images 버킷이 public=true로 설정됨.
--      이는 SELECT 정책과 무관하게 URL을 아는 사람은 누구나 파일 접근 가능.
--      공개 SNS 특성상 적절하나, emotion_analysis 이미지는
--      private 버킷으로 분리하는 것을 고려할 수 있음.
--
--   4. soft delete된 게시물의 이미지 정리:
--      soft delete된 게시물의 이미지는 Storage에 그대로 남아있음.
--      주기적으로 deleted_at이 오래된 게시물의 이미지를 정리하는
--      Edge Function 또는 cron job 구성을 권장.
--


-- ================================================================
-- DONE
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  PetSpace P2 Fixes 적용 완료!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '  1. posts/comments에 deleted_at 컬럼 추가';
    RAISE NOTICE '  2. RLS 정책 업데이트 (soft delete 반영)';
    RAISE NOTICE '  3. get_feed_posts 함수 업데이트';
    RAISE NOTICE '  4. soft_delete_post/comment 헬퍼 함수 추가';
    RAISE NOTICE '  5. Storage RLS 검토 노트 포함';
    RAISE NOTICE '================================================';
END $$;
