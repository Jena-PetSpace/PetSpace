-- ================================================================
-- PetSpace 전체 데이터베이스 설정 (통합 SQL)
-- 최종 수정: 2026-04-22 (M-F3: 추천 알고리즘, 북마크 컬렉션, 해시태그/위치 RPC)
-- 포함: 테이블 18개 (+bookmark_collections), 인덱스, RLS, 트리거, 함수, 스토리지,
--       Realtime, 채팅, Soft Delete, search_path 보안 수정
-- M-F2 변경: comments.parent_id, posts.location_lat/lng,
--            comment_likes 트리거, 기존 RPC 0-op 전환
-- M-F3 변경: bookmark_collections 테이블, saved_posts.collection_id,
--            get_recommended_posts RPC (rule-based 추천),
--            get_posts_by_hashtag RPC, get_posts_by_location RPC
-- ================================================================
--
-- 이 파일 하나만 Supabase SQL Editor에서 실행하면
-- 모든 테이블, 인덱스, RLS, 트리거, 함수, 스토리지가 설정됩니다.
--
-- 실행 방법:
--   1. Supabase Dashboard → SQL Editor
--   2. New query
--   3. 이 파일 내용 전체 복사 & 붙여넣기
--   4. Run 버튼 클릭
--
-- ================================================================


-- ================================================================
-- PART 1: Extensions
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ================================================================
-- PART 2: Tables (17개)
-- ================================================================

-- 1. Users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR UNIQUE NOT NULL,
    display_name VARCHAR(50),
    username VARCHAR(30) UNIQUE,
    photo_url TEXT,
    bio TEXT,
    provider VARCHAR(20) DEFAULT 'email',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settings JSONB DEFAULT '{}'::jsonb,
    is_onboarding_completed BOOLEAN DEFAULT FALSE,
    pets UUID[] DEFAULT ARRAY[]::UUID[],
    following UUID[] DEFAULT ARRAY[]::UUID[],
    followers UUID[] DEFAULT ARRAY[]::UUID[],
    selected_pet_id UUID,
    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    -- 약관 동의 기록 (세션4 I1) — 동의 시점·버전 보존(동의 증명)
    terms_agreed_at      TIMESTAMP WITH TIME ZONE,
    privacy_agreed_at    TIMESTAMP WITH TIME ZONE,
    location_agreed_at   TIMESTAMP WITH TIME ZONE,
    marketing_agreed_at  TIMESTAMP WITH TIME ZONE,
    terms_version        VARCHAR(20),
    privacy_version      VARCHAR(20),
    location_version     VARCHAR(20),
    marketing_version    VARCHAR(20)
);

-- 2. Pets
CREATE TABLE IF NOT EXISTS pets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    type VARCHAR(10) CHECK (type IN ('dog', 'cat')),
    breed VARCHAR(50),
    birth_date DATE,
    gender VARCHAR(10),
    avatar_url TEXT,
    description TEXT,
    -- 펫 여권(F2_pet_passport) 컬럼. 모두 nullable → 기존 행/미입력 안전.
    passport_no TEXT,                  -- 여권번호(등록 시 1회 생성, P 시작)
    passport_surname TEXT,             -- 영문 성(수동 입력)
    passport_given_name TEXT,          -- 영문 이름(수동 입력)
    name_hanguel TEXT,                 -- 한글성명(수동 입력, name 과 별개)
    country_code TEXT DEFAULT 'KOR',   -- 국가코드(ISO 3166-1 alpha-3)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- M1 representative pet contract. The column is added separately so rerunning
-- this setup also upgrades an existing users table created before M1.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS selected_pet_id uuid;

DO $m1_constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_selected_pet_id_fkey'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_selected_pet_id_fkey
      FOREIGN KEY (selected_pet_id)
      REFERENCES public.pets(id)
      ON DELETE SET NULL;
  END IF;
END;
$m1_constraint$;

-- 3. Posts (soft delete 포함)
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID REFERENCES pets(id) ON DELETE SET NULL, -- 반려동물 삭제 시 포스트 유지
    image_url TEXT,          -- NULL 허용: 감정 분석 공유 시 이미지 없을 수 있음
    emotion_analysis JSONB,  -- NULL 허용: 일반 커뮤니티 포스트 지원
    caption TEXT,
    hashtags TEXT[],
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- 4. Emotion History
CREATE TABLE IF NOT EXISTS emotion_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    emotion_analysis JSONB NOT NULL,
    memo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Comments (soft delete 포함, 대댓글 1 depth 지원)
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE, -- 대댓글 (NULL = 최상위)
    content TEXT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- 6. Follows
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id)
);

-- 7. Likes
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- 8. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    event_key TEXT
);

-- 9. User Devices (FCM)
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- 10. Comment Likes
CREATE TABLE IF NOT EXISTS comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(comment_id, user_id)
);

-- 11. Reports
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reported_post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    reported_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    -- reported_message_id FK 는 chat_messages 정의 이후 ALTER TABLE 로 추가(아래 참조)
    reported_message_id UUID,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    admin_notes TEXT,
    CONSTRAINT reports_target_check CHECK (
        reported_user_id IS NOT NULL OR
        reported_post_id IS NOT NULL OR
        reported_comment_id IS NOT NULL OR
        reported_message_id IS NOT NULL
    )
);

-- 12. User Blocks
CREATE TABLE IF NOT EXISTS user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

-- 13. Health Records
CREATE TABLE IF NOT EXISTS health_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    record_type VARCHAR(20) NOT NULL CHECK (record_type IN ('vaccination', 'checkup', 'weight', 'medication', 'surgery')),
    title VARCHAR(100) NOT NULL,
    description TEXT,
    record_date DATE NOT NULL,
    next_date DATE,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'overdue', 'cancelled')),
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. Saved Posts (북마크)
CREATE TABLE IF NOT EXISTS saved_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- 14-B. Bookmark Collections (M-F3: 북마크 컬렉션)
CREATE TABLE IF NOT EXISTS bookmark_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    emoji TEXT DEFAULT '📁',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- saved_posts에 collection_id 추가 (M-F3)
ALTER TABLE saved_posts
  ADD COLUMN IF NOT EXISTS collection_id UUID
  REFERENCES bookmark_collections(id) ON DELETE SET NULL;

-- 15. Chat Rooms
CREATE TABLE IF NOT EXISTS chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(10) NOT NULL CHECK (type IN ('direct', 'group')),
    name VARCHAR(100),
    description TEXT,
    avatar_url TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    last_message_sender_id UUID REFERENCES users(id) ON DELETE SET NULL
);

-- 16. Chat Participants
CREATE TABLE IF NOT EXISTS chat_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(10) DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(room_id, user_id)
);

-- 17. Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT,
    type VARCHAR(10) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'system')),
    image_url TEXT,
    image_urls TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

-- chat_messages에 image_urls 컬럼 추가 (기존 테이블 대비)
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS image_urls TEXT[];

-- reports.reported_message_id FK 추가 (chat_messages 정의 이후 — 채팅 메시지 신고용)
-- reports 테이블이 chat_messages보다 먼저 생성되므로 FK는 여기서 ALTER로 연결한다.
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reported_message_id UUID;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'reports_reported_message_id_fkey'
      AND table_name = 'reports'
  ) THEN
    ALTER TABLE reports
      ADD CONSTRAINT reports_reported_message_id_fkey
      FOREIGN KEY (reported_message_id) REFERENCES chat_messages(id) ON DELETE CASCADE;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_reports_reported_message_id ON reports(reported_message_id);

-- Users 테이블 컬럼 보강 (기존 테이블 대비)
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pets UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS following UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS followers UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS provider VARCHAR(20) DEFAULT 'email';

-- Soft delete 컬럼 보강 (기존 테이블 대비)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION; -- M-F2: 카카오 로컬 검색 좌표
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION; -- M-F2: 카카오 로컬 검색 좌표
ALTER TABLE comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES comments(id) ON DELETE CASCADE; -- M-F2: 대댓글 1 depth

-- image_url, emotion_analysis NOT NULL 제약 제거 (텍스트/이미지/감정분석 각각 선택적)
ALTER TABLE posts ALTER COLUMN image_url DROP NOT NULL;
ALTER TABLE posts ALTER COLUMN emotion_analysis DROP NOT NULL;

COMMENT ON COLUMN users.provider IS '가입 방식 (email, google, kakao)';
COMMENT ON COLUMN users.is_onboarding_completed IS '온보딩 프로세스 완료 여부';
COMMENT ON COLUMN users.pets IS '사용자가 소유한 반려동물 UUID 배열';
COMMENT ON COLUMN users.following IS '사용자가 팔로우하는 사용자 UUID 배열';
COMMENT ON COLUMN users.followers IS '사용자를 팔로우하는 사용자 UUID 배열';


-- ================================================================
-- PART 3: Indexes
-- ================================================================

-- Pets
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON pets(user_id);
-- 여권번호 UNIQUE (부분 인덱스: null 제외 → 미발급 행 다수 허용)
CREATE UNIQUE INDEX IF NOT EXISTS uq_pets_passport_no
  ON pets (passport_no) WHERE passport_no IS NOT NULL;

-- Posts
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_pet_id ON posts(pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_emotion_analysis ON posts USING GIN(emotion_analysis);
CREATE INDEX IF NOT EXISTS idx_posts_hashtags ON posts USING GIN(hashtags);
CREATE INDEX IF NOT EXISTS idx_posts_deleted_at ON posts(deleted_at) WHERE deleted_at IS NULL;

-- Emotion History
CREATE INDEX IF NOT EXISTS idx_emotion_history_user_id ON emotion_history(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_pet_id ON emotion_history(pet_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_created_at ON emotion_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emotion_history_emotion_analysis ON emotion_history USING GIN(emotion_analysis);
CREATE INDEX IF NOT EXISTS idx_emotion_history_user_created_at ON emotion_history(user_id, created_at DESC);

-- 감정 통계 뷰 (SECURITY INVOKER: RLS 우회 방지)
DROP VIEW IF EXISTS public.emotion_stats;
CREATE VIEW public.emotion_stats
  WITH (security_invoker = true)
AS
SELECT user_id,
    pet_id,
    date_trunc('day'::text, created_at) AS day,
    avg((emotion_analysis ->> 'happiness'::text)::numeric) AS avg_happiness,
    avg((emotion_analysis ->> 'calm'::text)::numeric) AS avg_calm,
    avg((emotion_analysis ->> 'excitement'::text)::numeric) AS avg_excitement,
    avg((emotion_analysis ->> 'curiosity'::text)::numeric) AS avg_curiosity,
    avg((emotion_analysis ->> 'anxiety'::text)::numeric) AS avg_anxiety,
    avg((emotion_analysis ->> 'fear'::text)::numeric) AS avg_fear,
    avg((emotion_analysis ->> 'sadness'::text)::numeric) AS avg_sadness,
    avg((emotion_analysis ->> 'discomfort'::text)::numeric) AS avg_discomfort,
    count(*) AS analysis_count
FROM emotion_history
GROUP BY user_id, pet_id, (date_trunc('day'::text, created_at));

-- Comments
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_author_id ON comments(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_deleted_at ON comments(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_id); -- M-F2: 대댓글 조회

-- Follows
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows(following_id);

-- Likes
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at ON notifications(user_id, created_at DESC);

-- Users
CREATE INDEX IF NOT EXISTS idx_users_pets ON users USING GIN(pets);
CREATE INDEX IF NOT EXISTS idx_users_following ON users USING GIN(following);
CREATE INDEX IF NOT EXISTS idx_users_followers ON users USING GIN(followers);
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users(is_onboarding_completed);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NOT NULL;

-- Comment Likes
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_id ON comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_created_at ON comment_likes(created_at DESC);

-- Reports
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_post_id ON reports(reported_post_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_comment_id ON reports(reported_comment_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

-- User Blocks
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker_id ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_id ON user_blocks(blocked_id);

-- Health Records
CREATE INDEX IF NOT EXISTS idx_health_records_pet_id ON health_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_health_records_user_id ON health_records(user_id);
CREATE INDEX IF NOT EXISTS idx_health_records_record_date ON health_records(record_date DESC);

-- Saved Posts
CREATE INDEX IF NOT EXISTS idx_saved_posts_user_id ON saved_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_posts_post_id ON saved_posts(post_id);
CREATE INDEX IF NOT EXISTS idx_saved_posts_created_at ON saved_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_posts_collection_id ON saved_posts(collection_id); -- M-F3

-- Bookmark Collections (M-F3)
CREATE INDEX IF NOT EXISTS idx_bookmark_collections_user_id ON bookmark_collections(user_id);

-- Chat Rooms
CREATE INDEX IF NOT EXISTS idx_chat_rooms_created_by ON chat_rooms(created_by);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_last_message_at ON chat_rooms(last_message_at DESC NULLS LAST);

-- Chat Participants
CREATE INDEX IF NOT EXISTS idx_chat_participants_room_id ON chat_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_room_user ON chat_participants(room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_active ON chat_participants(user_id, is_active);

-- Chat Messages
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(room_id, created_at DESC);


-- ================================================================
-- PART 4: Functions
-- ================================================================

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 좋아요 카운터
-- ⚠️ SECURITY DEFINER 필수: 다른 사람 게시물에 좋아요 시 posts UPDATE 가
-- RLS 정책(본인 글만 수정) 에 막힘. postgres 권한으로 실행되어야 BYPASSRLS.
CREATE OR REPLACE FUNCTION increment_likes_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_likes_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ language 'plpgsql';

-- 댓글 카운터 (동일 이유로 SECURITY DEFINER 필수)
CREATE OR REPLACE FUNCTION increment_comments_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_comments_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ language 'plpgsql';

-- Reports updated_at
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 게시물 좋아요 RPC
-- ⚠️ 실제 카운트 증가는 PART 5의 트리거(likes_count_increment/decrement)가 담당.
-- 이 RPC는 과거 앱 코드와의 호환성을 위한 0-op (아무 동작 없음).
-- 앱 코드에서 rpc 호출 제거 후 DROP FUNCTION 가능.
CREATE OR REPLACE FUNCTION increment_post_likes(post_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 0-op: 트리거가 담당
    RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_post_likes(post_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 0-op: 트리거가 담당
    RETURN;
END;
$$;

-- 게시물 댓글 카운트 RPC (0-op → 트리거 comments_count_increment/decrement가 담당)
CREATE OR REPLACE FUNCTION increment_post_comments(post_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_post_comments(post_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN;
END;
$$;

-- 댓글 좋아요 RPC (0-op → 트리거 comment_likes_count_increment/decrement가 담당)
CREATE OR REPLACE FUNCTION increment_comment_likes(comment_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_comment_likes(comment_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN;
END;
$$;

-- M-F2: comment_likes 트리거용 카운트 함수 (SECURITY DEFINER 필수, RLS 우회)
CREATE OR REPLACE FUNCTION increment_comment_likes_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_comment_likes_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
    RETURN OLD;
END;
$$ LANGUAGE 'plpgsql';

-- 회원가입 시 자동 프로필 생성
-- Supabase 설정: Authentication > Email > "Confirm email" = OFF
-- 이메일 인증은 앱에서 자체 OTP 플로우로 관리
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_orphan_id UUID;
    v_orphan_deleted_at TIMESTAMPTZ;
BEGIN
    BEGIN
        -- email UNIQUE 충돌 사전 처리:
        -- 같은 email인데 id가 다른 기존 public.users 행이 있으면(=고아 행) 분기한다.
        --   · deleted_at IS NULL  → 정상 탈퇴를 거치지 않고 남은 비정상 잔재
        --       (대시보드에서 auth.users만 수동 삭제 후 재가입 등) → 삭제하고 새 행 생성.
        --       이 처리가 없으면 ON CONFLICT(id)가 email 충돌을 못 잡아 INSERT가
        --       조용히 실패 → 로그인 시 "사용자 정보를 찾을 수 없습니다"로 깨진다.
        --   · deleted_at IS NOT NULL → 앱 탈퇴(soft delete) 유예 중인 계정.
        --       세션2 결정(30일 내 재가입 차단=의도된 동작)을 존중해 건드리지 않는다.
        --       이 경우 새 행 생성은 email 충돌로 실패하며, 정책상 복구로 유도한다.
        --
        -- ⚠️ 고아 판정에는 반드시 "auth.users 에 해당 id 가 없음"까지 포함해야 한다.
        --    소셜 로그인이 기존 계정에 연동되지 못하고 같은 email 로 새 auth 계정을
        --    만드는 경우(H-2 적용 전의 Apple 로그인 등), 기존 행은 살아있는 계정이다.
        --    이 체크가 없으면 그 계정의 프로필이 삭제되고 CASCADE 로 펫·게시물까지
        --    전부 지워진다. 살아있는 중복은 그대로 두어 INSERT 가 email 충돌로 실패
        --    (아래 EXCEPTION 로그)하게 하고, 앱 단의 23505 안내 메시지로 처리한다.
        SELECT u.id, u.deleted_at INTO v_orphan_id, v_orphan_deleted_at
        FROM public.users u
        WHERE u.email = NEW.email
          AND u.id <> NEW.id
          AND NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = u.id)
        LIMIT 1;

        IF v_orphan_id IS NOT NULL AND v_orphan_deleted_at IS NULL THEN
            DELETE FROM public.users WHERE id = v_orphan_id;
        END IF;

        INSERT INTO public.users (id, email, display_name, photo_url, provider, is_onboarding_completed)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
            COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
            COALESCE(NEW.raw_user_meta_data->>'provider', 'email'),
            FALSE
        )
        ON CONFLICT (id) DO UPDATE SET
            provider = COALESCE(NEW.raw_user_meta_data->>'provider', users.provider),
            photo_url = COALESCE(NEW.raw_user_meta_data->>'photo_url', users.photo_url),
            updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'handle_new_user error for %: %', NEW.email, SQLERRM;
    END;
    RETURN NEW;
END;
$$;

-- 사용자 반려동물 조회
DROP FUNCTION IF EXISTS get_user_pets(uuid);
CREATE OR REPLACE FUNCTION get_user_pets(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    type VARCHAR,
    breed VARCHAR,
    birth_date DATE,
    gender VARCHAR,
    avatar_url TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.name, p.type, p.breed, p.birth_date, p.gender, p.avatar_url, p.created_at
    FROM pets p
    WHERE p.user_id = user_uuid
    ORDER BY p.created_at DESC;
END;
$$;

-- 피드 포스트 조회 (soft delete 반영)
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
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
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
    -- D-5: 차단 양방향 필터링 (UGC 정책)
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

-- 감정 통계 조회
CREATE OR REPLACE FUNCTION get_emotion_statistics(
    user_uuid UUID,
    pet_uuid UUID DEFAULT NULL,
    days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    emotion VARCHAR,
    avg_score NUMERIC,
    count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        jsonb_object_keys(eh.emotion_analysis) as emotion,
        AVG((eh.emotion_analysis ->> jsonb_object_keys(eh.emotion_analysis))::NUMERIC) as avg_score,
        COUNT(*) as count
    FROM emotion_history eh
    WHERE eh.user_id = user_uuid
    AND (pet_uuid IS NULL OR eh.pet_id = pet_uuid)
    AND eh.created_at >= NOW() - INTERVAL '%s days'
    GROUP BY jsonb_object_keys(eh.emotion_analysis)
    ORDER BY avg_score DESC;
END;
$$;

-- 새 메시지 INSERT 시 chat_rooms.last_message 자동 갱신
CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    UPDATE chat_rooms
    SET
        last_message = CASE
            WHEN NEW.type = 'image' THEN '사진을 보냈습니다'
            WHEN NEW.type = 'system' THEN NEW.content
            ELSE NEW.content
        END,
        last_message_at = NEW.created_at,
        last_message_sender_id = NEW.sender_id
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 전체 읽지않은 메시지 수 조회 (뱃지용)
CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    total_count INTEGER;
BEGIN
    SELECT COALESCE(SUM(unread), 0) INTO total_count
    FROM (
        SELECT COUNT(cm.id) as unread
        FROM chat_participants cp
        JOIN chat_messages cm ON cm.room_id = cp.room_id
        WHERE cp.user_id = p_user_id
          AND cp.is_active = TRUE
          AND cm.created_at > cp.last_read_at
          AND cm.sender_id != p_user_id
        GROUP BY cp.room_id
    ) sub;
    RETURN total_count;
END;
$$;

-- 채팅방별 읽지않은 메시지 수 조회
CREATE OR REPLACE FUNCTION get_room_unread_count(p_room_id UUID, p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(cm.id) INTO unread_count
    FROM chat_messages cm
    JOIN chat_participants cp ON cp.room_id = cm.room_id AND cp.user_id = p_user_id
    WHERE cm.room_id = p_room_id
      AND cm.created_at > cp.last_read_at
      AND cm.sender_id != p_user_id;
    RETURN COALESCE(unread_count, 0);
END;
$$;

-- RLS 무한 재귀 방지용 헬퍼 함수
-- SECURITY DEFINER로 실행되어 RLS를 우회하여 chat_participants 조회
CREATE OR REPLACE FUNCTION is_room_member(p_room_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM chat_participants
        WHERE room_id = p_room_id
          AND user_id = p_user_id
          AND is_active = TRUE
    );
END;
$$;

-- 기존 1:1 채팅방 찾기 (중복 방지)
CREATE OR REPLACE FUNCTION find_direct_chat(p_user1_id UUID, p_user2_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    room_uuid UUID;
BEGIN
    SELECT cr.id INTO room_uuid
    FROM chat_rooms cr
    WHERE cr.type = 'direct'
      AND EXISTS (
          SELECT 1 FROM chat_participants cp1
          WHERE cp1.room_id = cr.id AND cp1.user_id = p_user1_id AND cp1.is_active = TRUE
      )
      AND EXISTS (
          SELECT 1 FROM chat_participants cp2
          WHERE cp2.room_id = cr.id AND cp2.user_id = p_user2_id AND cp2.is_active = TRUE
      )
    LIMIT 1;
    RETURN room_uuid;
END;
$$;

-- 카카오 로그인 사용자 이메일 인증 처리
-- 카카오 OAuth로 가입한 사용자의 이메일을 자동 인증 처리
DROP FUNCTION IF EXISTS confirm_kakao_user_by_email(text);
CREATE OR REPLACE FUNCTION confirm_kakao_user_by_email(p_email TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    -- auth.users에서 해당 이메일의 사용자 찾기
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = p_email
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'User not found');
    END IF;

    -- 이메일 인증 처리 (email_confirmed_at 설정)
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = v_user_id
    AND email_confirmed_at IS NULL;

    -- public.users에서도 provider 업데이트
    UPDATE public.users
    SET provider = 'kakao',
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN json_build_object(
        'success', true,
        'user_id', v_user_id,
        'message', 'Kakao user confirmed'
    );
END;
$$;

-- 인기 해시태그 조회 (게시물 수 기준)
DROP FUNCTION IF EXISTS get_popular_hashtags(integer);
CREATE OR REPLACE FUNCTION get_popular_hashtags(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    hashtag TEXT,
    post_count BIGINT
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        unnest(p.hashtags) AS hashtag,
        COUNT(*) AS post_count
    FROM posts p
    WHERE p.deleted_at IS NULL
    AND p.is_private IS FALSE
    AND p.hashtags IS NOT NULL
    GROUP BY unnest(p.hashtags)
    ORDER BY post_count DESC
    LIMIT limit_count;
END;
$$;

-- 트렌딩 해시태그 조회 (최근 N일 기준)
DROP FUNCTION IF EXISTS get_trending_hashtags(integer, integer);
CREATE OR REPLACE FUNCTION get_trending_hashtags(
    limit_count INTEGER DEFAULT 10,
    days_ago INTEGER DEFAULT 7
)
RETURNS TABLE (
    hashtag TEXT,
    post_count BIGINT
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        unnest(p.hashtags) AS hashtag,
        COUNT(*) AS post_count
    FROM posts p
    WHERE p.deleted_at IS NULL
    AND p.is_private IS FALSE
    AND p.hashtags IS NOT NULL
    AND p.created_at >= NOW() - (days_ago || ' days')::INTERVAL
    GROUP BY unnest(p.hashtags)
    ORDER BY post_count DESC
    LIMIT limit_count;
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

-- 계정 30일 soft delete (G-1: delete_user_account 대체)
-- 앱 호출처: auth_repository_impl.dart (Task 1-C에서 교체 예정)
CREATE OR REPLACE FUNCTION request_account_deletion()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NOW()
    WHERE id = auth.uid() AND deleted_at IS NULL;
END;
$$;

-- 계정 복구 RPC (SECURITY DEFINER — RLS 우회하여 본인 deleted_at 해제)
CREATE OR REPLACE FUNCTION restore_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NULL
    WHERE id = auth.uid() AND deleted_at IS NOT NULL;
END;
$$;

-- 게시물 soft delete 헬퍼
CREATE OR REPLACE FUNCTION soft_delete_post(post_uuid UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE posts
    SET deleted_at = NOW()
    WHERE id = post_uuid
    AND author_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$;

-- 댓글 soft delete 헬퍼
CREATE OR REPLACE FUNCTION soft_delete_comment(comment_uuid UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE comments
    SET deleted_at = NOW()
    WHERE id = comment_uuid
    AND author_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$;


-- ================================================================
-- PART 5: Triggers
-- ================================================================

-- updated_at 트리거
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_devices_updated_at ON user_devices;
CREATE TRIGGER update_user_devices_updated_at BEFORE UPDATE ON user_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_reports_updated_at ON reports;
CREATE TRIGGER trigger_update_reports_updated_at BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION update_reports_updated_at();

-- 좋아요 카운터 트리거
DROP TRIGGER IF EXISTS likes_count_increment ON likes;
CREATE TRIGGER likes_count_increment AFTER INSERT ON likes
    FOR EACH ROW EXECUTE FUNCTION increment_likes_count();

DROP TRIGGER IF EXISTS likes_count_decrement ON likes;
CREATE TRIGGER likes_count_decrement AFTER DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION decrement_likes_count();

-- 댓글 카운터 트리거
DROP TRIGGER IF EXISTS comments_count_increment ON comments;
CREATE TRIGGER comments_count_increment AFTER INSERT ON comments
    FOR EACH ROW EXECUTE FUNCTION increment_comments_count();

DROP TRIGGER IF EXISTS comments_count_decrement ON comments;
CREATE TRIGGER comments_count_decrement AFTER DELETE ON comments
    FOR EACH ROW EXECUTE FUNCTION decrement_comments_count();

-- M-F2: 댓글 좋아요 카운터 트리거
DROP TRIGGER IF EXISTS comment_likes_count_increment ON comment_likes;
CREATE TRIGGER comment_likes_count_increment AFTER INSERT ON comment_likes
    FOR EACH ROW EXECUTE FUNCTION increment_comment_likes_count();

DROP TRIGGER IF EXISTS comment_likes_count_decrement ON comment_likes;
CREATE TRIGGER comment_likes_count_decrement AFTER DELETE ON comment_likes
    FOR EACH ROW EXECUTE FUNCTION decrement_comment_likes_count();

-- health_records updated_at 트리거
DROP TRIGGER IF EXISTS update_health_records_updated_at ON health_records;
CREATE TRIGGER update_health_records_updated_at BEFORE UPDATE ON health_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- bookmark_collections updated_at 트리거 (M-F3)
DROP TRIGGER IF EXISTS update_bookmark_collections_updated_at ON bookmark_collections;
CREATE TRIGGER update_bookmark_collections_updated_at BEFORE UPDATE ON bookmark_collections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 회원가입 트리거 (Confirm email OFF이므로 INSERT 시 항상 실행)
DROP TRIGGER IF EXISTS on_social_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Chat 트리거
DROP TRIGGER IF EXISTS update_chat_rooms_updated_at ON chat_rooms;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE UPDATE ON chat_rooms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS on_chat_message_insert ON chat_messages;
CREATE TRIGGER on_chat_message_insert
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_room_last_message();


-- ================================================================
-- PART 6: Row Level Security (테이블)
-- ================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmark_collections ENABLE ROW LEVEL SECURITY; -- M-F3
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Users
-- 인증된 유저는 모든 프로필 조회 가능 (채팅 유저 검색, 소셜 기능 등)
-- 탈퇴 계정(deleted_at NOT NULL)은 본인만 조회 가능 (복구 안내용)
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON users;
CREATE POLICY "Authenticated users can view all profiles" ON users
    FOR SELECT TO authenticated
    USING (deleted_at IS NULL OR auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- [RLS 보강] Users DELETE: 본인 계정만 삭제 가능
DROP POLICY IF EXISTS "Users can delete own profile" ON users;
CREATE POLICY "Users can delete own profile" ON users
    FOR DELETE USING (auth.uid() = id);

-- Pets
DROP POLICY IF EXISTS "Users can view own pets" ON pets;
CREATE POLICY "Users can view own pets" ON pets
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own pets" ON pets;
CREATE POLICY "Users can insert own pets" ON pets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own pets" ON pets;
CREATE POLICY "Users can update own pets" ON pets
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own pets" ON pets;
CREATE POLICY "Users can delete own pets" ON pets
    FOR DELETE USING (auth.uid() = user_id);

-- Posts (soft delete 반영 + 탈퇴 작성자 차단)
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = posts.author_id AND u.deleted_at IS NOT NULL
        )
    );

DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
CREATE POLICY "Users can insert own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can update own posts" ON posts;
CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = author_id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can delete own posts" ON posts;
CREATE POLICY "Users can delete own posts" ON posts
    FOR DELETE USING (auth.uid() = author_id AND deleted_at IS NULL);

-- Emotion History
DROP POLICY IF EXISTS "Users can only see own emotion history" ON emotion_history;
CREATE POLICY "Users can only see own emotion history" ON emotion_history
    FOR ALL USING (auth.uid() = user_id);

-- Comments (soft delete 반영 + 탈퇴 작성자 차단)
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = comments.author_id AND u.deleted_at IS NOT NULL
        )
    );

DROP POLICY IF EXISTS "Users can insert comments" ON comments;
CREATE POLICY "Users can insert comments" ON comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can update own comments" ON comments;
CREATE POLICY "Users can update own comments" ON comments
    FOR UPDATE USING (auth.uid() = author_id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
CREATE POLICY "Users can delete own comments" ON comments
    FOR DELETE USING (auth.uid() = author_id AND deleted_at IS NULL);

-- Follows
DROP POLICY IF EXISTS "Users can view follows" ON follows;
CREATE POLICY "Users can view follows" ON follows
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can follow others" ON follows;
CREATE POLICY "Users can follow others" ON follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can unfollow others" ON follows;
CREATE POLICY "Users can unfollow others" ON follows
    FOR DELETE USING (auth.uid() = follower_id);

-- Likes
DROP POLICY IF EXISTS "Users can view likes" ON likes;
CREATE POLICY "Users can view likes" ON likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can like posts" ON likes;
CREATE POLICY "Users can like posts" ON likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike posts" ON likes;
CREATE POLICY "Users can unlike posts" ON likes
    FOR DELETE USING (auth.uid() = user_id);

-- Notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- [RLS 보강] Notifications DELETE: 본인 알림만 삭제 가능
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

-- User Devices
DROP POLICY IF EXISTS "Users can manage own devices" ON user_devices;
CREATE POLICY "Users can manage own devices" ON user_devices
    FOR ALL USING (auth.uid() = user_id);

-- Comment Likes
DROP POLICY IF EXISTS "Users can view all comment likes" ON comment_likes;
CREATE POLICY "Users can view all comment likes" ON comment_likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create comment likes for themselves" ON comment_likes;
CREATE POLICY "Users can create comment likes for themselves" ON comment_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comment likes" ON comment_likes;
CREATE POLICY "Users can delete their own comment likes" ON comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Reports
DROP POLICY IF EXISTS "Users can view their own reports" ON reports;
CREATE POLICY "Users can view their own reports" ON reports
    FOR SELECT USING (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports" ON reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- User Blocks
DROP POLICY IF EXISTS "Users can view their own blocks" ON user_blocks;
CREATE POLICY "Users can view their own blocks" ON user_blocks
    FOR SELECT USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can create blocks for themselves" ON user_blocks;
CREATE POLICY "Users can create blocks for themselves" ON user_blocks
    FOR INSERT WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can delete their own blocks" ON user_blocks;
CREATE POLICY "Users can delete their own blocks" ON user_blocks
    FOR DELETE USING (auth.uid() = blocker_id);

-- Health Records
DROP POLICY IF EXISTS "Users can view own pet health records" ON health_records;
CREATE POLICY "Users can view own pet health records" ON health_records
    FOR SELECT USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own pet health records" ON health_records;
CREATE POLICY "Users can insert own pet health records" ON health_records
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update own pet health records" ON health_records;
CREATE POLICY "Users can update own pet health records" ON health_records
    FOR UPDATE USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete own pet health records" ON health_records;
CREATE POLICY "Users can delete own pet health records" ON health_records
    FOR DELETE USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1
            FROM pets
            WHERE pets.id = health_records.pet_id
              AND pets.user_id = auth.uid()
        )
    );

-- Saved Posts (북마크)
DROP POLICY IF EXISTS "Users can manage own saved posts" ON saved_posts;
CREATE POLICY "Users can manage own saved posts" ON saved_posts
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Bookmark Collections (M-F3: 북마크 컬렉션)
DROP POLICY IF EXISTS "users manage own collections" ON bookmark_collections;
CREATE POLICY "users manage own collections" ON bookmark_collections
    FOR ALL USING (auth.uid() = user_id);

-- Chat Rooms
DROP POLICY IF EXISTS "Users can view rooms they participate in" ON chat_rooms;
CREATE POLICY "Users can view rooms they participate in" ON chat_rooms
    FOR SELECT USING (
        created_by = auth.uid()
        OR is_room_member(chat_rooms.id, auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated users can create chat rooms" ON chat_rooms;
CREATE POLICY "Authenticated users can create chat rooms" ON chat_rooms
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Room creator or admin can update room" ON chat_rooms;
CREATE POLICY "Room creator or admin can update room" ON chat_rooms
    FOR UPDATE USING (
        auth.uid() = created_by
        OR is_room_member(chat_rooms.id, auth.uid())
    );

-- Chat Participants
-- NOTE: SELECT 정책에서 자기 자신(chat_participants)을 서브쿼리로 참조하면
-- 무한 재귀(infinite recursion) 오류가 발생함.
-- 해결: SECURITY DEFINER 함수로 RLS를 우회하여 참여 여부 확인
DROP POLICY IF EXISTS "Users can view participants of their rooms" ON chat_participants;
CREATE POLICY "Users can view participants of their rooms" ON chat_participants
    FOR SELECT USING (
        is_room_member(chat_participants.room_id, auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated users can insert participants" ON chat_participants;
CREATE POLICY "Authenticated users can insert participants" ON chat_participants
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM chat_rooms
            WHERE chat_rooms.id = room_id
              AND chat_rooms.created_by = auth.uid()
        )
        OR auth.uid() = user_id
    );

DROP POLICY IF EXISTS "Users can update own participant record" ON chat_participants;
CREATE POLICY "Users can update own participant record" ON chat_participants
    FOR UPDATE USING (auth.uid() = user_id);

-- Chat Messages
DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
CREATE POLICY "Users can view messages in their rooms" ON chat_messages
    FOR SELECT USING (
        is_room_member(chat_messages.room_id, auth.uid())
    );

DROP POLICY IF EXISTS "Users can send messages to rooms they belong to" ON chat_messages;
CREATE POLICY "Users can send messages to rooms they belong to" ON chat_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND is_room_member(room_id, auth.uid())
    );

DROP POLICY IF EXISTS "Users can delete their own messages" ON chat_messages;
CREATE POLICY "Users can delete their own messages" ON chat_messages
    FOR DELETE TO authenticated
    USING (auth.uid() = sender_id);

-- ================================================================
-- PART 5-E1: 반려동물 MBTI 결과 이력 (E1_pet_mbti.sql 반영)
-- ----------------------------------------------------------------
-- 검사 결과는 INSERT로 누적하고 기존 결과는 수정하지 않는다.
-- pets의 두 캐시 컬럼은 홈·프로필에서 최신 유형을 빠르게 표시하는 용도다.
-- 실제 운영 DB 변경은 migrations/E1_pet_mbti.sql을 적용한다.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.pet_mbti_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat', 'etc')),
    type_code TEXT NOT NULL CHECK (char_length(type_code) = 4),
    axis_scores JSONB NOT NULL DEFAULT '{}'::jsonb,
    answers JSONB NOT NULL DEFAULT '[]'::jsonb,
    content_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pet_mbti_results IS
  '반려동물 MBTI 검사 결과 이력. 검사마다 INSERT 누적(UPDATE 미사용). 최신 1건은 created_at DESC.';
COMMENT ON COLUMN public.pet_mbti_results.species IS 'dog / cat / etc(범용 문항)';
COMMENT ON COLUMN public.pet_mbti_results.type_code IS '4글자 MBTI 코드. 예: ENFP';
COMMENT ON COLUMN public.pet_mbti_results.axis_scores IS
  '축별 극 카운트. 축당 합=5. 예: {"EI":{"E":4,"I":1}}';
COMMENT ON COLUMN public.pet_mbti_results.answers IS '응답 원본 배열. 재계산/감사용.';
COMMENT ON COLUMN public.pet_mbti_results.content_version IS
  'JSON meta.version. 과거 결과 호환용.';

CREATE INDEX IF NOT EXISTS idx_pet_mbti_results_pet_created
    ON public.pet_mbti_results (pet_id, created_at DESC);

ALTER TABLE public.pets
    ADD COLUMN IF NOT EXISTS current_mbti_type TEXT;
ALTER TABLE public.pets
    ADD COLUMN IF NOT EXISTS current_mbti_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.pets.current_mbti_type IS
  'MBTI 최신 결과 type_code 캐시. 프로필/홈 카드 표시용. 원천은 pet_mbti_results.';
COMMENT ON COLUMN public.pets.current_mbti_updated_at IS
  'current_mbti_type 캐시 갱신 시각.';

ALTER TABLE public.pet_mbti_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own pet mbti results"
    ON public.pet_mbti_results;
CREATE POLICY "Users can view own pet mbti results"
    ON public.pet_mbti_results
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own pet mbti results"
    ON public.pet_mbti_results;
CREATE POLICY "Users can insert own pet mbti results"
    ON public.pet_mbti_results
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete own pet mbti results"
    ON public.pet_mbti_results;
CREATE POLICY "Users can delete own pet mbti results"
    ON public.pet_mbti_results
    FOR DELETE USING (
        EXISTS (
            SELECT 1
            FROM public.pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );


-- ================================================================
-- PART 6-H1: 산책 기록 + 위치정보 취급대장 (H1_walk_records.sql 반영)
-- ----------------------------------------------------------------
-- LBS 사업신고 첨부2(기술적 보호조치) 증빙용. 산책 기록의 출시용 정식 스키마.
-- 실제 적용 대상은 migrations/H1_walk_records.sql. 여기는 신규 설치 일관성용 반영.
-- 설계 결정: user_id FK→public.users / 취급대장 subject_id FK 미부여(증빙 보존)
--          / route jsonb 단일 컬럼 / 취급대장 INSERT 정책 미부여(트리거 전용).
-- 테이블·트리거·RLS를 한 블록에 모아 유지보수성 확보(기능 단위 응집).
-- ================================================================

-- H1-1. 산책 기록
CREATE TABLE IF NOT EXISTS public.walk_records (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    pet_id      UUID REFERENCES public.pets(id) ON DELETE SET NULL,
    started_at  TIMESTAMPTZ NOT NULL,
    ended_at    TIMESTAMPTZ,
    distance_m  INTEGER NOT NULL DEFAULT 0,   -- 산책 거리(미터)
    duration_s  INTEGER NOT NULL DEFAULT 0,   -- 산책 시간(초)
    route       JSONB,                        -- 경로 좌표 [{lat,lng,t}] ← 핵심 위치정보
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.walk_records       IS '산책 기록(경로 위치정보 포함). LBS 신고 첨부2 증빙 대상.';
COMMENT ON COLUMN public.walk_records.route IS '경로 좌표 배열 [{lat,lng,t}]. 개인위치정보 → RLS로 본인만 접근.';

-- H1-2. 위치정보 이용·제공사실 확인자료 (취급대장) — subject_id FK 미부여
CREATE TABLE IF NOT EXISTS public.location_access_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_id  UUID NOT NULL,                                       -- 대상(개인위치정보주체)
    source      TEXT NOT NULL DEFAULT 'device_gps(apple/google)',    -- 취득경로(위치정보사업자)
    service     TEXT NOT NULL DEFAULT 'petspace_walk',               -- 제공 서비스
    provided_to TEXT,                                                -- 제공받는 자(제3자 없음 → NULL)
    used_at     TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE public.location_access_log IS '위치정보 이용·제공사실 확인자료(취급대장). 트리거(security definer)만 기록, 사용자 조작 불가. 위치정보법 보존 의무 대상이라 subject_id FK 미부여.';

-- H1-3. 인덱스 (FK 컬럼 — 기존 테이블 관례)
CREATE INDEX IF NOT EXISTS idx_walk_records_user_id           ON public.walk_records(user_id);
CREATE INDEX IF NOT EXISTS idx_walk_records_pet_id            ON public.walk_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_walk_records_started_at        ON public.walk_records(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_access_log_subject_id ON public.location_access_log(subject_id);

-- H1-4. 취급대장 자동 기록 트리거 (SECURITY DEFINER — RLS 우회 기록, 사용자 조작 불가)
CREATE OR REPLACE FUNCTION public.log_location_access()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.location_access_log(subject_id, source, service, provided_to)
    VALUES (NEW.user_id, 'device_gps(apple/google)', 'petspace_walk', NULL);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_walk_log ON public.walk_records;
CREATE TRIGGER trg_walk_log
    AFTER INSERT ON public.walk_records
    FOR EACH ROW EXECUTE FUNCTION public.log_location_access();

-- H1-5. RLS — walk_records 본인 CRUD / location_access_log SELECT-only(트리거 전용)
ALTER TABLE public.walk_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_walk" ON public.walk_records;
CREATE POLICY "select_own_walk" ON public.walk_records
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_walk" ON public.walk_records;
CREATE POLICY "insert_own_walk" ON public.walk_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_walk" ON public.walk_records;
CREATE POLICY "update_own_walk" ON public.walk_records
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_walk" ON public.walk_records;
CREATE POLICY "delete_own_walk" ON public.walk_records
    FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE public.location_access_log ENABLE ROW LEVEL SECURITY;

-- INSERT/UPDATE/DELETE 정책 미부여 → 트리거(security definer)만 기록. 직접 INSERT는 RLS로 거부.
DROP POLICY IF EXISTS "select_own_log" ON public.location_access_log;
CREATE POLICY "select_own_log" ON public.location_access_log
    FOR SELECT USING (auth.uid() = subject_id);


-- ================================================================
-- PART 7: Storage Bucket
-- ================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;


-- ================================================================
-- PART 8: Storage RLS Policies
-- ================================================================
--
-- Storage RLS 구성 요약:
--   버킷: 'images' (public: true)
--   폴더 구조: images/{folder}/{user_id}/{filename}
--
--   SQL로 설정된 Storage RLS 정책:
--     - profiles/   : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - pets/       : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - posts/      : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - emotion_analysis/ : INSERT/UPDATE/DELETE는 본인만, SELECT는 public
--     - chat/       : INSERT는 본인만, SELECT는 authenticated
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

-- 버킷 전체를 허용하는 광범위한 SELECT 정책 제거 (Security Advisor 경고 해소)
-- 폴더별 세분화 정책(아래)으로 대체됨
DROP POLICY IF EXISTS "Allow public reads from images" ON storage.objects;

-- 프로필 이미지
DROP POLICY IF EXISTS "Users can upload own profile images" ON storage.objects;
CREATE POLICY "Users can upload own profile images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'profiles' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update own profile images" ON storage.objects;
CREATE POLICY "Users can update own profile images" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'profiles' AND (storage.foldername(name))[2] = auth.uid()::text)
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'profiles' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete own profile images" ON storage.objects;
CREATE POLICY "Users can delete own profile images" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'profiles' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;
CREATE POLICY "Public can view profile images" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'profiles');

-- 반려동물 이미지
DROP POLICY IF EXISTS "Users can upload pet images" ON storage.objects;
CREATE POLICY "Users can upload pet images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'pets' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update pet images" ON storage.objects;
CREATE POLICY "Users can update pet images" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'pets' AND (storage.foldername(name))[2] = auth.uid()::text)
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'pets' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete pet images" ON storage.objects;
CREATE POLICY "Users can delete pet images" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'pets' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;
CREATE POLICY "Public can view pet images" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'pets');

-- 게시물 이미지
DROP POLICY IF EXISTS "Users can upload post images" ON storage.objects;
CREATE POLICY "Users can upload post images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'posts' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update post images" ON storage.objects;
CREATE POLICY "Users can update post images" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'posts' AND (storage.foldername(name))[2] = auth.uid()::text)
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'posts' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete post images" ON storage.objects;
CREATE POLICY "Users can delete post images" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'posts' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Public can view post images" ON storage.objects;
CREATE POLICY "Public can view post images" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'posts');

-- 감정 분석 이미지
DROP POLICY IF EXISTS "Users can upload emotion analysis images" ON storage.objects;
CREATE POLICY "Users can upload emotion analysis images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'emotion_analysis' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update emotion analysis images" ON storage.objects;
CREATE POLICY "Users can update emotion analysis images" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'emotion_analysis' AND (storage.foldername(name))[2] = auth.uid()::text)
    WITH CHECK (bucket_id = 'images' AND (storage.foldername(name))[1] = 'emotion_analysis' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete emotion analysis images" ON storage.objects;
CREATE POLICY "Users can delete emotion analysis images" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'emotion_analysis' AND (storage.foldername(name))[2] = auth.uid()::text);

DROP POLICY IF EXISTS "Public can view emotion analysis images" ON storage.objects;
CREATE POLICY "Public can view emotion analysis images" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'images' AND (storage.foldername(name))[1] = 'emotion_analysis');

-- 채팅 이미지
DROP POLICY IF EXISTS "Users can upload chat images" ON storage.objects;
CREATE POLICY "Users can upload chat images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'images'
        AND (storage.foldername(name))[1] = 'chat'
        AND (storage.foldername(name))[2] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users can view chat images" ON storage.objects;
CREATE POLICY "Users can view chat images" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'images'
        AND (storage.foldername(name))[1] = 'chat'
    );


-- ================================================================
-- PART 9: Realtime Publication
-- ================================================================
-- Supabase Realtime을 통한 실시간 업데이트를 위해
-- likes, comments, notifications, chat_messages, chat_participants
-- 테이블을 publication에 추가합니다.
-- (supabase_realtime publication은 Supabase가 자동 생성함)

DO $$
BEGIN
    -- likes
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'likes'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE likes;
    END IF;

    -- comments
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'comments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE comments;
    END IF;

    -- notifications
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
    END IF;

    -- chat_messages
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
    END IF;

    -- chat_participants
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_participants'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;
    END IF;

    RAISE NOTICE 'Realtime publication 설정 완료 (likes, comments, notifications, chat_messages, chat_participants)';
END $$;

-- ================================================================
-- DONE
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  PetSpace 데이터베이스 설정 완료!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '테이블 17개, 인덱스, RLS, 트리거, 함수, 스토리지, Realtime 설정 완료';
    RAISE NOTICE '  1-14: users, pets, posts, emotion_history, comments, follows,';
    RAISE NOTICE '        likes, notifications, user_devices, comment_likes,';
    RAISE NOTICE '        reports, user_blocks, health_records, saved_posts';
    RAISE NOTICE '  15-17: chat_rooms, chat_participants, chat_messages';
    RAISE NOTICE '  + soft delete (posts, comments)';
    RAISE NOTICE '  + search_path 보안 수정 (모든 함수)';
    RAISE NOTICE '  + confirm_kakao_user_by_email RPC (카카오 로그인)';
    RAISE NOTICE '  + get_popular_hashtags / get_trending_hashtags RPC';
    RAISE NOTICE '  + RLS 보강: users DELETE, notifications DELETE';
    RAISE NOTICE '================================================';
END $$;


-- ================================================================
-- PART 10: 포인트 / 퀘스트 / 스토어 / 기부 / 뱃지 (Week 1 추가)
-- ================================================================

-- 18. 포인트 거래 내역
CREATE TABLE IF NOT EXISTS point_transactions (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount      INTEGER NOT NULL,
  type        TEXT NOT NULL,
  description TEXT NOT NULL,
  ref_id      TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 포인트 잔액 뷰 (SECURITY INVOKER: RLS 우회 방지)
CREATE OR REPLACE VIEW user_points
  WITH (security_invoker = true)
AS
  SELECT user_id, COALESCE(SUM(amount), 0)::INTEGER AS balance
  FROM point_transactions
  GROUP BY user_id;

-- 19. 퀘스트 정의
CREATE TABLE IF NOT EXISTS quests (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type         TEXT NOT NULL,
  key          TEXT UNIQUE NOT NULL,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL,
  point_reward INTEGER NOT NULL,
  target_count INTEGER DEFAULT 1,
  is_active    BOOLEAN DEFAULT true
);

-- 20. 유저 퀘스트 진행
CREATE TABLE IF NOT EXISTS user_quest_progress (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  quest_id     UUID REFERENCES quests(id),
  period_key   TEXT NOT NULL,
  progress     INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, quest_id, period_key)
);

-- 21. 스토어 아이템
CREATE TABLE IF NOT EXISTS store_items (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category     TEXT NOT NULL,
  name         TEXT NOT NULL,
  description  TEXT,
  point_cost   INTEGER NOT NULL,
  image_url    TEXT,
  is_available BOOLEAN DEFAULT true,
  stock        INTEGER,
  partner_name TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- 22. 구매 내역
CREATE TABLE IF NOT EXISTS user_purchases (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id      UUID REFERENCES store_items(id),
  point_spent  INTEGER NOT NULL,
  used_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- 23. 기부 캠페인
CREATE TABLE IF NOT EXISTS donation_campaigns (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title          TEXT NOT NULL,
  description    TEXT,
  goal_amount    INTEGER NOT NULL,
  current_amount INTEGER DEFAULT 0,
  start_at       TIMESTAMPTZ,
  end_at         TIMESTAMPTZ,
  is_active      BOOLEAN DEFAULT true
);

-- 24. 유저 뱃지
CREATE TABLE IF NOT EXISTS user_badges (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id  TEXT NOT NULL,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id)
);


-- ================================================================
-- PART 10-B: 인덱스
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_point_transactions_user_id
  ON point_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_transactions_created_at
  ON point_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_quest_progress_user_id
  ON user_quest_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quest_progress_period
  ON user_quest_progress(user_id, period_key);
CREATE INDEX IF NOT EXISTS idx_user_purchases_user_id
  ON user_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id
  ON user_badges(user_id);


-- ================================================================
-- PART 10-C: RLS
-- ================================================================

ALTER TABLE point_transactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quest_progress  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_purchases       ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_items          ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation_campaigns   ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges          ENABLE ROW LEVEL SECURITY;
ALTER TABLE quests               ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users read own points"   ON point_transactions;
DROP POLICY IF EXISTS "users insert own points" ON point_transactions;
CREATE POLICY "users read own points"   ON point_transactions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users insert own points" ON point_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users manage own quest progress" ON user_quest_progress;
CREATE POLICY "users manage own quest progress" ON user_quest_progress
  FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users manage own purchases" ON user_purchases;
CREATE POLICY "users manage own purchases" ON user_purchases
  FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "anyone read store items" ON store_items;
CREATE POLICY "anyone read store items" ON store_items
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "anyone read campaigns" ON donation_campaigns;
CREATE POLICY "anyone read campaigns" ON donation_campaigns
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "users manage own badges" ON user_badges;
CREATE POLICY "users manage own badges" ON user_badges
  FOR ALL USING (auth.uid() = user_id);

-- 퀘스트 정의는 모든 인증 유저가 읽기만 가능 (쓰기는 관리자만)
DROP POLICY IF EXISTS "anyone read quests" ON quests;
CREATE POLICY "anyone read quests" ON quests
  FOR SELECT USING (true);


-- ================================================================
-- PART 10-D: 퀘스트 초기 데이터
-- ================================================================

INSERT INTO quests (type, key, title, description, point_reward, target_count)
VALUES
  ('daily',       'daily_emotion_analysis',  'AI 감정 분석하기',       '사진 1장 업로드',       50,  1),
  ('daily',       'daily_health_record',     '건강 기록 추가하기',      '기록 1개 작성',         30,  1),
  ('daily',       'daily_community_comment', '커뮤니티 댓글 달기',      '댓글 1개 작성',         30,  1),
  ('daily',       'daily_app_open',          '오늘 앱 열기',            '앱 접속',               10,  1),
  ('weekly',      'weekly_streak_7',         '7일 연속 감정 분석',      '7일 연속 분석 달성',    300, 7),
  ('weekly',      'weekly_likes_10',         '커뮤니티 좋아요 10개',    '이번 주 좋아요',        100, 10),
  ('weekly',      'weekly_posts_3',          '이번 주 게시글 3개 작성', '피드 포스팅',           150, 3),
  ('achievement', 'ach_first_analysis',      '첫 AI 분석 완료',         '최초 감정 분석',        100, 1),
  ('achievement', 'ach_10_records',          '건강 기록 10개 달성',     '누적 기록',             200, 10),
  ('achievement', 'ach_level_5',             '레벨 5 달성',             '꾸준히 활동',           500, 1)
ON CONFLICT (key) DO NOTHING;


-- ================================================================
-- PART 11: increment_user_points RPC
-- 퀘스트 포인트 저장 시 race condition 없이 원자적으로 증가
--
-- 구조: user_points는 VIEW (point_transactions의 SUM)
--       → INSERT는 point_transactions 테이블에 직접 삽입
--       → user_points VIEW가 자동으로 잔액 합산
--
-- 호출: supabase.rpc('increment_user_points', { p_user_id: uid, p_points: 30 })
-- ================================================================

-- 보안(세션1 1-B, 1단계): p_user_id는 클라이언트 호출부 호환을 위해 시그니처에만 남기고
-- 적립 대상은 항상 auth.uid()로 강제한다 → 타인 계정 포인트 조작 차단.
-- auth.uid()가 NULL(비인증)이면 예외로 차단.
-- ⚠️ 2단계(금액 서버 산정 + 일일 제한 함수 내부 이전)는 리워드 스토어 개발 시 반드시 함께 처리.
--    소비처(리워드 스토어)가 생기면 본인 무한 적립이 실제 악용이 되므로 그 전까지 누락 금지.
--
-- ⚠️ 오버로드 모호성 제거: 과거 2-파라미터 오버로드 increment_user_points(UUID, INT)가
--    함께 존재하면, (UUID, INT) 호출이 2-파라미터 함수와 "4-파라미터(뒤 2개 DEFAULT)" 함수
--    양쪽에 매칭되어 42725(is not unique) 오류가 난다. 2-파라미터 오버로드는 제거하고
--    4-파라미터 단일 함수로 통일한다. (클라이언트는 named arg로 p_user_id/p_points만 전달 → default 적용)
DROP FUNCTION IF EXISTS increment_user_points(UUID, INT);

CREATE OR REPLACE FUNCTION increment_user_points(
  p_user_id    UUID,
  p_points     INT,
  p_type       TEXT DEFAULT 'quest',
  p_description TEXT DEFAULT '퀘스트 완료'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION '인증되지 않은 호출입니다.' USING ERRCODE = '42501';
  END IF;
  INSERT INTO point_transactions (user_id, amount, type, description)
  VALUES (v_uid, p_points, p_type, p_description);
END;
$$;

-- ================================================================
-- 건강 분석 히스토리 (AI 건강분석 결과 저장)
-- 추가: 2026-04-16
-- ================================================================

CREATE TABLE IF NOT EXISTS health_history (
  id                 BIGSERIAL PRIMARY KEY,
  user_id            UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pet_id             UUID,
  pet_name           TEXT,
  area               TEXT NOT NULL,
  image_urls         TEXT[]   DEFAULT '{}',
  overall_score      INT      NOT NULL,
  status             TEXT     NOT NULL,          -- '양호' | '주의' | '위험' | '확인불가'
  findings           JSONB    DEFAULT '[]',
  risk_alert         BOOLEAN  DEFAULT FALSE,
  risk_reason        TEXT,
  recommendations    TEXT[]   DEFAULT '{}',
  confidence         FLOAT    NOT NULL,
  summary            TEXT     NOT NULL,
  additional_context TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_health_history_user_id   ON health_history (user_id);
CREATE INDEX IF NOT EXISTS idx_health_history_pet_id    ON health_history (pet_id);
CREATE INDEX IF NOT EXISTS idx_health_history_created_at ON health_history (created_at DESC);

-- RLS
ALTER TABLE health_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users can manage own health_history" ON health_history;
CREATE POLICY "users can manage own health_history"
  ON health_history FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── get_latest_health_by_area RPC ──────────────────────────────────────────
-- 부위별 최신 건강 분석 결과 조회 (AiHistoryPage 현황 탭 이용)
-- p_user_id: 조회할 유저 UUID
-- p_pet_id:  NULL이면 pet_id IS NULL인 미등록 분석만 조회,
--            값이 있으면 해당 pet의 분석만 조회
CREATE OR REPLACE FUNCTION get_latest_health_by_area(
  p_user_id UUID,
  p_pet_id  UUID DEFAULT NULL
)
RETURNS TABLE (
  area          TEXT,
  overall_score INT,
  status        TEXT,
  risk_alert    BOOLEAN,
  created_at    TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT ON (area)
    area,
    overall_score,
    status,
    risk_alert,
    created_at
  FROM health_history
  WHERE user_id = p_user_id
    AND (
      p_pet_id IS NULL
        AND pet_id IS NULL
      OR
      p_pet_id IS NOT NULL
        AND pet_id = p_pet_id
    )
  ORDER BY area, created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION get_latest_health_by_area(UUID, UUID) FROM anon;


-- ================================================================
-- PART 12: M-F3 발견성 RPC (추천 알고리즘 + 해시태그/위치 검색)
-- 추가: 2026-04-22
-- ================================================================

-- ── get_recommended_posts ────────────────────────────────────────
-- 추천 알고리즘 rule-based 점수
-- - 같은 견종 매칭: +40
-- - 작성자 주간 활동성 (3+ 게시물): +20
-- - 내가 좋아요한 유저의 다른 게시물: +15
-- - 최신 글 (3일 이내): +10
-- 팔로우/차단 관계는 제외
CREATE OR REPLACE FUNCTION get_recommended_posts(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  author_id UUID,
  author_name VARCHAR,
  author_photo TEXT,
  pet_id UUID,
  pet_name VARCHAR,
  pet_type VARCHAR,
  pet_breed VARCHAR,
  image_url TEXT,
  emotion_analysis JSONB,
  caption TEXT,
  hashtags TEXT[],
  location TEXT,
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  likes_count INTEGER,
  comments_count INTEGER,
  created_at TIMESTAMPTZ,
  is_liked BOOLEAN,
  recommendation_score INTEGER
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_breeds TEXT[];
BEGIN
  SELECT ARRAY_AGG(DISTINCT breed) INTO v_user_breeds
  FROM pets WHERE user_id = p_user_id AND breed IS NOT NULL;

  RETURN QUERY
  SELECT
    p.id, p.author_id,
    u.display_name AS author_name,
    u.photo_url AS author_photo,
    p.pet_id, pet.name AS pet_name, pet.type AS pet_type, pet.breed AS pet_breed,
    p.image_url, p.emotion_analysis, p.caption, p.hashtags,
    p.location, p.location_lat, p.location_lng,
    p.likes_count, p.comments_count, p.created_at,
    EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked,
    (
      CASE WHEN pet.breed IS NOT NULL AND pet.breed = ANY(v_user_breeds) THEN 40 ELSE 0 END
      +
      CASE WHEN (
        SELECT COUNT(*) FROM posts p2
        WHERE p2.author_id = p.author_id
          AND p2.created_at >= NOW() - INTERVAL '7 days'
          AND p2.deleted_at IS NULL
      ) >= 3 THEN 20 ELSE 0 END
      +
      CASE WHEN EXISTS(
        SELECT 1 FROM likes l
        JOIN posts p3 ON l.post_id = p3.id
        WHERE l.user_id = p_user_id AND p3.author_id = p.author_id
      ) THEN 15 ELSE 0 END
      +
      CASE WHEN p.created_at >= NOW() - INTERVAL '3 days' THEN 10 ELSE 0 END
    )::INTEGER AS recommendation_score
  FROM posts p
  LEFT JOIN users u ON p.author_id = u.id
  LEFT JOIN pets pet ON p.pet_id = pet.id
  WHERE
    p.deleted_at IS NULL
    AND p.is_private = FALSE
    AND p.author_id != p_user_id
    AND NOT EXISTS(
      SELECT 1 FROM follows f
      WHERE f.follower_id = p_user_id AND f.following_id = p.author_id
    )
    AND NOT EXISTS(
      SELECT 1 FROM user_blocks ub
      WHERE (ub.blocker_id = p_user_id AND ub.blocked_id = p.author_id)
         OR (ub.blocker_id = p.author_id AND ub.blocked_id = p_user_id)
    )
  ORDER BY recommendation_score DESC, p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ── get_posts_by_hashtag ─────────────────────────────────────────
-- 특정 해시태그의 게시물 조회. sort = 'popular' | 'recent'
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
    -- D-5: 차단 양방향 필터링 (UGC 정책)
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

-- ── get_posts_by_location ────────────────────────────────────────
-- 반경 내 게시물 (Bounding box 방식, PostGIS 없이)
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
  -- 위도 1도 ≈ 111km. 경도 1도는 cos(lat) * 111km
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
    -- D-5: 차단 양방향 필터링 (UGC 정책)
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

-- ============================================================================
-- PART 11: 알림/차단 시스템 (2026-04-23 추가)
-- ============================================================================
-- FCM 백엔드 + 로컬 알림 + 사용자 차단 + 알림 설정 동기화.
-- Edge Function send-push-notification 이 is_sent=false 레코드를 폴링 발송.

-- ── 11.1 notifications 테이블 확장 ────────────────────────────────────────
-- 기존 테이블에 컬럼만 추가 (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'is_sent'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN is_sent BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'post_id'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN post_id UUID REFERENCES posts(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'comment_id'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN comment_id UUID REFERENCES comments(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'sent_at'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN sent_at TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'notifications'
          AND column_name = 'event_key'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN event_key TEXT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unsent
    ON notifications(created_at ASC)
    WHERE is_sent = FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(user_id, created_at DESC)
    WHERE read = FALSE;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own ON notifications
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_delete_own ON notifications;
CREATE POLICY notifications_delete_own ON notifications
    FOR DELETE USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_service ON notifications;
-- notify_on_like/comment/follow 트리거는 SECURITY DEFINER 함수라 RLS를 우회하므로
-- 이 정책은 authenticated 사용자의 직접 INSERT만 차단 목적으로 제거.
-- anon/authenticated 의 직접 INSERT는 허용하지 않는다.

-- ── 11.2 알림 자동 생성 트리거 (like / comment / follow) ──────────────────
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_event_key
    ON notifications(event_key)
    WHERE event_key IS NOT NULL;

CREATE OR REPLACE FUNCTION notification_type_preference_enabled(
    p_user_id UUID,
    p_type TEXT
)
RETURNS BOOLEAN AS $$
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
    FROM notification_preferences
    WHERE user_id = p_user_id;

    RETURN COALESCE(v_enabled, FALSE);
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION create_notification(
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
RETURNS UUID AS $$
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

    IF NOT notification_type_preference_enabled(p_user_id, p_type) THEN
        RETURN NULL;
    END IF;

    INSERT INTO notifications (
        user_id, sender_id, type, title, body, post_id, comment_id,
        data, read, is_sent, event_key
    )
    VALUES (
        p_user_id, p_sender_id, p_type, p_title, p_body, p_post_id,
        p_comment_id,
        COALESCE(p_data, '{}'::JSONB) || jsonb_build_object('type', p_type),
        FALSE, FALSE, v_event_key
    )
    ON CONFLICT (event_key) WHERE event_key IS NOT NULL
    DO UPDATE SET event_key = EXCLUDED.event_key
    RETURNING id INTO v_notification_id;

    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE
    v_post_author_id UUID;
    v_sender_name TEXT;
BEGIN
    -- 알림 INSERT 실패해도 본 INSERT(likes) 는 성공하도록 EXCEPTION 핸들링
    BEGIN
        SELECT author_id INTO v_post_author_id FROM posts WHERE id = NEW.post_id;
        IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
            RETURN NEW;
        END IF;
        SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.user_id;

        PERFORM create_notification(
            p_user_id := v_post_author_id,
            p_sender_id := NEW.user_id,
            p_type := 'like',
            p_title := '새로운 좋아요',
            p_body := v_sender_name || '님이 회원님의 게시글을 좋아합니다.',
            p_post_id := NEW.post_id,
            p_data := jsonb_build_object(
                'post_id', NEW.post_id::text,
                'sender_id', NEW.user_id::text,
                'sender_name', v_sender_name
            ),
            p_event_key := 'like:' || NEW.id::text
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'notify_on_like error: %', SQLERRM;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_on_like ON likes;
CREATE TRIGGER trigger_notify_on_like
    AFTER INSERT ON likes FOR EACH ROW EXECUTE FUNCTION notify_on_like();

CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_post_author_id UUID;
    v_sender_name TEXT;
    v_preview TEXT;
BEGIN
    -- 알림 INSERT 실패해도 본 INSERT(comments) 는 성공하도록 EXCEPTION 핸들링
    BEGIN
        -- BUG 수정: comments 테이블은 user_id 가 아니라 author_id 컬럼 사용
        SELECT author_id INTO v_post_author_id FROM posts WHERE id = NEW.post_id;
        IF v_post_author_id IS NULL OR v_post_author_id = NEW.author_id THEN
            RETURN NEW;
        END IF;
        SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.author_id;

        v_preview := LEFT(COALESCE(NEW.content, ''), 50);
        IF LENGTH(COALESCE(NEW.content, '')) > 50 THEN
            v_preview := v_preview || '...';
        END IF;

        PERFORM create_notification(
            p_user_id := v_post_author_id,
            p_sender_id := NEW.author_id,
            p_type := 'comment',
            p_title := '새로운 댓글',
            p_body := v_sender_name || ': ' || v_preview,
            p_post_id := NEW.post_id,
            p_comment_id := NEW.id,
            p_data := jsonb_build_object(
                'post_id', NEW.post_id::text,
                'comment_id', NEW.id::text,
                'sender_id', NEW.author_id::text,
                'sender_name', v_sender_name
            ),
            p_event_key := 'comment:' || NEW.id::text
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'notify_on_comment error: %', SQLERRM;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
    AFTER INSERT ON comments FOR EACH ROW EXECUTE FUNCTION notify_on_comment();

CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    -- 알림 INSERT 실패해도 본 INSERT(follows) 는 성공하도록 EXCEPTION 핸들링
    BEGIN
        IF NEW.follower_id = NEW.following_id THEN
            RETURN NEW;
        END IF;
        SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.follower_id;

        PERFORM create_notification(
            p_user_id := NEW.following_id,
            p_sender_id := NEW.follower_id,
            p_type := 'follow',
            p_title := '새로운 팔로워',
            p_body := v_sender_name || '님이 회원님을 팔로우하기 시작했어요.',
            p_data := jsonb_build_object(
                'sender_id', NEW.follower_id::text,
                'sender_name', v_sender_name
            ),
            p_event_key := 'follow:' || NEW.id::text
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'notify_on_follow error: %', SQLERRM;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_on_follow ON follows;
CREATE TRIGGER trigger_notify_on_follow
    AFTER INSERT ON follows FOR EACH ROW EXECUTE FUNCTION notify_on_follow();

-- ── 11.3 user_blocks 헬퍼 (RLS + RPC) ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

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

CREATE OR REPLACE FUNCTION get_blocked_user_ids(p_user_id UUID)
RETURNS TABLE(blocked_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT ub.blocked_id
    FROM user_blocks ub
    WHERE ub.blocker_id = p_user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION get_blocked_user_ids(UUID) FROM anon;

CREATE OR REPLACE FUNCTION is_mutually_blocked(p_user_a UUID, p_user_b UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_blocks
        WHERE (blocker_id = p_user_a AND blocked_id = p_user_b)
           OR (blocker_id = p_user_b AND blocked_id = p_user_a)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION is_mutually_blocked(UUID, UUID) FROM anon;

-- ── 11.4 notification_preferences (사용자별 알림 설정) ────────────────────
CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled_push BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_like BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_comment BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_follow BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_mention BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_system BOOLEAN DEFAULT TRUE NOT NULL,
    enabled_health_alert BOOLEAN DEFAULT TRUE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION touch_notification_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS trigger_touch_notif_prefs ON notification_preferences;
CREATE TRIGGER trigger_touch_notif_prefs
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION touch_notification_preferences_updated_at();

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notif_prefs_select_own ON notification_preferences;
CREATE POLICY notif_prefs_select_own ON notification_preferences
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS notif_prefs_insert_own ON notification_preferences;
CREATE POLICY notif_prefs_insert_own ON notification_preferences
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS notif_prefs_update_own ON notification_preferences;
CREATE POLICY notif_prefs_update_own ON notification_preferences
    FOR UPDATE USING (user_id = auth.uid());

-- 사용자 생성 시 기본 preferences 자동 생성
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION create_default_notification_preferences() FROM anon, authenticated;

DROP TRIGGER IF EXISTS trigger_create_notif_prefs ON users;
CREATE TRIGGER trigger_create_notif_prefs
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- 기존 사용자 backfill
INSERT INTO notification_preferences (user_id)
SELECT id FROM users
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- PART 12: 함수 권한 강화 (anon 역할 EXECUTE 차단)
-- ============================================================================
-- anon(비로그인) 사용자가 SECURITY DEFINER 함수를 직접 호출하지 못하도록 제한.
-- 트리거 전용 함수, 인증 필요 쓰기 함수, 민감 조회 함수 포함.

-- 쓰기 카운터 함수 (트리거 전용 또는 authenticated 전용)
REVOKE EXECUTE ON FUNCTION increment_likes_count() FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_likes_count() FROM anon;
REVOKE EXECUTE ON FUNCTION increment_comments_count() FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_comments_count() FROM anon;
REVOKE EXECUTE ON FUNCTION increment_comment_likes_count() FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_comment_likes_count() FROM anon;
REVOKE EXECUTE ON FUNCTION increment_post_likes(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_post_likes(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION increment_post_comments(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_post_comments(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION increment_comment_likes(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_comment_likes(UUID) FROM anon;

-- 포인트/퀘스트 함수 (authenticated 전용)
-- 세션1 1-B: 2-파라미터 오버로드 제거됨(모호성 해소) → 해당 REVOKE 라인도 제거.
-- 4-파라미터 단일 함수만 남으며 anon EXECUTE 차단.
REVOKE EXECUTE ON FUNCTION increment_user_points(UUID, INTEGER, TEXT, TEXT) FROM anon;

-- 계정/게시물 삭제 함수 (authenticated 전용)
-- delete_user_account() 는 G-1 마이그레이션에서 DROP됨 (soft delete로 대체)
REVOKE EXECUTE ON FUNCTION request_account_deletion() FROM anon, public;
REVOKE EXECUTE ON FUNCTION restore_my_account() FROM anon, public;
GRANT EXECUTE ON FUNCTION request_account_deletion() TO authenticated;
GRANT EXECUTE ON FUNCTION restore_my_account() TO authenticated;
REVOKE EXECUTE ON FUNCTION soft_delete_post(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION soft_delete_comment(UUID) FROM anon;

-- 채팅 함수 (authenticated 전용)
REVOKE EXECUTE ON FUNCTION get_total_unread_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_room_unread_count(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION is_room_member(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION find_direct_chat(UUID, UUID) FROM anon;

-- 알림 트리거 함수 (직접 호출 불필요)
REVOKE EXECUTE ON FUNCTION notify_on_like() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION notify_on_comment() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION notify_on_follow() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION handle_new_user() FROM anon, authenticated;
REVOKE ALL ON FUNCTION notification_type_preference_enabled(UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION create_notification(
    UUID, UUID, TEXT, TEXT, TEXT, UUID, UUID, JSONB, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION create_notification(
    UUID, UUID, TEXT, TEXT, TEXT, UUID, UUID, JSONB, TEXT
) TO service_role;

-- 개인 데이터 조회 함수 (authenticated 전용)
REVOKE EXECUTE ON FUNCTION get_user_pets(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_user_streak(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_feed_posts(UUID, INTEGER, INTEGER) FROM anon;
REVOKE EXECUTE ON FUNCTION get_emotion_statistics(UUID, UUID, INTEGER) FROM anon;
REVOKE EXECUTE ON FUNCTION get_emotion_timeline(UUID, INTEGER) FROM anon;


-- ============================================================================
-- PART 13: breeds 테이블 (D-4 이후 추가)
-- 반려동물 품종 정보 — 강아지/고양이 선택 UI에 사용
-- ============================================================================

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

DROP POLICY IF EXISTS "breeds: 전체 조회 허용" ON public.breeds;
CREATE POLICY "breeds: 전체 조회 허용"
  ON public.breeds FOR SELECT USING (true);

-- 보안(세션1 1-C): breeds는 읽기 전용 마스터 데이터.
-- 쓰기(INSERT/UPDATE/DELETE)는 service_role(SQL Editor)로만 수행한다.
-- 기존에 적용된 authenticated 쓰기 정책이 있으면 제거(재실행 멱등). CREATE는 하지 않음.
DROP POLICY IF EXISTS "breeds: 인증 사용자 삽입" ON public.breeds;
DROP POLICY IF EXISTS "breeds: 인증 사용자 수정" ON public.breeds;
DROP POLICY IF EXISTS "breeds: 인증 사용자 삭제" ON public.breeds;

CREATE INDEX IF NOT EXISTS idx_breeds_species       ON public.breeds(species);
CREATE INDEX IF NOT EXISTS idx_breeds_name_ko       ON public.breeds(name_ko);
CREATE INDEX IF NOT EXISTS idx_breeds_is_active     ON public.breeds(is_active);
CREATE INDEX IF NOT EXISTS idx_breeds_display_order ON public.breeds(display_order);

DROP TRIGGER IF EXISTS trg_breeds_updated_at ON public.breeds;
CREATE TRIGGER trg_breeds_updated_at
  BEFORE UPDATE ON public.breeds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 강아지 품종 초기 데이터
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order)
VALUES
  ('dog', '말티즈',           'Maltese',             'small',  '작고 귀여운 장모종 강아지',           1),
  ('dog', '푸들',             'Poodle',              'small',  '영리하고 사교적인 견종',              2),
  ('dog', '치와와',           'Chihuahua',           'small',  '세계에서 가장 작은 견종',             3),
  ('dog', '포메라니안',       'Pomeranian',          'small',  '폭신한 털을 가진 활발한 강아지',       4),
  ('dog', '시바견',           'Shiba Inu',           'medium', '일본 원산의 독립적인 성격의 견종',     5),
  ('dog', '비글',             'Beagle',              'medium', '사냥개 출신의 호기심 많은 견종',       6),
  ('dog', '웰시코기',         'Welsh Corgi',         'medium', '짧은 다리와 긴 몸통이 특징',          7),
  ('dog', '골든 리트리버',    'Golden Retriever',    'large',  '온순하고 충성스러운 대형견',           8),
  ('dog', '래브라도 리트리버','Labrador Retriever',  'large',  '가장 인기있는 가족견',                9),
  ('dog', '진돗개',           'Jindo',               'medium', '한국 토종견으로 충성심이 강함',        10),
  ('dog', '요크셔테리어',     'Yorkshire Terrier',   'small',  '작지만 용감한 테리어 품종',           11),
  ('dog', '시츄',             'Shih Tzu',            'small',  '중국 원산의 애완견',                 12),
  ('dog', '닥스훈트',         'Dachshund',           'small',  '긴 몸과 짧은 다리가 특징',           13),
  ('dog', '불독',             'Bulldog',             'medium', '주름진 얼굴과 근육질 체형',           14),
  ('dog', '보더콜리',         'Border Collie',       'medium', '가장 영리한 견종 중 하나',            15)
ON CONFLICT (species, name_ko) DO NOTHING;

-- 고양이 품종 초기 데이터
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order)
VALUES
  ('cat', '코리안 숏헤어',  'Korean Shorthair',   'medium', '한국 토종 고양이',                1),
  ('cat', '페르시안',       'Persian',            'medium', '긴 털과 납작한 얼굴이 특징',       2),
  ('cat', '러시안 블루',    'Russian Blue',       'medium', '은색 푸른 털을 가진 고양이',       3),
  ('cat', '샴',            'Siamese',             'medium', '독특한 무늬와 파란 눈이 특징',     4),
  ('cat', '스코티시 폴드',  'Scottish Fold',      'medium', '접힌 귀가 특징인 고양이',          5),
  ('cat', '먼치킨',         'Munchkin',           'small',  '짧은 다리가 특징인 고양이',        6),
  ('cat', '아메리칸 숏헤어','American Shorthair', 'medium', '튼튼하고 건강한 품종',            7),
  ('cat', '메인쿤',         'Maine Coon',         'large',  '가장 큰 고양이 품종 중 하나',      8),
  ('cat', '브리티시 숏헤어','British Shorthair',  'medium', '둥근 얼굴과 두꺼운 털',           9),
  ('cat', '뱅갈',           'Bengal',             'medium', '야생 표범 무늬를 가진 고양이',     10),
  ('cat', '노르웨이 숲',    'Norwegian Forest',   'large',  '긴 털을 가진 북유럽 원산 고양이',  11),
  ('cat', '랙돌',           'Ragdoll',            'large',  '안으면 인형처럼 축 늘어지는 성격', 12),
  ('cat', '아비시니안',     'Abyssinian',         'medium', '날씬하고 우아한 체형',             13),
  ('cat', '터키시 앙고라',  'Turkish Angora',     'medium', '우아하고 긴 털을 가진 고양이',     14),
  ('cat', '스핑크스',       'Sphynx',             'medium', '털이 없는 독특한 품종',            15)
ON CONFLICT (species, name_ko) DO NOTHING;

-- search_breeds RPC
CREATE OR REPLACE FUNCTION search_breeds(
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

REVOKE EXECUTE ON FUNCTION search_breeds(varchar, text, integer) FROM anon;

CREATE OR REPLACE FUNCTION get_all_breeds(p_species varchar(10) DEFAULT NULL)
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


-- ============================================================================
-- PART 14: user_devices D-4 스키마 보강
-- is_active 컬럼 추가 + UNIQUE 제약 (user_id, fcm_token) → (fcm_token) 변경
-- ============================================================================

-- is_active 컬럼 추가 (없으면)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_devices' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE user_devices ADD COLUMN is_active boolean NOT NULL DEFAULT true;
  END IF;
END $$;

-- UNIQUE 제약 변경: (user_id, fcm_token) → (fcm_token)
-- 같은 기기가 다른 유저로 재로그인할 때 충돌 없이 upsert 가능
DO $$
BEGIN
  -- 기존 제약 제거 (이름이 다를 수 있으므로 pg_constraint로 조회)
  IF EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'user_devices'
      AND c.contype = 'u'
      AND array_to_string(ARRAY(
        SELECT a.attname FROM pg_attribute a
        WHERE a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        ORDER BY a.attnum
      ), ',') = 'fcm_token,user_id'
  ) THEN
    EXECUTE (
      SELECT 'ALTER TABLE user_devices DROP CONSTRAINT ' || c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE t.relname = 'user_devices' AND c.contype = 'u'
        AND array_to_string(ARRAY(
          SELECT a.attname FROM pg_attribute a
          WHERE a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
          ORDER BY a.attnum
        ), ',') = 'fcm_token,user_id'
    );
  END IF;

  -- 새 UNIQUE(fcm_token) 추가 (없으면)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'user_devices'
      AND c.contype = 'u'
      AND array_to_string(ARRAY(
        SELECT a.attname FROM pg_attribute a
        WHERE a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        ORDER BY a.attnum
      ), ',') = 'fcm_token'
  ) THEN
    ALTER TABLE user_devices ADD CONSTRAINT user_devices_fcm_token_key UNIQUE (fcm_token);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_devices_is_active ON user_devices(is_active);


-- ============================================================================
-- PART 15: FCM 푸시 알림 트리거 (D-4)
-- notifications INSERT 시 Edge Function send-push-notification 비동기 호출
-- 선행 조건: pg_net 활성화 + PART 16 ALTER DATABASE 설정 완료
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _supabase_url  text;
  _service_key   text;
BEGIN
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_key  := current_setting('app.settings.service_role_key', true);

  IF _supabase_url IS NULL OR _service_key IS NULL THEN
    RAISE WARNING 'notify_push_on_notification: app.settings 미설정 — PART 16 실행 필요';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := _supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _service_key
    ),
    body    := jsonb_build_object('notification_id', NEW.id::text)
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

REVOKE EXECUTE ON FUNCTION public.notify_push_on_notification() FROM anon, authenticated;


-- ============================================================================
-- PART 16: D-4 사후 설정 (Supabase Dashboard에서 실행)
-- ============================================================================
-- pg_net 트리거 활성화 전 반드시 실행.
-- YOUR_PROJECT_REF / YOUR_SERVICE_ROLE_KEY 를 실제 값으로 교체 후 실행.

-- ALTER DATABASE postgres
--   SET "app.settings.supabase_url" = 'https://YOUR_PROJECT_REF.supabase.co';

-- ALTER DATABASE postgres
--   SET "app.settings.service_role_key" = 'YOUR_SERVICE_ROLE_KEY';


-- ============================================================================
-- PART 17: 관리자 초기 게시글 Seed Data
-- ============================================================================
-- 주의: 아래는 주석 처리됨. 관리자 계정(auth.users) 생성 후 UUID 교체하여 실행.

/*
INSERT INTO users (id, display_name, provider, is_onboarding_completed)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    '관리자', 'email', true
)
ON CONFLICT (id) DO UPDATE SET display_name = '관리자';

INSERT INTO posts (author_id, type, content, image_urls, tags, likes_count, comments_count)
VALUES
('00000000-0000-0000-0000-000000000001', 'text',
 '반려동물 치아 관리 필수 가이드\n\n1. 매일 양치질: 반려동물 전용 칫솔과 치약을 사용하세요\n2. 치석 제거: 6개월~1년 주기로 스케일링 권장\n3. 이상 신호: 구취, 침흘림, 잇몸 출혈 시 즉시 병원 방문',
 '{}', ARRAY['magazine', 'health'], 0, 0),
('00000000-0000-0000-0000-000000000001', 'text',
 '기본 복종 훈련 시작하기\n\n1. 앉아 (Sit): 간식을 코 위로 올려 자연스럽게 앉게 유도\n2. 기다려 (Stay): 손바닥을 보여주며 기다려 명령\n3. 이리와 (Come): 긴 줄을 이용해 부르면 오는 연습',
 '{}', ARRAY['magazine', 'training'], 0, 0),
('00000000-0000-0000-0000-000000000001', 'text',
 '예방접종 가이드\n\n🐶 강아지: 6~8주 DHPPL 1차 → 10~12주 2차 → 14~16주 3차+광견병 → 매년 추가\n🐱 고양이: 6~8주 FVRCP 1차 → 10~12주 2차 → 14~16주 3차+광견병 → 매년 추가',
 '{}', ARRAY['health'], 0, 0),
('00000000-0000-0000-0000-000000000001', 'text',
 '분리불안 극복 훈련 팁\n\n1단계: 잠깐 외출 연습 (30초→1분→5분 점진적 증가)\n2단계: 외출 전 과도한 인사 금지\n3단계: 귀가 시 흥분하지 않게 (5분 후 인사)',
 '{}', ARRAY['training'], 0, 0);
*/

-- ============================================================================
-- PART 18: Schema Migrations (점진적 컬럼 추가)
-- ============================================================================
-- 기존 PART 10이 포인트/퀘스트 용도로 이미 점유 중이므로 PART 18로 신설.
-- 각 마이그레이션은 날짜·목적 주석을 머리에 두고 IF NOT EXISTS 가드 필수.

-- 2026-05-20: emotion 분석 시 사용자 입력 컨텍스트 추가
-- AI 분석 프롬프트에 주입되는 보호자 입력 정보 (장소·상황·특이사항)
ALTER TABLE emotion_history
ADD COLUMN IF NOT EXISTS context_note TEXT;

COMMENT ON COLUMN emotion_history.context_note IS
  '분석 시점 보호자 입력 컨텍스트. AI 프롬프트 주입용. memo와 별도 (memo는 분석 후 회고용).';

-- 2026-06-15: posts 라이브 컬럼 동기화 + 카테고리 컬럼화
-- 이 setup.sql의 posts 정의(PART 3)와 라이브 DB가 어긋나 있어, 라이브에 이미
-- 존재하는 컬럼(post_type, image_urls)을 IF NOT EXISTS로 명문화한다.
-- 새 스키마 변경은 category 추가뿐(상세·백필은 migrations/posts_category.sql).
ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type TEXT DEFAULT 'photo';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS category TEXT;

COMMENT ON COLUMN posts.post_type IS
  '글 종류: photo(사진) / community(Q&A 등 텍스트) / emotion(감정 분석 공유).';
COMMENT ON COLUMN posts.image_urls IS
  '다중 이미지 URL 배열. 레거시 image_url(단일) 대체.';
COMMENT ON COLUMN posts.category IS
  '커뮤니티(Q&A) 글의 카테고리: health/training/food/life/qa. 미분류는 NULL.';

CREATE INDEX IF NOT EXISTS idx_posts_category
  ON posts(category) WHERE deleted_at IS NULL;


-- ============================================================================
-- PART 19: 펫 뉴스 (F1) — 반자동 수집/검수/링크아웃
-- ============================================================================
-- 외부 RSS를 Edge Function(collect-news)이 매일 09:00 KST 수집 → pending 적재.
-- 운영자가 대시보드에서 published 토글 → 앱은 published만 노출(원문 링크아웃).
-- 저작권: 제목·발행일·출처·원문 링크만 저장. 본문/요약/썸네일 컬럼 없음.
-- (상세·검증 내역은 supabase/migrations/F1_pet_news.sql 참조)

-- 19-1) 수집 소스 목록
create table if not exists public.news_sources (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,                 -- 매체명(출처 표시용)
  rss_url     text not null unique,          -- RSS 피드 URL
  is_active   boolean not null default true, -- 수집 on/off
  created_at  timestamptz not null default now()
);

comment on table public.news_sources is '펫 뉴스 RSS 수집 소스';

-- 19-2) 수집 기사
create table if not exists public.news_articles (
  id            uuid primary key default gen_random_uuid(),
  source_id     uuid references public.news_sources(id) on delete set null,
  source_name   text not null,                -- 출처(매체명) — 표시용 비정규화
  title         text not null,                -- 기사 제목
  link          text not null unique,         -- 원문 URL (중복 방지 키)
  published_at  timestamptz,                  -- 원문 발행일(파싱)
  status        text not null default 'pending'
                check (status in ('pending','published','rejected')),
  collected_at  timestamptz not null default now(),
  reviewed_at   timestamptz                   -- 검수(발행/반려) 시각
);

comment on table public.news_articles is '수집된 펫 뉴스(반자동 검수). 본문 미저장 → 링크아웃 전용';

create index if not exists idx_news_articles_status_pub
  on public.news_articles (status, published_at desc);

-- 19-3) RLS: 앱은 발행분만 SELECT. INSERT/UPDATE는 정책 없음(service_role 전용).
alter table public.news_articles enable row level security;
alter table public.news_sources  enable row level security;

drop policy if exists "news read published" on public.news_articles;
create policy "news read published"
  on public.news_articles
  for select
  using (status = 'published');

-- 19-4) 소스 시드 (작업0 검증, 2026-06-08)
insert into public.news_sources (name, rss_url, is_active) values
  ('데일리벳',         'https://www.dailyvet.co.kr/feed',                        true),
  ('뉴스펫',           'https://www.newspet.co.kr/rss/allArticle.xml',           true),
  ('구글뉴스(반려동물)', 'https://news.google.com/rss/search?q=%EB%B0%98%EB%A0%A4%EB%8F%99%EB%AC%BC&hl=ko&gl=KR&ceid=KR:ko', true),
  ('한국반려동물신문', 'http://www.pet-news.or.kr/rss/allArticle.xml',           false)  -- 휴면, 수집 제외
on conflict (rss_url) do nothing;
-- ================================================================
-- K1 BLOCK / PRIVACY CONTRACT (P2B synchronized final state)
-- ================================================================

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
DECLARE
  v_actor uuid := auth.uid();
  v_is_manager boolean := false;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF (
    NEW.id IS DISTINCT FROM OLD.id
    OR NEW.room_id IS DISTINCT FROM OLD.room_id
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.role IS DISTINCT FROM OLD.role
    OR NEW.joined_at IS DISTINCT FROM OLD.joined_at
  ) THEN
    RAISE EXCEPTION 'participant identity and role are immutable';
  END IF;

  IF v_actor = OLD.user_id THEN
    IF NOT OLD.is_active AND NEW.is_active THEN
      RAISE EXCEPTION 'participant reactivation requires a group manager';
    END IF;
    RETURN NEW;
  END IF;

  v_is_manager := private.can_manage_group_participants(
    OLD.room_id,
    v_actor
  );
  IF NOT v_is_manager THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;

  IF OLD.is_active = NEW.is_active
    AND NEW.last_read_at IS NOT DISTINCT FROM OLD.last_read_at
  THEN
    RETURN NEW;
  END IF;

  IF OLD.is_active
    OR NOT NEW.is_active
    OR NEW.last_read_at IS DISTINCT FROM OLD.last_read_at
    OR NOT private.user_is_active_internal(OLD.user_id)
  THEN
    RAISE EXCEPTION 'request not allowed';
  END IF;

  PERFORM private.lock_user_pair_internal(v_actor, OLD.user_id);
  IF private.mutually_blocked_internal(v_actor, OLD.user_id) THEN
    RAISE EXCEPTION 'request not allowed';
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
      IF NOT private.user_is_active_internal(NEW.following_id) THEN
        RAISE EXCEPTION 'request not allowed';
      END IF;
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
  WITH normalized_query AS (
    SELECT nullif(
      btrim(regexp_replace(btrim(coalesce(p_query, '')), '^@+', '')),
      ''
    ) AS value
  ),
  escaped_query AS (
    SELECT
      value,
      CASE
        WHEN value IS NULL THEN NULL
        ELSE replace(
          replace(replace(value, E'\\', E'\\\\'), '%', E'\\%'),
          '_',
          E'\\_'
        )
      END AS escaped
    FROM normalized_query
  )
  SELECT
         ub.blocked_id,
         CASE
           WHEN u.deleted_at IS NULL THEN u.display_name::text
           ELSE '탈퇴한 사용자'::text
         END AS display_name,
         CASE
           WHEN u.deleted_at IS NULL THEN u.username::text
           ELSE NULL::text
         END AS username,
         CASE
           WHEN u.deleted_at IS NULL THEN u.photo_url::text
           ELSE NULL::text
         END AS photo_url,
         ub.created_at AS blocked_at, ub.id AS block_id
  FROM public.user_blocks ub
  JOIN public.users u ON u.id = ub.blocked_id
  CROSS JOIN escaped_query q
  WHERE ub.blocker_id = auth.uid()
    AND (
      p_before_created_at IS NULL OR p_before_id IS NULL OR
      (ub.created_at, ub.id) < (p_before_created_at, p_before_id)
    )
    AND (
      q.value IS NULL
      OR (
        CASE
          WHEN u.deleted_at IS NULL THEN u.display_name::text
          ELSE '탈퇴한 사용자'::text
        END
      ) ILIKE '%' || q.escaped || '%' ESCAPE E'\\'
      OR (
        u.deleted_at IS NULL
        AND u.username ILIKE '%' || q.escaped || '%' ESCAPE E'\\'
      )
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
REVOKE SELECT ON TABLE public.users FROM PUBLIC, anon, authenticated;
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

-- B0 privacy guard: 기존 PERMISSIVE K1 정책과 AND 결합해 private/NULL을
-- 작성자 외 사용자에게 노출하지 않는다.
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
DROP POLICY IF EXISTS chat_participants_update_self_or_manager ON public.chat_participants;
CREATE POLICY chat_participants_update_self_or_manager ON public.chat_participants
FOR UPDATE TO authenticated
USING (
  auth.uid() = user_id
  OR private.can_manage_group_participants(room_id, auth.uid())
)
WITH CHECK (
  auth.uid() = user_id
  OR private.can_manage_group_participants(room_id, auth.uid())
);

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

BEGIN;

-- ================================================================
-- L2 ACCOUNT DELETION ACCESS GUARD
-- ================================================================
-- public.users 본인 조회와 restore_my_account()는 복구 안내를 위해 유지한다.
-- 그 외 사용자 소유 데이터는 deleted_at 기록 직후 남은 access token으로도
-- 읽거나 변경할 수 없도록 restrictive 정책을 추가한다.
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

BEGIN;

-- ================================================================
-- M1 SELECTED PET CONTRACT (auth.uid()-anchored, no caller user id)
-- ================================================================
CREATE OR REPLACE FUNCTION public.get_my_selected_pet_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.selected_pet_id
  FROM public.users AS u
  WHERE u.id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.set_my_selected_pet_id(p_pet_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_pet_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.pets AS p
    WHERE p.id = p_pet_id
      AND p.user_id = v_actor
  ) THEN
    RAISE EXCEPTION 'pet is not owned by caller' USING ERRCODE = '42501';
  END IF;

  UPDATE public.users
  SET selected_pet_id = p_pet_id,
      updated_at = now()
  WHERE id = v_actor;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN p_pet_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_selected_pet_id()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_my_selected_pet_id(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_selected_pet_id()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_selected_pet_id(uuid)
  TO authenticated;

COMMIT;
