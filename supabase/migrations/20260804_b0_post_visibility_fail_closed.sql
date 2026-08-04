-- B0: posts 공개 범위를 auth.uid() 기준으로 fail-closed 강제한다.
-- 로컬 정본 파일이며 별도 승인 전 운영 DB에 적용하지 않는다.
BEGIN;

DROP POLICY IF EXISTS posts_privacy_fail_closed ON public.posts;
CREATE POLICY posts_privacy_fail_closed
ON public.posts
AS RESTRICTIVE
FOR SELECT
TO authenticated
USING (
  author_id = auth.uid()
  OR is_private IS FALSE
);

-- SECURITY DEFINER는 RLS를 우회하므로 함수 내부에도 같은 owner/public 조건을 둔다.
-- 기존 signature, return type, volatility, search_path와 실행 권한은 변경하지 않는다.
CREATE OR REPLACE FUNCTION public.get_feed_posts(
  user_uuid uuid,
  limit_count integer DEFAULT 20,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name varchar,
  author_photo text,
  pet_id uuid,
  pet_name varchar,
  pet_type varchar,
  image_url text,
  emotion_analysis jsonb,
  caption text,
  hashtags text[],
  likes_count integer,
  comments_count integer,
  created_at timestamptz,
  is_liked boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR (user_uuid IS NOT NULL AND user_uuid <> v_actor) THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;
  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name, u.photo_url AS author_photo,
    p.pet_id, pet.name AS pet_name, pet.type AS pet_type,
    p.image_url, p.emotion_analysis, p.caption, p.hashtags,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS (
      SELECT 1 FROM public.likes l
      WHERE l.post_id = p.id AND l.user_id = v_actor
    ) AS is_liked
  FROM public.posts p
  LEFT JOIN public.users u ON p.author_id = u.id
  LEFT JOIN public.pets pet ON p.pet_id = pet.id
  WHERE p.deleted_at IS NULL
    AND (p.author_id = v_actor OR p.is_private IS FALSE)
    AND private.user_is_active_internal(p.author_id)
    AND (
      p.author_id = v_actor
      OR p.author_id IN (
        SELECT f.following_id FROM public.follows f
        WHERE f.follower_id = v_actor
      )
    )
    AND NOT private.mutually_blocked_internal(v_actor, p.author_id)
  ORDER BY p.created_at DESC
  LIMIT greatest(1, least(coalesce(limit_count, 20), 50))
  OFFSET greatest(coalesce(offset_count, 0), 0);
END;
$$;

-- 집계 RPC도 SECURITY DEFINER이므로 비공개/NULL 게시글의 hashtag를 집계하지 않는다.
CREATE OR REPLACE FUNCTION public.get_popular_hashtags(
  limit_count integer DEFAULT 10
)
RETURNS TABLE (
  hashtag text,
  post_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT unnest(p.hashtags) AS hashtag, count(*) AS post_count
  FROM public.posts p
  WHERE p.deleted_at IS NULL
    AND p.is_private IS FALSE
    AND p.hashtags IS NOT NULL
  GROUP BY unnest(p.hashtags)
  ORDER BY post_count DESC
  LIMIT greatest(1, least(coalesce(limit_count, 10), 50));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_trending_hashtags(
  limit_count integer DEFAULT 10,
  days_ago integer DEFAULT 7
)
RETURNS TABLE (
  hashtag text,
  post_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT unnest(p.hashtags) AS hashtag, count(*) AS post_count
  FROM public.posts p
  WHERE p.deleted_at IS NULL
    AND p.is_private IS FALSE
    AND p.hashtags IS NOT NULL
    AND p.created_at >= now() - (days_ago || ' days')::interval
  GROUP BY unnest(p.hashtags)
  ORDER BY post_count DESC
  LIMIT greatest(1, least(coalesce(limit_count, 10), 50));
END;
$$;

REVOKE ALL ON FUNCTION public.get_popular_hashtags(integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_trending_hashtags(integer, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_popular_hashtags(integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trending_hashtags(integer, integer)
  TO authenticated;

COMMIT;
