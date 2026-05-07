-- ============================================================
-- D-5 차단(Block) 필터링 패치
-- ------------------------------------------------------------
-- 작성일: 2026-05-07
-- 목적:
--   기존 피드/해시태그/위치 RPC 가 user_blocks 를 무시하고 있어
--   A 가 B 를 차단해도 B 의 게시글이 A 의 피드/탐색에 그대로 노출되는 문제를 차단.
--   App Store 1.2 / Google Play UGC 정책 컴플라이언스.
--
-- 적용 대상:
--   - get_feed_posts(uuid, integer, integer)
--   - get_posts_by_hashtag(text, uuid, text, integer, integer)
--   - get_posts_by_location(double precision, double precision, integer, uuid, integer, integer)
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행하거나,
--   `supabase db push` 로 마이그레이션 반영.
--
-- 검증 시나리오:
--   1) 사용자 A 가 사용자 B 를 차단(user_blocks INSERT) 한다.
--   2) B 가 새 게시글을 작성한다.
--   3) A 의 피드/해시태그/위치 검색 결과에서 해당 게시글이 노출되지 않아야 한다.
-- ============================================================

-- ── 1) get_feed_posts: 차단 양방향 필터링 ────────────────────
DROP FUNCTION IF EXISTS get_feed_posts(uuid, integer, integer);
CREATE OR REPLACE FUNCTION get_feed_posts(
    user_uuid UUID,
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
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
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id, p.author_id,
        u.display_name AS author_name, u.photo_url AS author_photo,
        p.pet_id, pet.name AS pet_name, pet.type AS pet_type,
        p.image_url, p.emotion_analysis, p.caption, p.hashtags,
        p.likes_count, p.comments_count, p.created_at,
        EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = user_uuid) AS is_liked
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
    -- ⬇️ D-5 추가: 양방향 차단 필터 (user_uuid 가 NULL 이면 익명 조회이므로 skip)
    AND (
        user_uuid IS NULL
        OR NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_id = user_uuid AND ub.blocked_id = p.author_id)
               OR (ub.blocker_id = p.author_id AND ub.blocked_id = user_uuid)
        )
    )
    ORDER BY p.created_at DESC
    LIMIT limit_count OFFSET offset_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_feed_posts(UUID, INTEGER, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION get_feed_posts(UUID, INTEGER, INTEGER) TO authenticated;


-- ── 2) get_posts_by_hashtag: 차단 양방향 필터링 ──────────────
CREATE OR REPLACE FUNCTION get_posts_by_hashtag(
  p_hashtag TEXT,
  p_user_id UUID DEFAULT NULL,
  p_sort TEXT DEFAULT 'popular',
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  author_id UUID,
  author_name VARCHAR,
  author_photo TEXT,
  pet_id UUID,
  image_url TEXT,
  caption TEXT,
  hashtags TEXT[],
  likes_count INTEGER,
  comments_count INTEGER,
  created_at TIMESTAMPTZ,
  is_liked BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name,
    u.photo_url AS author_photo,
    p.pet_id, p.image_url, p.caption, p.hashtags,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked
  FROM posts p
  LEFT JOIN users u ON p.author_id = u.id
  WHERE
    p.deleted_at IS NULL
    AND p.is_private = FALSE
    AND p.hashtags && ARRAY[p_hashtag]
    -- ⬇️ D-5 추가: 양방향 차단 필터
    AND (
      p_user_id IS NULL
      OR NOT EXISTS (
        SELECT 1 FROM user_blocks ub
        WHERE (ub.blocker_id = p_user_id AND ub.blocked_id = p.author_id)
           OR (ub.blocker_id = p.author_id AND ub.blocked_id = p_user_id)
      )
    )
  ORDER BY
    CASE WHEN p_sort = 'popular' THEN p.likes_count ELSE 0 END DESC,
    p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_posts_by_hashtag(TEXT, UUID, TEXT, INTEGER, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION get_posts_by_hashtag(TEXT, UUID, TEXT, INTEGER, INTEGER) TO authenticated;


-- ── 3) get_posts_by_location: 차단 양방향 필터링 ─────────────
CREATE OR REPLACE FUNCTION get_posts_by_location(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_m INTEGER DEFAULT 50,
  p_user_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  author_id UUID,
  author_name VARCHAR,
  author_photo TEXT,
  pet_id UUID,
  image_url TEXT,
  caption TEXT,
  location TEXT,
  likes_count INTEGER,
  comments_count INTEGER,
  created_at TIMESTAMPTZ,
  is_liked BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lat_delta DOUBLE PRECISION;
  v_lng_delta DOUBLE PRECISION;
BEGIN
  v_lat_delta := p_radius_m / 111000.0;
  v_lng_delta := p_radius_m / (111000.0 * COS(RADIANS(p_lat)));

  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name,
    u.photo_url AS author_photo,
    p.pet_id, p.image_url, p.caption, p.location,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked
  FROM posts p
  LEFT JOIN users u ON p.author_id = u.id
  WHERE
    p.deleted_at IS NULL
    AND p.is_private = FALSE
    AND p.location_lat IS NOT NULL
    AND p.location_lng IS NOT NULL
    AND p.location_lat BETWEEN (p_lat - v_lat_delta) AND (p_lat + v_lat_delta)
    AND p.location_lng BETWEEN (p_lng - v_lng_delta) AND (p_lng + v_lng_delta)
    -- ⬇️ D-5 추가: 양방향 차단 필터
    AND (
      p_user_id IS NULL
      OR NOT EXISTS (
        SELECT 1 FROM user_blocks ub
        WHERE (ub.blocker_id = p_user_id AND ub.blocked_id = p.author_id)
           OR (ub.blocker_id = p.author_id AND ub.blocked_id = p_user_id)
      )
    )
  ORDER BY p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_posts_by_location(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, UUID, INTEGER, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION get_posts_by_location(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, UUID, INTEGER, INTEGER) TO authenticated;


-- ============================================================
-- 검증용 SQL (실행 후 주석 처리하거나 삭제)
-- ============================================================
-- 사용자 A 가 사용자 B 를 차단했을 때 A 의 피드에 B 게시글이 안 보이는지 확인
-- DO $$
-- DECLARE
--   v_a UUID := '<USER_A_UUID>';
--   v_b UUID := '<USER_B_UUID>';
--   v_count INTEGER;
-- BEGIN
--   INSERT INTO user_blocks(blocker_id, blocked_id) VALUES (v_a, v_b)
--     ON CONFLICT DO NOTHING;
--   SELECT COUNT(*) INTO v_count FROM get_feed_posts(v_a, 100, 0)
--     WHERE author_id = v_b;
--   RAISE NOTICE 'A 의 피드에 보이는 B 게시글 수 = %', v_count;
--   ASSERT v_count = 0, 'D-5 차단 필터링 실패';
--   DELETE FROM user_blocks WHERE blocker_id = v_a AND blocked_id = v_b;
-- END$$;
