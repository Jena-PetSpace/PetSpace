-- MY-CLOSE P2B / K1: auth.uid()-anchored block and privacy contract.

BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.mutually_blocked_internal(p_user_a uuid, p_user_b uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_id = p_user_a AND blocked_id = p_user_b)
       OR (blocker_id = p_user_b AND blocked_id = p_user_a)
  );
$$;
REVOKE ALL ON FUNCTION private.mutually_blocked_internal(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.mutually_blocked_internal(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.user_is_active_internal(p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND deleted_at IS NULL
  );
$$;
REVOKE ALL ON FUNCTION private.user_is_active_internal(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.user_is_active_internal(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.lock_user_pair_internal(
  p_user_a uuid,
  p_user_b uuid
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_a IS NULL OR p_user_b IS NULL OR p_user_a = p_user_b THEN
    RETURN;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(
    least(p_user_a::text, p_user_b::text) || ':' ||
    greatest(p_user_a::text, p_user_b::text),
    0
  ));
END;
$$;
REVOKE ALL ON FUNCTION private.lock_user_pair_internal(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.direct_chat_allowed_internal(
  p_room_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce((
    SELECT CASE
      WHEN r.type <> 'direct' THEN true
      ELSE NOT EXISTS (
        SELECT 1
        FROM public.chat_participants cp
        WHERE cp.room_id = r.id
          AND cp.is_active
          AND cp.user_id <> p_user_id
          AND private.mutually_blocked_internal(p_user_id, cp.user_id)
      )
    END
    FROM public.chat_rooms r
    WHERE r.id = p_room_id
  ), false);
$$;
REVOKE ALL ON FUNCTION private.direct_chat_allowed_internal(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.direct_chat_allowed_internal(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.reply_target_allowed_internal(
  p_parent_id uuid,
  p_post_id uuid,
  p_actor_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_parent_id IS NULL OR EXISTS (
    SELECT 1
    FROM public.comments parent
    WHERE parent.id = p_parent_id
      AND parent.post_id = p_post_id
      AND parent.deleted_at IS NULL
      AND private.user_is_active_internal(parent.author_id)
      AND NOT private.mutually_blocked_internal(p_actor_id, parent.author_id)
  );
$$;
REVOKE ALL ON FUNCTION private.reply_target_allowed_internal(uuid, uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.reply_target_allowed_internal(uuid, uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.is_room_member(
  p_room_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE room_id = p_room_id
      AND user_id = p_user_id
      AND is_active
  );
$$;
REVOKE ALL ON FUNCTION private.is_room_member(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_room_member(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.can_manage_group_participants(
  p_room_id uuid,
  p_actor_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_rooms r
    WHERE r.id = p_room_id
      AND r.type = 'group'
      AND (
        r.created_by = p_actor_id
        OR EXISTS (
          SELECT 1
          FROM public.chat_participants cp
          WHERE cp.room_id = r.id
            AND cp.user_id = p_actor_id
            AND cp.role = 'admin'
            AND cp.is_active
        )
      )
  );
$$;
REVOKE ALL ON FUNCTION private.can_manage_group_participants(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.can_manage_group_participants(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.enforce_direct_room_participant_limit()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_active_count integer;
BEGIN
  IF coalesce(NEW.is_active, true)
    AND EXISTS (
      SELECT 1 FROM public.chat_rooms
      WHERE id = NEW.room_id AND type = 'direct'
    )
  THEN
    SELECT count(*) INTO v_active_count
    FROM public.chat_participants cp
    WHERE cp.room_id = NEW.room_id
      AND cp.is_active
      AND cp.id <> NEW.id;
    IF v_active_count >= 2 THEN
      RAISE EXCEPTION 'direct room participant limit exceeded';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.enforce_direct_room_participant_limit()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_direct_room_participant_limit
  ON public.chat_participants;
CREATE TRIGGER enforce_direct_room_participant_limit
  BEFORE INSERT OR UPDATE OF room_id, user_id, is_active
  ON public.chat_participants
  FOR EACH ROW
  EXECUTE FUNCTION private.enforce_direct_room_participant_limit();

CREATE OR REPLACE FUNCTION private.guard_chat_participant_self_update()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND (
    NEW.id IS DISTINCT FROM OLD.id
    OR NEW.room_id IS DISTINCT FROM OLD.room_id
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.role IS DISTINCT FROM OLD.role
    OR NEW.joined_at IS DISTINCT FROM OLD.joined_at
    OR (NOT OLD.is_active AND NEW.is_active)
  ) THEN
    RAISE EXCEPTION 'participant identity and role are immutable';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_participant_self_update()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_chat_participant_self_update
  ON public.chat_participants;
CREATE TRIGGER guard_chat_participant_self_update
  BEFORE UPDATE
  ON public.chat_participants
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_chat_participant_self_update();

CREATE OR REPLACE FUNCTION private.guard_blocked_interaction_insert()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_room_type text;
  v_target uuid;
  v_targets uuid[] := '{}'::uuid[];
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  CASE TG_TABLE_NAME
    WHEN 'follows' THEN
      IF NEW.follower_id <> v_actor THEN RAISE EXCEPTION 'request not allowed'; END IF;
      v_targets := ARRAY[NEW.following_id];
    WHEN 'likes' THEN
      IF NEW.user_id <> v_actor THEN RAISE EXCEPTION 'request not allowed'; END IF;
      SELECT ARRAY[p.author_id] INTO v_targets
      FROM public.posts p WHERE p.id = NEW.post_id;
    WHEN 'comments' THEN
      IF NEW.author_id <> v_actor THEN RAISE EXCEPTION 'request not allowed'; END IF;
      SELECT ARRAY[p.author_id, parent.author_id] INTO v_targets
      FROM public.posts p
      LEFT JOIN public.comments parent ON parent.id = NEW.parent_id
      WHERE p.id = NEW.post_id;
    WHEN 'comment_likes' THEN
      IF NEW.user_id <> v_actor THEN RAISE EXCEPTION 'request not allowed'; END IF;
      SELECT ARRAY[c.author_id, p.author_id] INTO v_targets
      FROM public.comments c
      JOIN public.posts p ON p.id = c.post_id
      WHERE c.id = NEW.comment_id;
    WHEN 'chat_participants' THEN
      v_targets := ARRAY[NEW.user_id];
    WHEN 'chat_messages' THEN
      IF NEW.sender_id <> v_actor THEN RAISE EXCEPTION 'request not allowed'; END IF;
      SELECT r.type INTO v_room_type
      FROM public.chat_rooms r WHERE r.id = NEW.room_id;
      IF v_room_type = 'direct' THEN
        SELECT coalesce(array_agg(cp.user_id), '{}'::uuid[]) INTO v_targets
        FROM public.chat_participants cp
        WHERE cp.room_id = NEW.room_id
          AND cp.is_active
          AND cp.user_id <> v_actor;
      END IF;
    ELSE
      RAISE EXCEPTION 'unsupported interaction table';
  END CASE;

  FOR v_target IN
    SELECT DISTINCT target_id
    FROM unnest(coalesce(v_targets, '{}'::uuid[])) AS target_ids(target_id)
    WHERE target_id IS NOT NULL AND target_id <> v_actor
    ORDER BY target_id
  LOOP
    PERFORM private.lock_user_pair_internal(v_actor, v_target);
    IF private.mutually_blocked_internal(v_actor, v_target) THEN
      RAISE EXCEPTION 'request not allowed';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_blocked_interaction_insert()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_blocked_follow_insert ON public.follows;
CREATE TRIGGER guard_blocked_follow_insert
  BEFORE INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();
DROP TRIGGER IF EXISTS guard_blocked_like_insert ON public.likes;
CREATE TRIGGER guard_blocked_like_insert
  BEFORE INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();
DROP TRIGGER IF EXISTS guard_blocked_comment_insert ON public.comments;
CREATE TRIGGER guard_blocked_comment_insert
  BEFORE INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();
DROP TRIGGER IF EXISTS guard_blocked_comment_like_insert ON public.comment_likes;
CREATE TRIGGER guard_blocked_comment_like_insert
  BEFORE INSERT ON public.comment_likes
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();
DROP TRIGGER IF EXISTS guard_blocked_chat_participant_insert
  ON public.chat_participants;
CREATE TRIGGER guard_blocked_chat_participant_insert
  BEFORE INSERT ON public.chat_participants
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();
DROP TRIGGER IF EXISTS guard_blocked_chat_message_insert
  ON public.chat_messages;
CREATE TRIGGER guard_blocked_chat_message_insert
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION private.guard_blocked_interaction_insert();

REVOKE ALL ON FUNCTION public.is_room_member(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF v_actor = p_blocked_id THEN RAISE EXCEPTION 'self block is not allowed'; END IF;
  IF NOT private.user_is_active_internal(p_blocked_id) THEN
    RAISE EXCEPTION 'user not found';
  END IF;
  PERFORM private.lock_user_pair_internal(v_actor, p_blocked_id);
  INSERT INTO public.user_blocks(blocker_id, blocked_id)
  VALUES (v_actor, p_blocked_id) ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
  DELETE FROM public.follows
  WHERE (follower_id = v_actor AND following_id = p_blocked_id)
     OR (follower_id = p_blocked_id AND following_id = v_actor);
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.user_blocks
  WHERE blocker_id = auth.uid() AND blocked_id = p_blocked_id;
$$;

CREATE OR REPLACE FUNCTION public.get_my_blocked_user_ids()
RETURNS TABLE(blocked_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ub.blocked_id FROM public.user_blocks ub
  WHERE ub.blocker_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_mutually_blocked_with(p_other_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT private.mutually_blocked_internal(auth.uid(), p_other_user_id);
$$;

CREATE OR REPLACE FUNCTION public.get_blocked_users(
  p_limit integer DEFAULT 20,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_query text DEFAULT NULL
)
RETURNS TABLE(
  blocked_id uuid, display_name text, username text, photo_url text,
  blocked_at timestamptz, block_id uuid
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ub.blocked_id, u.display_name::text, u.username::text, u.photo_url,
         ub.created_at AS blocked_at, ub.id AS block_id
  FROM public.user_blocks ub
  JOIN public.users u ON u.id = ub.blocked_id
  WHERE ub.blocker_id = auth.uid()
    AND (
      p_before_created_at IS NULL OR p_before_id IS NULL OR
      (ub.created_at, ub.id) < (p_before_created_at, p_before_id)
    )
    AND (
      nullif(btrim(regexp_replace(btrim(coalesce(p_query, '')), '^@+', '')), '') IS NULL
      OR u.display_name ILIKE '%' ||
        btrim(regexp_replace(btrim(coalesce(p_query, '')), '^@+', '')) || '%'
      OR u.username ILIKE '%' ||
        btrim(regexp_replace(btrim(coalesce(p_query, '')), '^@+', '')) || '%'
    )
  ORDER BY ub.created_at DESC, ub.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 20));
$$;

REVOKE ALL ON FUNCTION public.get_blocked_user_ids(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_mutually_blocked(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_total_unread_count(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_room_unread_count(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.find_direct_chat(uuid, uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_my_blocked_user_ids() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_mutually_blocked_with(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_blocked_users(integer,timestamptz,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_blocked_user_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_mutually_blocked_with(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_blocked_users(integer,timestamptz,uuid,text) TO authenticated;

DROP POLICY IF EXISTS "Users can create blocks for themselves" ON public.user_blocks;
DROP POLICY IF EXISTS "Users can delete their own blocks" ON public.user_blocks;
DROP POLICY IF EXISTS user_blocks_insert_own ON public.user_blocks;
DROP POLICY IF EXISTS user_blocks_delete_own ON public.user_blocks;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_blocks
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_user_profile()
RETURNS SETOF public.users
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT * FROM public.users WHERE id = auth.uid(); $$;
REVOKE ALL ON FUNCTION public.get_my_user_profile() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_user_profile() TO authenticated;

CREATE OR REPLACE FUNCTION public.ensure_my_user_profile(
  p_display_name text DEFAULT NULL,
  p_photo_url text DEFAULT NULL,
  p_provider text DEFAULT NULL
)
RETURNS SETOF public.users
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text;
  v_metadata jsonb;
  v_provider text;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT au.email, coalesce(au.raw_user_meta_data, '{}'::jsonb)
  INTO v_email, v_metadata
  FROM auth.users au
  WHERE au.id = v_actor;
  IF v_email IS NULL THEN RAISE EXCEPTION 'authenticated user not found'; END IF;

  v_provider := lower(coalesce(
    nullif(btrim(p_provider), ''),
    nullif(btrim(v_metadata->>'provider'), ''),
    'email'
  ));
  IF v_provider NOT IN ('email', 'google', 'apple', 'kakao') THEN
    v_provider := 'email';
  END IF;

  INSERT INTO public.users(
    id, email, display_name, photo_url, provider, is_onboarding_completed
  )
  VALUES (
    v_actor,
    v_email,
    coalesce(
      nullif(btrim(p_display_name), ''),
      nullif(btrim(v_metadata->>'display_name'), ''),
      nullif(btrim(v_metadata->>'full_name'), ''),
      nullif(btrim(v_metadata->>'name'), ''),
      split_part(v_email, '@', 1)
    ),
    coalesce(
      nullif(btrim(p_photo_url), ''),
      nullif(btrim(v_metadata->>'photo_url'), ''),
      nullif(btrim(v_metadata->>'avatar_url'), '')
    ),
    v_provider,
    false
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN QUERY SELECT * FROM public.users WHERE id = v_actor;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_my_user_profile(text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_my_user_profile(text, text, text)
  TO authenticated;
REVOKE SELECT ON TABLE public.users FROM authenticated;
GRANT SELECT (id, display_name, username, photo_url, bio, created_at, updated_at)
  ON TABLE public.users TO authenticated;

CREATE OR REPLACE FUNCTION public.get_total_unread_count()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*) FROM public.chat_messages m
  JOIN public.chat_participants cp ON cp.room_id = m.room_id
  WHERE cp.user_id = auth.uid() AND cp.is_active
    AND m.created_at > coalesce(cp.last_read_at, '-infinity'::timestamptz)
    AND m.sender_id <> auth.uid()
    AND NOT private.mutually_blocked_internal(auth.uid(), m.sender_id);
$$;

CREATE OR REPLACE FUNCTION public.get_room_unread_count(p_room_id uuid)
RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE room_id = p_room_id AND user_id = auth.uid() AND is_active
  ) THEN RAISE EXCEPTION 'room membership required'; END IF;
  SELECT count(*) INTO v_count FROM public.chat_messages m
  JOIN public.chat_participants cp ON cp.room_id = m.room_id
  WHERE m.room_id = p_room_id AND cp.user_id = auth.uid()
    AND m.created_at > coalesce(cp.last_read_at, '-infinity'::timestamptz)
    AND m.sender_id <> auth.uid()
    AND NOT private.mutually_blocked_internal(auth.uid(), m.sender_id);
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_direct_chat(p_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid := auth.uid(); v_room uuid;
BEGIN
  IF v_actor IS NULL OR p_other_user_id = v_actor THEN RAISE EXCEPTION 'invalid user'; END IF;
  IF NOT private.user_is_active_internal(p_other_user_id) THEN
    RAISE EXCEPTION 'user not found';
  END IF;
  PERFORM private.lock_user_pair_internal(v_actor, p_other_user_id);
  IF private.mutually_blocked_internal(v_actor, p_other_user_id) THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;
  SELECT r.id INTO v_room FROM public.chat_rooms r
  JOIN public.chat_participants a ON a.room_id=r.id AND a.user_id=v_actor AND a.is_active
  JOIN public.chat_participants b ON b.room_id=r.id AND b.user_id=p_other_user_id AND b.is_active
  WHERE r.type='direct'
    AND (
      SELECT count(*)
      FROM public.chat_participants cp
      WHERE cp.room_id = r.id AND cp.is_active
    ) = 2
  LIMIT 1;
  IF v_room IS NULL THEN
    INSERT INTO public.chat_rooms(type, created_by) VALUES ('direct', v_actor) RETURNING id INTO v_room;
    INSERT INTO public.chat_participants(room_id,user_id,role)
    VALUES (v_room,v_actor,'admin'),(v_room,p_other_user_id,'member');
  END IF;
  RETURN v_room;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_group_chat(
  p_name text,
  p_member_ids uuid[] DEFAULT '{}'::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_room uuid;
  v_member uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF nullif(btrim(p_name), '') IS NULL THEN RAISE EXCEPTION 'invalid room name'; END IF;

  FOR v_member IN
    SELECT DISTINCT member_id
    FROM unnest(coalesce(p_member_ids, '{}'::uuid[])) AS members(member_id)
    WHERE member_id IS NOT NULL AND member_id <> v_actor
    ORDER BY member_id
  LOOP
    PERFORM private.lock_user_pair_internal(v_actor, v_member);
    IF NOT private.user_is_active_internal(v_member)
      OR private.mutually_blocked_internal(v_actor, v_member)
    THEN
      RAISE EXCEPTION 'request not allowed';
    END IF;
  END LOOP;

  INSERT INTO public.chat_rooms(type, name, created_by)
  VALUES ('group', btrim(p_name), v_actor)
  RETURNING id INTO v_room;

  INSERT INTO public.chat_participants(room_id, user_id, role)
  VALUES (v_room, v_actor, 'admin');
  INSERT INTO public.chat_participants(room_id, user_id, role)
  SELECT v_room, member_id, 'member'
  FROM (
    SELECT DISTINCT member_id
    FROM unnest(coalesce(p_member_ids, '{}'::uuid[])) AS input_members(member_id)
    WHERE member_id IS NOT NULL AND member_id <> v_actor
  ) members;

  INSERT INTO public.chat_messages(room_id, sender_id, content, type)
  VALUES (v_room, v_actor, '그룹 채팅이 시작되었습니다.', 'system');
  RETURN v_room;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_chat_room_last_message()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET
    last_message = CASE
      WHEN NEW.type = 'image' THEN '사진을 보냈습니다'
      ELSE NEW.content
    END,
    last_message_at = NEW.created_at,
    last_message_sender_id = NEW.sender_id
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.update_chat_room_last_message()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_total_unread_count() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_room_unread_count(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_or_create_direct_chat(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_group_chat(text, uuid[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_total_unread_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_room_unread_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_chat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_group_chat(text, uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id uuid, p_sender_id uuid, p_type text, p_title text, p_body text,
  p_post_id uuid DEFAULT NULL, p_comment_id uuid DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb, p_event_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid; v_key text := nullif(btrim(p_event_key), '');
BEGIN
  IF p_user_id IS NULL
    OR v_key IS NULL
    OR nullif(btrim(p_type), '') IS NULL
    OR nullif(btrim(p_title), '') IS NULL
    OR nullif(btrim(p_body), '') IS NULL
  THEN
    RAISE EXCEPTION 'invalid notification contract';
  END IF;
  IF p_sender_id IS NOT NULL THEN
    PERFORM private.lock_user_pair_internal(p_user_id, p_sender_id);
  END IF;
  IF p_sender_id = p_user_id OR (
    p_sender_id IS NOT NULL
    AND private.mutually_blocked_internal(p_user_id, p_sender_id)
  ) THEN RETURN NULL; END IF;
  IF NOT public.notification_type_preference_enabled(p_user_id, p_type) THEN
    RETURN NULL;
  END IF;
  INSERT INTO public.notifications(
    user_id,sender_id,type,title,body,post_id,comment_id,data,read,is_sent,event_key
  ) VALUES (
    p_user_id,p_sender_id,p_type,p_title,p_body,p_post_id,p_comment_id,
    coalesce(p_data,'{}'::jsonb) || jsonb_build_object('type',p_type),
    false,false,v_key
  )
  ON CONFLICT (event_key) WHERE event_key IS NOT NULL
  DO UPDATE SET event_key=excluded.event_key
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.create_notification(
  uuid,uuid,text,text,text,uuid,uuid,jsonb,text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(
  uuid,uuid,text,text,text,uuid,uuid,jsonb,text
) TO service_role;

CREATE OR REPLACE FUNCTION public.notification_delivery_allowed(p_notification_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(bool_and(
    n.sender_id IS NULL OR NOT private.mutually_blocked_internal(n.user_id, n.sender_id)
  ), false)
  FROM public.notifications n WHERE n.id = p_notification_id;
$$;
REVOKE ALL ON FUNCTION public.notification_delivery_allowed(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_delivery_allowed(uuid) TO service_role;

DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.users;
DROP POLICY IF EXISTS users_select_visible ON public.users;
CREATE POLICY users_select_visible ON public.users FOR SELECT TO authenticated
USING (id = auth.uid() OR (deleted_at IS NULL AND NOT private.mutually_blocked_internal(auth.uid(), id)));

DROP POLICY IF EXISTS "Users can view follows" ON public.follows;
DROP POLICY IF EXISTS follows_select_visible ON public.follows;
CREATE POLICY follows_select_visible ON public.follows FOR SELECT TO authenticated
USING (
  NOT private.mutually_blocked_internal(auth.uid(), follower_id)
  AND NOT private.mutually_blocked_internal(auth.uid(), following_id)
);
DROP POLICY IF EXISTS "Users can follow others" ON public.follows;
DROP POLICY IF EXISTS follows_insert_unblocked ON public.follows;
CREATE POLICY follows_insert_unblocked ON public.follows FOR INSERT TO authenticated
WITH CHECK (
  follower_id = auth.uid()
  AND NOT private.mutually_blocked_internal(follower_id, following_id)
);

DROP POLICY IF EXISTS "Posts are viewable by everyone" ON public.posts;
DROP POLICY IF EXISTS posts_select_visible ON public.posts;
CREATE POLICY posts_select_visible ON public.posts FOR SELECT TO authenticated
USING (
  deleted_at IS NULL
  AND private.user_is_active_internal(author_id)
  AND NOT private.mutually_blocked_internal(auth.uid(), author_id)
);

DROP POLICY IF EXISTS "Comments are viewable by everyone" ON public.comments;
DROP POLICY IF EXISTS comments_select_visible ON public.comments;
CREATE POLICY comments_select_visible ON public.comments FOR SELECT TO authenticated
USING (
  deleted_at IS NULL
  AND private.user_is_active_internal(author_id)
  AND NOT private.mutually_blocked_internal(auth.uid(), author_id)
  AND EXISTS (
    SELECT 1 FROM public.posts p
    WHERE p.id = comments.post_id
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
);

DROP POLICY IF EXISTS "Users can view likes" ON public.likes;
DROP POLICY IF EXISTS likes_select_visible ON public.likes;
CREATE POLICY likes_select_visible ON public.likes FOR SELECT TO authenticated
USING (
  NOT private.mutually_blocked_internal(auth.uid(), user_id)
  AND EXISTS (
    SELECT 1 FROM public.posts p
    WHERE p.id = likes.post_id
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
);
DROP POLICY IF EXISTS "Users can like posts" ON public.likes;
DROP POLICY IF EXISTS likes_insert_unblocked ON public.likes;
CREATE POLICY likes_insert_unblocked ON public.likes FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.posts p
    WHERE p.id = likes.post_id
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
);

DROP POLICY IF EXISTS "Users can insert comments" ON public.comments;
DROP POLICY IF EXISTS comments_insert_unblocked ON public.comments;
CREATE POLICY comments_insert_unblocked ON public.comments FOR INSERT TO authenticated
WITH CHECK (
  author_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.posts p
    WHERE p.id = comments.post_id
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
  AND private.reply_target_allowed_internal(
    comments.parent_id,
    comments.post_id,
    auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can view all comment likes" ON public.comment_likes;
DROP POLICY IF EXISTS comment_likes_select_visible ON public.comment_likes;
CREATE POLICY comment_likes_select_visible ON public.comment_likes FOR SELECT TO authenticated
USING (
  NOT private.mutually_blocked_internal(auth.uid(), user_id)
  AND EXISTS (
    SELECT 1
    FROM public.comments c
    JOIN public.posts p ON p.id = c.post_id
    WHERE c.id = comment_likes.comment_id
      AND c.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(c.author_id)
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), c.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
);
DROP POLICY IF EXISTS "Users can create comment likes for themselves" ON public.comment_likes;
DROP POLICY IF EXISTS comment_likes_insert_unblocked ON public.comment_likes;
CREATE POLICY comment_likes_insert_unblocked ON public.comment_likes FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid() AND EXISTS (
    SELECT 1
    FROM public.comments c
    JOIN public.posts p ON p.id = c.post_id
    WHERE c.id = comment_likes.comment_id
      AND c.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND private.user_is_active_internal(c.author_id)
      AND private.user_is_active_internal(p.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), c.author_id)
      AND NOT private.mutually_blocked_internal(auth.uid(), p.author_id)
  )
);

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_select_own_unblocked ON public.notifications;
CREATE POLICY notifications_select_own_unblocked ON public.notifications FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND (sender_id IS NULL OR NOT private.mutually_blocked_internal(auth.uid(), sender_id))
);

DROP POLICY IF EXISTS "Users can view rooms they participate in" ON public.chat_rooms;
DROP POLICY IF EXISTS chat_rooms_select_visible ON public.chat_rooms;
CREATE POLICY chat_rooms_select_visible ON public.chat_rooms FOR SELECT TO authenticated
USING (
  private.is_room_member(chat_rooms.id, auth.uid())
  AND (
    type <> 'direct'
    OR private.direct_chat_allowed_internal(chat_rooms.id, auth.uid())
  )
);

DROP POLICY IF EXISTS "Authenticated users can create chat rooms"
  ON public.chat_rooms;
DROP POLICY IF EXISTS chat_rooms_insert_authenticated ON public.chat_rooms;
REVOKE INSERT ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, type, name, description, avatar_url, created_by, created_at, updated_at
) ON TABLE public.chat_rooms TO authenticated;
REVOKE UPDATE ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT UPDATE (name, description, avatar_url)
  ON TABLE public.chat_rooms TO authenticated;
DROP POLICY IF EXISTS "Room creator or admin can update room" ON public.chat_rooms;
DROP POLICY IF EXISTS chat_rooms_update_member ON public.chat_rooms;
DROP POLICY IF EXISTS chat_rooms_update_admin ON public.chat_rooms;
CREATE POLICY chat_rooms_update_admin ON public.chat_rooms FOR UPDATE TO authenticated
USING (private.can_manage_group_participants(chat_rooms.id, auth.uid()))
WITH CHECK (private.can_manage_group_participants(chat_rooms.id, auth.uid()));

DROP POLICY IF EXISTS "Users can view participants of their rooms" ON public.chat_participants;
DROP POLICY IF EXISTS chat_participants_select_visible ON public.chat_participants;
CREATE POLICY chat_participants_select_visible ON public.chat_participants FOR SELECT TO authenticated
USING (
  private.is_room_member(chat_participants.room_id, auth.uid())
  AND NOT private.mutually_blocked_internal(auth.uid(), user_id)
);

DROP POLICY IF EXISTS "Authenticated users can insert participants" ON public.chat_participants;
DROP POLICY IF EXISTS chat_participants_insert_unblocked ON public.chat_participants;
CREATE POLICY chat_participants_insert_unblocked ON public.chat_participants FOR INSERT TO authenticated
WITH CHECK (
  private.can_manage_group_participants(room_id, auth.uid())
  AND NOT private.mutually_blocked_internal(auth.uid(), user_id)
);

DROP POLICY IF EXISTS "Users can update own participant record" ON public.chat_participants;
DROP POLICY IF EXISTS chat_participants_update_self_state ON public.chat_participants;
CREATE POLICY chat_participants_update_self_state ON public.chat_participants
FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_select_visible ON public.chat_messages;
CREATE POLICY chat_messages_select_visible ON public.chat_messages FOR SELECT TO authenticated
USING (
  private.is_room_member(chat_messages.room_id, auth.uid())
  AND NOT private.mutually_blocked_internal(auth.uid(), sender_id)
);

DROP POLICY IF EXISTS "Users can send messages to rooms they belong to" ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_insert_unblocked ON public.chat_messages;
CREATE POLICY chat_messages_insert_unblocked ON public.chat_messages FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND private.is_room_member(room_id, auth.uid())
  AND private.direct_chat_allowed_internal(room_id, auth.uid())
);

-- Preserve the legacy signatures while anchoring every viewer decision to auth.uid().
CREATE OR REPLACE FUNCTION public.get_recommended_posts(
  p_user_id uuid,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name varchar,
  author_photo text,
  pet_id uuid,
  pet_name varchar,
  pet_type varchar,
  pet_breed varchar,
  image_url text,
  emotion_analysis jsonb,
  caption text,
  hashtags text[],
  location text,
  location_lat double precision,
  location_lng double precision,
  likes_count integer,
  comments_count integer,
  created_at timestamptz,
  is_liked boolean,
  recommendation_score integer
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_user_breeds text[];
BEGIN
  IF v_actor IS NULL OR p_user_id <> v_actor THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;
  SELECT array_agg(DISTINCT breed) INTO v_user_breeds
  FROM public.pets
  WHERE user_id = v_actor AND breed IS NOT NULL;

  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name,
    u.photo_url AS author_photo,
    p.pet_id, pet.name AS pet_name, pet.type AS pet_type, pet.breed AS pet_breed,
    p.image_url, p.emotion_analysis, p.caption, p.hashtags,
    p.location, p.location_lat, p.location_lng,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS (
      SELECT 1 FROM public.likes l
      WHERE l.post_id = p.id AND l.user_id = v_actor
    ) AS is_liked,
    (
      CASE
        WHEN pet.breed IS NOT NULL AND pet.breed = ANY(v_user_breeds) THEN 40
        ELSE 0
      END
      + CASE WHEN (
        SELECT count(*) FROM public.posts p2
        WHERE p2.author_id = p.author_id
          AND p2.created_at >= now() - interval '7 days'
          AND p2.deleted_at IS NULL
      ) >= 3 THEN 20 ELSE 0 END
      + CASE WHEN EXISTS (
        SELECT 1
        FROM public.likes l
        JOIN public.posts p3 ON l.post_id = p3.id
        WHERE l.user_id = v_actor AND p3.author_id = p.author_id
      ) THEN 15 ELSE 0 END
      + CASE WHEN p.created_at >= now() - interval '3 days' THEN 10 ELSE 0 END
    )::integer AS recommendation_score
  FROM public.posts p
  LEFT JOIN public.users u ON p.author_id = u.id
  LEFT JOIN public.pets pet ON p.pet_id = pet.id
  WHERE p.deleted_at IS NULL
    AND p.is_private = false
    AND p.author_id <> v_actor
    AND private.user_is_active_internal(p.author_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.follows f
      WHERE f.follower_id = v_actor AND f.following_id = p.author_id
    )
    AND NOT private.mutually_blocked_internal(v_actor, p.author_id)
  ORDER BY recommendation_score DESC, p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 50))
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

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

CREATE OR REPLACE FUNCTION public.get_posts_by_hashtag(
  p_hashtag text,
  p_user_id uuid DEFAULT NULL,
  p_sort text DEFAULT 'popular',
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name varchar,
  author_photo text,
  pet_id uuid,
  image_url text,
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
  IF v_actor IS NULL OR (p_user_id IS NOT NULL AND p_user_id <> v_actor) THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;
  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name, u.photo_url AS author_photo,
    p.pet_id, p.image_url, p.caption, p.hashtags,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS (
      SELECT 1 FROM public.likes l
      WHERE l.post_id = p.id AND l.user_id = v_actor
    ) AS is_liked
  FROM public.posts p
  LEFT JOIN public.users u ON p.author_id = u.id
  WHERE p.deleted_at IS NULL
    AND p.is_private = false
    AND private.user_is_active_internal(p.author_id)
    AND p.hashtags && ARRAY[p_hashtag]
    AND NOT private.mutually_blocked_internal(v_actor, p.author_id)
  ORDER BY
    CASE WHEN p_sort = 'popular' THEN p.likes_count ELSE 0 END DESC,
    p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 50))
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_posts_by_location(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer DEFAULT 50,
  p_user_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name varchar,
  author_photo text,
  pet_id uuid,
  image_url text,
  caption text,
  location text,
  likes_count integer,
  comments_count integer,
  created_at timestamptz,
  is_liked boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_lat_delta double precision;
  v_lng_delta double precision;
BEGIN
  IF v_actor IS NULL OR (p_user_id IS NOT NULL AND p_user_id <> v_actor) THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;
  v_lat_delta := p_radius_m / 111000.0;
  v_lng_delta := p_radius_m / (111000.0 * cos(radians(p_lat)));
  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name, u.photo_url AS author_photo,
    p.pet_id, p.image_url, p.caption, p.location,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS (
      SELECT 1 FROM public.likes l
      WHERE l.post_id = p.id AND l.user_id = v_actor
    ) AS is_liked
  FROM public.posts p
  LEFT JOIN public.users u ON p.author_id = u.id
  WHERE p.deleted_at IS NULL
    AND p.is_private = false
    AND private.user_is_active_internal(p.author_id)
    AND p.location_lat IS NOT NULL
    AND p.location_lng IS NOT NULL
    AND p.location_lat BETWEEN (p_lat - v_lat_delta) AND (p_lat + v_lat_delta)
    AND p.location_lng BETWEEN (p_lng - v_lng_delta) AND (p_lng + v_lng_delta)
    AND NOT private.mutually_blocked_internal(v_actor, p.author_id)
  ORDER BY p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 50))
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

REVOKE ALL ON FUNCTION public.get_feed_posts(uuid,integer,integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_recommended_posts(uuid,integer,integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_posts_by_hashtag(text,uuid,text,integer,integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_posts_by_location(
  double precision,double precision,integer,uuid,integer,integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_feed_posts(uuid,integer,integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_recommended_posts(uuid,integer,integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_posts_by_hashtag(text,uuid,text,integer,integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_posts_by_location(
  double precision,double precision,integer,uuid,integer,integer
) TO authenticated;

COMMIT;
