-- CURRENT RELEASE APPLY FILE (2026-08-04)
-- Run only after FIREBASE_SERVICE_ACCOUNT_KEY and FIREBASE_PROJECT_ID are
-- registered and send-push-notification is deployed with JWT verification.
-- This file never stores production secrets. Re-running is idempotent.

-- P2A-1: canonical notification contract
-- Local implementation only. Apply to production only after explicit approval.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS event_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_event_key
  ON public.notifications(event_key)
  WHERE event_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.notification_type_preference_enabled(
  p_user_id UUID,
  p_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enabled BOOLEAN;
BEGIN
  SELECT CASE p_type
    WHEN 'like' THEN enabled_like
    WHEN 'comment' THEN enabled_comment
    WHEN 'follow' THEN enabled_follow
    WHEN 'mention' THEN enabled_mention
    WHEN 'system' THEN enabled_system
    WHEN 'admin_new_post' THEN enabled_system
    WHEN 'emotion_analysis' THEN enabled_system
    WHEN 'health_alert' THEN enabled_health_alert
    ELSE FALSE
  END
  INTO v_enabled
  FROM public.notification_preferences
  WHERE user_id = p_user_id;

  RETURN COALESCE(v_enabled, FALSE);
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_sender_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_post_id UUID DEFAULT NULL,
  p_comment_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::JSONB,
  p_event_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_event_key TEXT := NULLIF(BTRIM(p_event_key), '');
BEGIN
  IF p_user_id IS NULL
     OR p_type IS NULL
     OR BTRIM(p_type) = ''
     OR p_title IS NULL
     OR BTRIM(p_title) = ''
     OR p_body IS NULL
     OR BTRIM(p_body) = ''
     OR v_event_key IS NULL THEN
    RAISE EXCEPTION 'invalid notification contract';
  END IF;

  IF p_sender_id IS NOT NULL AND p_sender_id = p_user_id THEN
    RETURN NULL;
  END IF;

  IF NOT public.notification_type_preference_enabled(p_user_id, p_type) THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.notifications (
    user_id,
    sender_id,
    type,
    title,
    body,
    post_id,
    comment_id,
    data,
    read,
    is_sent,
    event_key
  )
  VALUES (
    p_user_id,
    p_sender_id,
    p_type,
    p_title,
    p_body,
    p_post_id,
    p_comment_id,
    COALESCE(p_data, '{}'::JSONB) || jsonb_build_object('type', p_type),
    FALSE,
    FALSE,
    v_event_key
  )
  ON CONFLICT (event_key) WHERE event_key IS NOT NULL
  DO UPDATE SET event_key = EXCLUDED.event_key
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

REVOKE ALL ON FUNCTION public.notification_type_preference_enabled(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_notification(
  UUID, UUID, TEXT, TEXT, TEXT, UUID, UUID, JSONB, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(
  UUID, UUID, TEXT, TEXT, TEXT, UUID, UUID, JSONB, TEXT
) TO service_role;

CREATE OR REPLACE FUNCTION public.notify_on_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_author_id UUID;
  v_sender_name TEXT;
BEGIN
  BEGIN
    SELECT author_id INTO v_post_author_id
    FROM public.posts
    WHERE id = NEW.post_id;

    IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
      RETURN NEW;
    END IF;

    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM public.users
    WHERE id = NEW.user_id;

    PERFORM public.create_notification(
      p_user_id := v_post_author_id,
      p_sender_id := NEW.user_id,
      p_type := 'like',
      p_title := '새로운 좋아요',
      p_body := v_sender_name || '님이 회원님의 게시글을 좋아합니다.',
      p_post_id := NEW.post_id,
      p_data := jsonb_build_object(
        'post_id', NEW.post_id::TEXT,
        'sender_id', NEW.user_id::TEXT,
        'sender_name', v_sender_name
      ),
      p_event_key := 'like:' || NEW.id::TEXT
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'notify_on_like error: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_author_id UUID;
  v_sender_name TEXT;
  v_preview TEXT;
BEGIN
  BEGIN
    SELECT author_id INTO v_post_author_id
    FROM public.posts
    WHERE id = NEW.post_id;

    IF v_post_author_id IS NULL OR v_post_author_id = NEW.author_id THEN
      RETURN NEW;
    END IF;

    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM public.users
    WHERE id = NEW.author_id;

    v_preview := LEFT(COALESCE(NEW.content, ''), 50);
    IF LENGTH(COALESCE(NEW.content, '')) > 50 THEN
      v_preview := v_preview || '...';
    END IF;

    PERFORM public.create_notification(
      p_user_id := v_post_author_id,
      p_sender_id := NEW.author_id,
      p_type := 'comment',
      p_title := '새로운 댓글',
      p_body := v_sender_name || ': ' || v_preview,
      p_post_id := NEW.post_id,
      p_comment_id := NEW.id,
      p_data := jsonb_build_object(
        'post_id', NEW.post_id::TEXT,
        'comment_id', NEW.id::TEXT,
        'sender_id', NEW.author_id::TEXT,
        'sender_name', v_sender_name
      ),
      p_event_key := 'comment:' || NEW.id::TEXT
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'notify_on_comment error: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  BEGIN
    IF NEW.follower_id = NEW.following_id THEN
      RETURN NEW;
    END IF;

    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM public.users
    WHERE id = NEW.follower_id;

    PERFORM public.create_notification(
      p_user_id := NEW.following_id,
      p_sender_id := NEW.follower_id,
      p_type := 'follow',
      p_title := '새로운 팔로워',
      p_body := v_sender_name || '님이 회원님을 팔로우하기 시작했어요.',
      p_data := jsonb_build_object(
        'sender_id', NEW.follower_id::TEXT,
        'sender_name', v_sender_name
      ),
      p_event_key := 'follow:' || NEW.id::TEXT
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'notify_on_follow error: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);

  IF nullif(btrim(v_supabase_url), '') IS NULL
     OR nullif(btrim(v_service_key), '') IS NULL THEN
    RAISE WARNING
      'notify_push_on_notification: required app.settings are missing';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := jsonb_build_object('notification_id', NEW.id::TEXT)
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_push_on_notification error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_on_like ON public.likes;
CREATE TRIGGER trigger_notify_on_like
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_like();

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON public.comments;
CREATE TRIGGER trigger_notify_on_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_comment();

DROP TRIGGER IF EXISTS trigger_notify_on_follow ON public.follows;
CREATE TRIGGER trigger_notify_on_follow
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_follow();

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_on_notification();

REVOKE ALL ON FUNCTION public.notify_on_like()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_on_comment()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_on_follow()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_push_on_notification()
  FROM PUBLIC, anon, authenticated;

COMMIT;

-- Verification: all rows must be true. The settings become true only after
-- the separate, secret-bearing ALTER DATABASE commands are run by the owner.
SELECT
  to_regprocedure('public.create_notification(uuid,uuid,text,text,text,uuid,uuid,jsonb,text)')
    IS NOT NULL AS create_notification_exists,
  to_regprocedure('public.notify_push_on_notification()')
    IS NOT NULL AS push_function_exists,
  EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_push_on_notification' AND NOT tgisinternal
  ) AS push_trigger_exists,
  NULLIF(BTRIM(current_setting('app.settings.supabase_url', true)), '')
    IS NOT NULL AS supabase_url_setting_exists,
  NULLIF(BTRIM(current_setting('app.settings.service_role_key', true)), '')
    IS NOT NULL AS service_role_setting_exists;
