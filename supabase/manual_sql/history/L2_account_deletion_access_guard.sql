-- L2: soft-delete 직후 남아 있을 수 있는 access token의 일반 데이터 접근 차단.
-- public.users 본인 조회는 복구 안내를 위해 유지하고, 복구 RPC만 예외로 둔다.
-- 운영 적용 전 대상 테이블·정책과 private.user_is_active_internal()을 read-only로
-- 확인한다.

BEGIN;

DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'pets',
    'posts',
    'emotion_history',
    'comments',
    'follows',
    'likes',
    'notifications',
    'user_devices',
    'comment_likes',
    'reports',
    'user_blocks',
    'health_records',
    'saved_posts',
    'bookmark_collections',
    'chat_rooms',
    'chat_participants',
    'chat_messages',
    'pet_mbti_results',
    'walk_records',
    'point_transactions',
    'user_quest_progress',
    'user_purchases',
    'user_badges',
    'health_history',
    'notification_preferences'
  ]
  LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      CONTINUE;
    END IF;

    EXECUTE format(
      'DROP POLICY IF EXISTS "Active accounts only" ON public.%I',
      table_name
    );
    EXECUTE format(
      'CREATE POLICY "Active accounts only" ON public.%I '
      'AS RESTRICTIVE FOR ALL TO authenticated '
      'USING (private.user_is_active_internal(auth.uid())) '
      'WITH CHECK (private.user_is_active_internal(auth.uid()))',
      table_name
    );
  END LOOP;
END;
$$;

COMMIT;
