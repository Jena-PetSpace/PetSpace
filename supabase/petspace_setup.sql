-- ================================================================
-- PetSpace (멍냥다이어리) Supabase 통합 설정 파일
-- 실행 위치: Supabase SQL Editor
-- 실행 순서: 위에서 아래로 순서대로 실행
--
-- 선행 조건 (Dashboard에서 먼저 처리):
--   1. Extensions → pg_net 활성화
--   2. Storage 버킷 생성: images (public)
--   3. Vault → FIREBASE_SERVICE_ACCOUNT_KEY 등록 (D-4)
--   4. Vault → FIREBASE_PROJECT_ID 등록 (D-4)
--   5. Edge Function send-push-notification 배포 (D-4)
-- ================================================================


-- ================================================================
-- SECTION 1: 핵심 테이블
-- ================================================================

-- ── users (프로필) ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.users (
  id                    uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name          text,
  avatar_url            text,
  bio                   text,
  provider              text,                        -- 'google' | 'kakao' | 'email'
  is_onboarding_completed boolean NOT NULL DEFAULT false,
  is_email_confirmed    boolean NOT NULL DEFAULT false,
  followers_count       integer NOT NULL DEFAULT 0,
  following_count       integer NOT NULL DEFAULT 0,
  posts_count           integer NOT NULL DEFAULT 0,
  points                integer NOT NULL DEFAULT 0,
  streak_days           integer NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users: 전체 조회 허용"
  ON public.users FOR SELECT USING (true);

CREATE POLICY "users: 본인 삽입"
  ON public.users FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users: 본인 수정"
  ON public.users FOR UPDATE USING (auth.uid() = id);


-- ── pets (반려동물) ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  type        text NOT NULL CHECK (type IN ('dog', 'cat')),
  breed       text,
  birth_date  date,
  gender      text CHECK (gender IN ('male', 'female')),
  avatar_url  text,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pets: 전체 조회 허용"
  ON public.pets FOR SELECT USING (true);

CREATE POLICY "pets: 본인 관리"
  ON public.pets FOR ALL USING (auth.uid() = user_id);


-- ── breeds (품종 데이터) ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.breeds (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  species          varchar(10) NOT NULL CHECK (species IN ('dog', 'cat')),
  name_ko          varchar(100) NOT NULL,
  name_en          varchar(100),
  description      text,
  origin_country   varchar(50),
  size             varchar(20) CHECK (size IN ('small', 'medium', 'large', 'extra_large')),
  temperament      text[],
  lifespan_min     integer,
  lifespan_max     integer,
  is_active        boolean NOT NULL DEFAULT true,
  display_order    integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_breed_per_species UNIQUE (species, name_ko)
);

ALTER TABLE public.breeds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "breeds: 전체 조회 허용"
  ON public.breeds FOR SELECT USING (true);

CREATE POLICY "breeds: 인증 사용자 삽입"
  ON public.breeds FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "breeds: 인증 사용자 수정"
  ON public.breeds FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "breeds: 인증 사용자 삭제"
  ON public.breeds FOR DELETE TO authenticated USING (true);


-- ── emotion_history (AI 감정 분석 이력) ─────────────────────────

CREATE TABLE IF NOT EXISTS public.emotion_history (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_id            uuid REFERENCES public.pets(id) ON DELETE SET NULL,
  pet_name          text,
  image_url         text NOT NULL,
  local_image_path  text NOT NULL DEFAULT '',
  -- 감정 점수 (0~1)
  happiness         float NOT NULL DEFAULT 0,
  calm              float NOT NULL DEFAULT 0,
  excitement        float NOT NULL DEFAULT 0,
  curiosity         float NOT NULL DEFAULT 0,
  anxiety           float NOT NULL DEFAULT 0,
  fear              float NOT NULL DEFAULT 0,
  sadness           float NOT NULL DEFAULT 0,
  discomfort        float NOT NULL DEFAULT 0,
  confidence        float NOT NULL DEFAULT 0,
  is_sleepy         boolean NOT NULL DEFAULT false,
  memo              text,
  tags              text[] NOT NULL DEFAULT '{}',
  analyzed_at       timestamptz NOT NULL DEFAULT now(),
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.emotion_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "emotion_history: 본인 관리"
  ON public.emotion_history FOR ALL USING (auth.uid() = user_id);


-- ── health_history (AI 건강 분석 이력) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.health_history (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_id          uuid REFERENCES public.pets(id) ON DELETE SET NULL,
  area            text NOT NULL,                   -- 'eye' | 'skin' | 'ear' | etc.
  overall_score   integer NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT '',
  image_urls      text[] NOT NULL DEFAULT '{}',
  findings        jsonb NOT NULL DEFAULT '[]',
  recommendations text[] NOT NULL DEFAULT '{}',
  analyzed_at     timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.health_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "health_history: 본인 관리"
  ON public.health_history FOR ALL USING (auth.uid() = user_id);


-- ── health_records (수동 건강 기록) ─────────────────────────────

CREATE TABLE IF NOT EXISTS public.health_records (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id      uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  type        text NOT NULL,                       -- 'vaccination' | 'checkup' | etc.
  title       text NOT NULL,
  description text,
  date        date NOT NULL,
  next_date   date,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.health_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "health_records: 반려동물 주인 관리"
  ON public.health_records FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = health_records.pet_id
        AND pets.user_id = auth.uid()
    )
  );


-- ================================================================
-- SECTION 2: 소셜 테이블
-- ================================================================

-- ── posts ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.posts (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type                  text NOT NULL DEFAULT 'image'
                          CHECK (type IN ('text', 'image', 'emotionAnalysis', 'video')),
  content               text,
  image_urls            text[] NOT NULL DEFAULT '{}',
  video_url             text,
  tags                  text[] NOT NULL DEFAULT '{}',
  location              text,
  location_lat          double precision,
  location_lng          double precision,
  likes_count           integer NOT NULL DEFAULT 0,
  comments_count        integer NOT NULL DEFAULT 0,
  shares_count          integer NOT NULL DEFAULT 0,
  is_public             boolean NOT NULL DEFAULT true,
  is_private            boolean NOT NULL DEFAULT false,
  emotion_analysis_id   uuid REFERENCES public.emotion_history(id) ON DELETE SET NULL,
  recommendation_score  integer,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts: 공개 게시물 전체 조회"
  ON public.posts FOR SELECT
  USING (is_public = true OR auth.uid() = author_id);

CREATE POLICY "posts: 본인 관리"
  ON public.posts FOR ALL USING (auth.uid() = author_id);


-- ── likes ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id    uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, post_id)
);

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "likes: 전체 조회"
  ON public.likes FOR SELECT USING (true);

CREATE POLICY "likes: 본인 관리"
  ON public.likes FOR ALL USING (auth.uid() = user_id);


-- ── comments ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id     uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  parent_id   uuid REFERENCES public.comments(id) ON DELETE CASCADE,  -- 대댓글
  content     text NOT NULL,
  likes_count integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments: 전체 조회"
  ON public.comments FOR SELECT USING (true);

CREATE POLICY "comments: 본인 관리"
  ON public.comments FOR ALL USING (auth.uid() = user_id);


-- ── comment_likes ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.comment_likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_id uuid NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, comment_id)
);

ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comment_likes: 전체 조회"
  ON public.comment_likes FOR SELECT USING (true);

CREATE POLICY "comment_likes: 본인 관리"
  ON public.comment_likes FOR ALL USING (auth.uid() = user_id);


-- ── follows ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.follows (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (follower_id, following_id)
);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "follows: 전체 조회"
  ON public.follows FOR SELECT USING (true);

CREATE POLICY "follows: 본인 관리"
  ON public.follows FOR ALL USING (auth.uid() = follower_id);


-- ── saved_posts (북마크) ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.saved_posts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id    uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, post_id)
);

ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_posts: 본인 관리"
  ON public.saved_posts FOR ALL USING (auth.uid() = user_id);


-- ── notifications ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  sender_name text,
  type        text NOT NULL,                       -- 'like' | 'comment' | 'follow' | 'mention' | 'emotionAnalysis'
  title       text NOT NULL,
  body        text NOT NULL,
  post_id     uuid REFERENCES public.posts(id) ON DELETE CASCADE,
  is_read     boolean NOT NULL DEFAULT false,
  data        jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications: 본인 알림 조회"
  ON public.notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications: 본인 알림 수정 (읽음 처리)"
  ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "notifications: 인증 사용자 삽입"
  ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);


-- ── notification_preferences ────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  likes_enabled   boolean NOT NULL DEFAULT true,
  comments_enabled boolean NOT NULL DEFAULT true,
  follows_enabled boolean NOT NULL DEFAULT true,
  push_enabled    boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences: 본인 관리"
  ON public.notification_preferences FOR ALL USING (auth.uid() = user_id);


-- ── reports (신고) ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('post', 'comment', 'user')),
  target_id   uuid NOT NULL,
  reason      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports: 본인 신고 삽입"
  ON public.reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "reports: 본인 신고 조회"
  ON public.reports FOR SELECT USING (auth.uid() = reporter_id);


-- ── user_blocks (차단) ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_blocks (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_blocks: 본인 관리"
  ON public.user_blocks FOR ALL USING (auth.uid() = blocker_id);


-- ── user_badges / user_points / point_transactions ──────────────

CREATE TABLE IF NOT EXISTS public.user_badges (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_type text NOT NULL,
  earned_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, badge_type)
);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_badges: 전체 조회"
  ON public.user_badges FOR SELECT USING (true);

CREATE POLICY "user_badges: 인증 사용자 삽입"
  ON public.user_badges FOR INSERT TO authenticated WITH CHECK (true);


CREATE TABLE IF NOT EXISTS public.user_points (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  total      integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_points: 본인 관리"
  ON public.user_points FOR ALL USING (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS public.point_transactions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount      integer NOT NULL,
  reason      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "point_transactions: 본인 조회"
  ON public.point_transactions FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "point_transactions: 인증 사용자 삽입"
  ON public.point_transactions FOR INSERT TO authenticated WITH CHECK (true);


-- ── bookmark_collections ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bookmark_collections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bookmark_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookmark_collections: 본인 관리"
  ON public.bookmark_collections FOR ALL USING (auth.uid() = user_id);


-- ================================================================
-- SECTION 3: 채팅 테이블
-- ================================================================

CREATE TABLE IF NOT EXISTS public.chat_rooms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type            text NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group')),
  name            text,
  avatar_url      text,
  last_message    text,
  last_message_at timestamptz,
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rooms: 참여자 조회"
  ON public.chat_rooms FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.room_id = chat_rooms.id
        AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_rooms: 인증 사용자 생성"
  ON public.chat_rooms FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "chat_rooms: 참여자 수정"
  ON public.chat_rooms FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.room_id = chat_rooms.id
        AND chat_participants.user_id = auth.uid()
    )
  );


CREATE TABLE IF NOT EXISTS public.chat_participants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id     uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_read_at timestamptz,
  joined_at   timestamptz NOT NULL DEFAULT now(),
  left_at     timestamptz,
  UNIQUE (room_id, user_id)
);

ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_participants: 참여자 조회"
  ON public.chat_participants FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.room_id = chat_participants.room_id
        AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_participants: 인증 사용자 삽입"
  ON public.chat_participants FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "chat_participants: 본인 수정"
  ON public.chat_participants FOR UPDATE USING (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS public.chat_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id     uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        text NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'system')),
  content     text,
  image_url   text,
  is_deleted  boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_messages: 참여자 조회"
  ON public.chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.room_id = chat_messages.room_id
        AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_messages: 참여자 삽입"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.room_id = chat_messages.room_id
        AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_messages: 본인 수정"
  ON public.chat_messages FOR UPDATE USING (auth.uid() = sender_id);


-- ================================================================
-- SECTION 4: FCM 기기 관리 (D-4)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_devices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token   text NOT NULL,
  platform    text NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'other')),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fcm_token)
);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_devices: 본인 기기 조회"
  ON public.user_devices FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기 삽입"
  ON public.user_devices FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기 수정"
  ON public.user_devices FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기 삭제"
  ON public.user_devices FOR DELETE USING (auth.uid() = user_id);


-- ================================================================
-- SECTION 5: 인덱스
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_pets_user_id              ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_breeds_species            ON public.breeds(species);
CREATE INDEX IF NOT EXISTS idx_breeds_name_ko            ON public.breeds(name_ko);
CREATE INDEX IF NOT EXISTS idx_breeds_is_active          ON public.breeds(is_active);
CREATE INDEX IF NOT EXISTS idx_breeds_display_order      ON public.breeds(display_order);
CREATE INDEX IF NOT EXISTS idx_emotion_history_user_id   ON public.emotion_history(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_pet_id    ON public.emotion_history(pet_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_analyzed  ON public.emotion_history(analyzed_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_history_user_id    ON public.health_history(user_id);
CREATE INDEX IF NOT EXISTS idx_health_records_pet_id     ON public.health_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_author_id           ON public.posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at          ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_is_public           ON public.posts(is_public);
CREATE INDEX IF NOT EXISTS idx_posts_tags                ON public.posts USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_likes_post_id             ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_post           ON public.likes(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id          ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id        ON public.comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower          ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following         ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id     ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at  ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read     ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id     ON public.chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at  ON public.chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id      ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_is_active    ON public.user_devices(is_active);
CREATE INDEX IF NOT EXISTS idx_saved_posts_user_id       ON public.saved_posts(user_id);


-- ================================================================
-- SECTION 6: 트리거 함수 & 트리거
-- ================================================================

-- ── 신규 사용자 프로필 자동 생성 ────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, provider)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'provider', 'email')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── 좋아요 카운터 (SECURITY DEFINER — RLS 우회) ─────────────────

CREATE OR REPLACE FUNCTION public.update_post_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
EXCEPTION WHEN others THEN
  RAISE WARNING 'update_post_likes_count 오류: %', SQLERRM;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_post_likes_count ON public.likes;
CREATE TRIGGER trg_post_likes_count
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.update_post_likes_count();


-- ── 댓글 카운터 (SECURITY DEFINER — RLS 우회) ───────────────────

CREATE OR REPLACE FUNCTION public.update_post_comments_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_id IS NULL THEN
    UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_id IS NULL THEN
    UPDATE public.posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN others THEN
  RAISE WARNING 'update_post_comments_count 오류: %', SQLERRM;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_post_comments_count ON public.comments;
CREATE TRIGGER trg_post_comments_count
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.update_post_comments_count();


-- ── breeds updated_at 자동 갱신 ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_breeds_updated_at ON public.breeds;
CREATE TRIGGER trg_breeds_updated_at
  BEFORE UPDATE ON public.breeds
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


-- ── FCM 푸시 알림 트리거 (D-4) ──────────────────────────────────
-- notifications INSERT 시 Edge Function send-push-notification 비동기 호출
-- 선행 조건: pg_net 활성화 + ALTER DATABASE 설정 완료

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _supabase_url  text;
  _service_key   text;
  _payload       jsonb;
  _data          jsonb;
BEGIN
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_key  := current_setting('app.settings.service_role_key', true);

  _data := jsonb_build_object('type', NEW.type);
  IF NEW.post_id IS NOT NULL THEN
    _data := _data || jsonb_build_object('post_id', NEW.post_id::text);
  END IF;
  IF NEW.sender_id IS NOT NULL THEN
    _data := _data || jsonb_build_object('sender_id', NEW.sender_id::text);
  END IF;

  _payload := jsonb_build_object(
    'user_id', NEW.user_id::text,
    'title',   NEW.title,
    'body',    NEW.body,
    'data',    _data
  );

  PERFORM net.http_post(
    url     := _supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _service_key
    ),
    body    := _payload
  );

  RETURN NEW;
EXCEPTION WHEN others THEN
  RAISE WARNING 'notify_push_on_notification 오류: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_on_notification();


-- ================================================================
-- SECTION 7: RPC 함수
-- ================================================================

-- ── 카카오 로그인 이메일 자동 인증 ──────────────────────────────

CREATE OR REPLACE FUNCTION public.confirm_kakao_user_by_email(p_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      updated_at = now()
  WHERE email = p_email
    AND email_confirmed_at IS NULL;
END;
$$;


-- ── 계정 삭제 ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;


-- ── 좋아요 RPC (낙관적 업데이트 보조) ───────────────────────────

CREATE OR REPLACE FUNCTION public.increment_post_likes(post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_likes(post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = post_id;
END;
$$;


-- ── 포인트 적립 ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_user_points(p_user_id uuid, p_amount integer, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_points (user_id, total)
  VALUES (p_user_id, p_amount)
  ON CONFLICT (user_id)
  DO UPDATE SET total = user_points.total + p_amount, updated_at = now();

  INSERT INTO public.point_transactions (user_id, amount, reason)
  VALUES (p_user_id, p_amount, p_reason);
END;
$$;


-- ── 스트릭 조회 ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_streak(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _streak integer := 0;
  _check_date date := CURRENT_DATE;
  _has_activity boolean;
BEGIN
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM public.emotion_history
      WHERE user_id = p_user_id
        AND analyzed_at::date = _check_date
    ) INTO _has_activity;

    EXIT WHEN NOT _has_activity;
    _streak := _streak + 1;
    _check_date := _check_date - 1;
  END LOOP;
  RETURN _streak;
END;
$$;


-- ── 채팅 읽지 않은 메시지 수 ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_room_unread_count(p_room_id uuid, p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _last_read timestamptz;
  _count     integer;
BEGIN
  SELECT last_read_at INTO _last_read
  FROM public.chat_participants
  WHERE room_id = p_room_id AND user_id = p_user_id;

  SELECT COUNT(*) INTO _count
  FROM public.chat_messages
  WHERE room_id = p_room_id
    AND sender_id != p_user_id
    AND (_last_read IS NULL OR created_at > _last_read);

  RETURN COALESCE(_count, 0);
END;
$$;


CREATE OR REPLACE FUNCTION public.get_total_unread_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _total integer := 0;
  _room  record;
BEGIN
  FOR _room IN
    SELECT room_id FROM public.chat_participants WHERE user_id = p_user_id
  LOOP
    _total := _total + public.get_room_unread_count(_room.room_id, p_user_id);
  END LOOP;
  RETURN _total;
END;
$$;


-- ── 1:1 채팅방 찾기 ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.find_direct_chat(p_user1_id uuid, p_user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _room_id uuid;
BEGIN
  SELECT cp1.room_id INTO _room_id
  FROM public.chat_participants cp1
  JOIN public.chat_participants cp2 ON cp1.room_id = cp2.room_id
  JOIN public.chat_rooms cr ON cr.id = cp1.room_id
  WHERE cp1.user_id = p_user1_id
    AND cp2.user_id = p_user2_id
    AND cr.type = 'direct'
  LIMIT 1;

  RETURN _room_id;
END;
$$;


-- ── 인기 해시태그 ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_popular_hashtags(p_limit integer DEFAULT 20)
RETURNS TABLE (tag text, count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT unnest(tags) AS tag, COUNT(*) AS count
  FROM public.posts
  WHERE is_public = true
    AND created_at > now() - INTERVAL '7 days'
  GROUP BY tag
  ORDER BY count DESC
  LIMIT p_limit;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_trending_hashtags(p_limit integer DEFAULT 10)
RETURNS TABLE (tag text, count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT unnest(tags) AS tag, COUNT(*) AS count
  FROM public.posts
  WHERE is_public = true
    AND created_at > now() - INTERVAL '24 hours'
  GROUP BY tag
  ORDER BY count DESC
  LIMIT p_limit;
END;
$$;


-- ── 추천 게시물 ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_recommended_posts(
  p_user_id uuid,
  p_limit   integer DEFAULT 20,
  p_offset  integer DEFAULT 0
)
RETURNS SETOF public.posts
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT p.*
  FROM public.posts p
  WHERE p.is_public = true
    AND p.author_id != p_user_id
    AND p.author_id NOT IN (
      SELECT blocked_id FROM public.user_blocks WHERE blocker_id = p_user_id
    )
  ORDER BY (p.likes_count * 2 + p.comments_count) DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


-- ── 해시태그/위치 검색 ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_posts_by_hashtag(
  p_hashtag text,
  p_limit   integer DEFAULT 20,
  p_offset  integer DEFAULT 0
)
RETURNS SETOF public.posts
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.posts
  WHERE is_public = true AND p_hashtag = ANY(tags)
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_posts_by_location(
  p_lat     double precision,
  p_lng     double precision,
  p_radius  double precision DEFAULT 10.0,
  p_limit   integer DEFAULT 20
)
RETURNS SETOF public.posts
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.posts
  WHERE is_public = true
    AND location_lat IS NOT NULL
    AND location_lng IS NOT NULL
    AND (
      6371 * acos(
        cos(radians(p_lat)) * cos(radians(location_lat))
        * cos(radians(location_lng) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(location_lat))
      )
    ) <= p_radius
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;


-- ── 품종 검색 ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.search_breeds(
  p_species varchar(10),
  p_query   text,
  p_limit   integer DEFAULT 20
)
RETURNS TABLE (
  id           uuid,
  species      varchar(10),
  name_ko      varchar(100),
  name_en      varchar(100),
  description  text,
  size         varchar(20)
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT b.id, b.species, b.name_ko, b.name_en, b.description, b.size
  FROM public.breeds b
  WHERE b.species = p_species
    AND b.is_active = true
    AND (b.name_ko ILIKE '%' || p_query || '%' OR b.name_en ILIKE '%' || p_query || '%')
  ORDER BY b.display_order ASC, b.name_ko ASC
  LIMIT p_limit;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_all_breeds(p_species varchar(10) DEFAULT NULL)
RETURNS TABLE (
  id            uuid,
  species       varchar(10),
  name_ko       varchar(100),
  name_en       varchar(100),
  description   text,
  size          varchar(20),
  display_order integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT b.id, b.species, b.name_ko, b.name_en, b.description, b.size, b.display_order
  FROM public.breeds b
  WHERE b.is_active = true
    AND (p_species IS NULL OR b.species = p_species)
  ORDER BY b.species ASC, b.display_order ASC, b.name_ko ASC;
END;
$$;


-- ── 차단 사용자 목록 조회 ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_blocked_users(p_user_id uuid)
RETURNS TABLE (blocked_id uuid)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT ub.blocked_id FROM public.user_blocks ub WHERE ub.blocker_id = p_user_id;
END;
$$;


-- ================================================================
-- SECTION 8: 초기 데이터
-- ================================================================

-- 강아지 품종
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order)
VALUES
  ('dog', '말티즈',         'Maltese',            'small',  '작고 귀여운 장모종 강아지',          1),
  ('dog', '푸들',           'Poodle',             'small',  '영리하고 사교적인 견종',             2),
  ('dog', '치와와',         'Chihuahua',          'small',  '세계에서 가장 작은 견종',            3),
  ('dog', '포메라니안',     'Pomeranian',         'small',  '폭신한 털을 가진 활발한 강아지',      4),
  ('dog', '시바견',         'Shiba Inu',          'medium', '일본 원산의 독립적인 성격의 견종',    5),
  ('dog', '비글',           'Beagle',             'medium', '사냥개 출신의 호기심 많은 견종',      6),
  ('dog', '웰시코기',       'Welsh Corgi',        'medium', '짧은 다리와 긴 몸통이 특징',         7),
  ('dog', '골든 리트리버',  'Golden Retriever',   'large',  '온순하고 충성스러운 대형견',          8),
  ('dog', '래브라도 리트리버','Labrador Retriever','large', '가장 인기있는 가족견',               9),
  ('dog', '진돗개',         'Jindo',              'medium', '한국 토종견으로 충성심이 강함',       10),
  ('dog', '요크셔테리어',   'Yorkshire Terrier',  'small',  '작지만 용감한 테리어 품종',          11),
  ('dog', '시츄',           'Shih Tzu',           'small',  '중국 원산의 애완견',                12),
  ('dog', '닥스훈트',       'Dachshund',          'small',  '긴 몸과 짧은 다리가 특징',          13),
  ('dog', '불독',           'Bulldog',            'medium', '주름진 얼굴과 근육질 체형',          14),
  ('dog', '보더콜리',       'Border Collie',      'medium', '가장 영리한 견종 중 하나',           15)
ON CONFLICT (species, name_ko) DO NOTHING;

-- 고양이 품종
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order)
VALUES
  ('cat', '코리안 숏헤어', 'Korean Shorthair',  'medium', '한국 토종 고양이',               1),
  ('cat', '페르시안',      'Persian',           'medium', '긴 털과 납작한 얼굴이 특징',      2),
  ('cat', '러시안 블루',   'Russian Blue',      'medium', '은색 푸른 털을 가진 고양이',      3),
  ('cat', '샴',           'Siamese',            'medium', '독특한 무늬와 파란 눈이 특징',    4),
  ('cat', '스코티시 폴드', 'Scottish Fold',     'medium', '접힌 귀가 특징인 고양이',         5),
  ('cat', '먼치킨',        'Munchkin',          'small',  '짧은 다리가 특징인 고양이',       6),
  ('cat', '아메리칸 숏헤어','American Shorthair','medium', '튼튼하고 건강한 품종',           7),
  ('cat', '메인쿤',        'Maine Coon',        'large',  '가장 큰 고양이 품종 중 하나',     8),
  ('cat', '브리티시 숏헤어','British Shorthair', 'medium', '둥근 얼굴과 두꺼운 털',          9),
  ('cat', '뱅갈',          'Bengal',            'medium', '야생 표범 무늬를 가진 고양이',    10),
  ('cat', '노르웨이 숲',   'Norwegian Forest',  'large',  '긴 털을 가진 북유럽 원산 고양이', 11),
  ('cat', '랙돌',          'Ragdoll',           'large',  '안으면 인형처럼 축 늘어지는 성격',12),
  ('cat', '아비시니안',    'Abyssinian',        'medium', '날씬하고 우아한 체형',            13),
  ('cat', '터키시 앙고라', 'Turkish Angora',    'medium', '우아하고 긴 털을 가진 고양이',    14),
  ('cat', '스핑크스',      'Sphynx',            'medium', '털이 없는 독특한 품종',           15)
ON CONFLICT (species, name_ko) DO NOTHING;


-- ================================================================
-- SECTION 9: D-4 사후 설정 (Supabase 인프라 준비 후 실행)
-- ================================================================

-- 아래 두 줄은 pg_net 트리거 활성화 전 반드시 실행
-- (YOUR_PROJECT_REF / YOUR_SERVICE_ROLE_KEY 를 실제 값으로 교체)

-- ALTER DATABASE postgres
--   SET "app.settings.supabase_url" = 'https://YOUR_PROJECT_REF.supabase.co';

-- ALTER DATABASE postgres
--   SET "app.settings.service_role_key" = 'YOUR_SERVICE_ROLE_KEY';


-- ================================================================
-- SECTION 10: 실행 확인 쿼리
-- ================================================================

-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
-- SELECT tgname, tgenabled FROM pg_trigger WHERE tgname LIKE 'trg_%';
-- SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace ORDER BY proname;
-- SELECT * FROM user_devices LIMIT 5;

COMMENT ON TABLE public.users             IS 'PetSpace 사용자 프로필';
COMMENT ON TABLE public.pets              IS '반려동물 정보';
COMMENT ON TABLE public.breeds            IS '반려동물 품종 정보 (강아지/고양이)';
COMMENT ON TABLE public.emotion_history   IS 'AI 감정 분석 이력';
COMMENT ON TABLE public.health_history    IS 'AI 건강 분석 이력';
COMMENT ON TABLE public.health_records    IS '수동 건강 기록 (접종/검진 등)';
COMMENT ON TABLE public.posts             IS '소셜 게시물';
COMMENT ON TABLE public.likes             IS '게시물 좋아요';
COMMENT ON TABLE public.comments          IS '게시물 댓글 (대댓글 포함)';
COMMENT ON TABLE public.follows           IS '팔로우 관계';
COMMENT ON TABLE public.notifications     IS '인앱 알림';
COMMENT ON TABLE public.user_devices      IS 'FCM 기기 토큰 (D-4 푸시 알림)';
COMMENT ON TABLE public.chat_rooms        IS '채팅방';
COMMENT ON TABLE public.chat_participants IS '채팅방 참여자';
COMMENT ON TABLE public.chat_messages     IS '채팅 메시지';


-- ================================================================
-- SECTION 11: 관리자 초기 게시글 Seed Data
-- ================================================================
-- 관리자 계정은 auth.users에 먼저 생성되어 있어야 함
-- (Supabase Dashboard > Authentication > Users에서 수동 생성 후 아래 UUID 사용)
-- 또는 아래 주석을 참고하여 이메일 로그인으로 가입 후 UUID를 교체

-- ── 관리자 프로필 ────────────────────────────────────────────────
-- 주의: auth.users에 해당 UUID가 없으면 FK 제약으로 실패함
-- 실제 관리자 계정 생성 후 UUID를 교체하거나, 가입한 계정 UUID를 아래에 입력

/*
-- 관리자 프로필 삽입 (auth.users에 먼저 계정 생성 필요)
INSERT INTO public.users (id, display_name, provider, is_onboarding_completed, is_email_confirmed)
VALUES (
    '00000000-0000-0000-0000-000000000001',  -- 실제 관리자 auth.users UUID로 교체
    '관리자',
    'email',
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET display_name = '관리자';

-- ── 매거진 게시글 ─────────────────────────────────────────────
INSERT INTO public.posts (author_id, type, content, image_urls, tags, likes_count, comments_count)
VALUES
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '반려동물 치아 관리 필수 가이드

우리 아이의 구강 건강, 어떻게 관리하고 계신가요?

1. 매일 양치질: 반려동물 전용 칫솔과 치약을 사용하세요
2. 치석 제거: 6개월~1년 주기로 스케일링 권장
3. 간식 활용: 덴탈껌, 치석 제거 간식 활용
4. 이상 신호: 구취, 침흘림, 잇몸 출혈 시 즉시 병원 방문

치아 건강은 전신 건강과 직결됩니다!',
    '{}', ARRAY['magazine', 'health'], 0, 0
),
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '기본 복종 훈련 시작하기

반려견과의 소통, 기본 훈련부터 시작하세요!

1. 앉아 (Sit): 간식을 코 위로 올려 자연스럽게 앉게 유도
2. 기다려 (Stay): 앉은 상태에서 손바닥을 보여주며 기다려 명령
3. 이리와 (Come): 긴 줄을 이용해 부르면 오는 연습
4. 엎드려 (Down): 간식을 바닥으로 천천히 내려 유도

하루 10분씩 꾸준히 연습하면 2주 안에 효과를 볼 수 있어요!',
    '{}', ARRAY['magazine', 'training'], 0, 0
),
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '수제 간식 레시피 TOP 5

우리 아이를 위한 건강한 수제 간식을 만들어보세요!

1. 고구마칩: 얇게 썰어 오븐 120도에서 2시간 건조
2. 닭가슴살 져키: 얇게 저며 식품건조기에서 6시간
3. 당근 쿠키: 당근 퓨레 + 쌀가루 + 계란 → 170도 15분
4. 바나나 요거트 아이스: 바나나 + 무당 요거트 → 냉동
5. 연어 비스킷: 연어캔 + 귀리가루 + 계란 → 180도 20분

첨가물 걱정 없는 건강 간식이에요!',
    '{}', ARRAY['magazine', 'food'], 0, 0
),
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '여름철 산책 시 주의사항

더운 날씨에 안전한 산책을 위한 팁!

1. 시간: 오전 7시 전, 오후 6시 이후 산책
2. 아스팔트 온도: 손등으로 5초 대보고 뜨거우면 산책 금지
3. 수분 보충: 접이식 물그릇 꼭 챙기기
4. 열사병 증상: 헐떡임, 침흘림, 비틀거림 → 즉시 그늘로 이동
5. 발바닥 보호: 핫팟 보호용 왁스 또는 신발 착용

우리 아이의 여름 건강, 함께 지켜요!',
    '{}', ARRAY['magazine', 'life'], 0, 0
),

-- ── 건강 카테고리 게시글 ─────────────────────────────────────
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '겨울철 반려동물 건강 체크리스트

추운 겨울, 우리 아이 건강 관리 어떻게 하세요?

✅ 실내 온도 20-24도 유지
✅ 산책 후 발바닥 세척 (제설제 주의)
✅ 피부 건조 방지: 가습기 + 보습제
✅ 체중 관리: 겨울엔 활동량 감소로 체중 증가 주의
✅ 관절 건강: 노령견은 특히 관절 보온에 신경

건강한 겨울나기 함께해요!',
    '{}', ARRAY['health'], 0, 0
),
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '예방접종 가이드: 시기와 종류

반려동물 예방접종, 정확한 시기를 알고 계신가요?

🐶 강아지:
- 6~8주: DHPPL 1차
- 10~12주: DHPPL 2차 + 코로나
- 14~16주: DHPPL 3차 + 광견병
- 매년: 추가 접종

🐱 고양이:
- 6~8주: FVRCP 1차
- 10~12주: FVRCP 2차
- 14~16주: FVRCP 3차 + 광견병
- 매년: 추가 접종

접종 시기를 놓치지 마세요!',
    '{}', ARRAY['health'], 0, 0
),

-- ── 훈련 카테고리 게시글 ─────────────────────────────────────
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '산책 매너 교육 방법

산책 시 당기는 습관, 이렇게 고쳐보세요!

1. 리드줄 길이: 1.2~1.5m 적정 (너무 길면 통제 어려움)
2. 방향 전환법: 당기면 반대 방향으로 전환
3. 멈춤 훈련: 당기는 순간 멈추고, 줄이 느슨해지면 다시 걷기
4. 보상: 옆에서 걸을 때마다 간식으로 보상
5. 일관성: 매 산책 시 같은 규칙 적용

2~3주면 눈에 띄게 달라져요!',
    '{}', ARRAY['training'], 0, 0
),
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '분리불안 극복 훈련 팁

외출 시 우리 아이가 짖거나 물건을 망가뜨리나요?

1단계: 잠깐 외출 연습 (30초 → 1분 → 5분 점진적 증가)
2단계: 외출 전 과도한 인사 금지 (담담하게)
3단계: 귀가 시에도 흥분하지 않게 (5분 후 인사)
4단계: 콩(Kong) 장난감에 간식 넣어주기
5단계: 안전한 공간(크레이트) 만들어주기

심한 경우 수의사 상담을 권장합니다.',
    '{}', ARRAY['training'], 0, 0
),

-- ── Q&A 게시글 ───────────────────────────────────────────────
(
    '00000000-0000-0000-0000-000000000001',
    'text',
    '강아지 눈물자국 관리법

눈물자국으로 고민이신 분들 참고하세요!

원인: 눈물관 막힘, 알레르기, 사료 성분 등
관리법:
- 하루 2~3회 따뜻한 물로 닦아주기
- 눈물자국 전용 클리너 사용
- 사료 변경 시도 (곡물 프리)
- 심할 경우 안과 진료

꾸준한 관리가 중요해요!',
    '{}', ARRAY['qa', 'health'], 0, 0
);
*/

-- 위 seed 데이터는 관리자 계정 생성 후 주석을 해제하고 실행하세요.
-- UUID '00000000-0000-0000-0000-000000000001'을 실제 관리자 auth.users.id로 교체 필요.
