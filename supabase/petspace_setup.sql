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
    followers UUID[] DEFAULT ARRAY[]::UUID[]
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    admin_notes TEXT,
    CHECK (
        reported_user_id IS NOT NULL OR
        reported_post_id IS NOT NULL OR
        reported_comment_id IS NOT NULL
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
CREATE OR REPLACE FUNCTION increment_likes_count()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_likes_count()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ language 'plpgsql';

-- 댓글 카운터
CREATE OR REPLACE FUNCTION increment_comments_count()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_comments_count()
RETURNS TRIGGER
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

-- M-F2: comment_likes 트리거용 카운트 함수
CREATE OR REPLACE FUNCTION increment_comment_likes_count()
RETURNS TRIGGER
SET search_path = public
AS $$
BEGIN
    UPDATE comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_comment_likes_count()
RETURNS TRIGGER
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
BEGIN
    BEGIN
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
    AND p.hashtags IS NOT NULL
    AND p.created_at >= NOW() - (days_ago || ' days')::INTERVAL
    GROUP BY unnest(p.hashtags)
    ORDER BY post_count DESC
    LIMIT limit_count;
END;
$$;

-- 계정 삭제 (auth.users + public.users 모두 삭제)
-- SECURITY DEFINER로 실행되어 auth.users 삭제 가능
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- public.users 삭제 (CASCADE로 연관 데이터 자동 삭제)
    DELETE FROM public.users WHERE id = auth.uid();
    -- auth.users 삭제
    DELETE FROM auth.users WHERE id = auth.uid();
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
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON users;
CREATE POLICY "Authenticated users can view all profiles" ON users
    FOR SELECT TO authenticated
    USING (true);

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

-- Posts (soft delete 반영)
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (deleted_at IS NULL);

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

-- Comments (soft delete 반영)
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (deleted_at IS NULL);

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
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own pet health records" ON health_records;
CREATE POLICY "Users can insert own pet health records" ON health_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own pet health records" ON health_records;
CREATE POLICY "Users can update own pet health records" ON health_records
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own pet health records" ON health_records;
CREATE POLICY "Users can delete own pet health records" ON health_records
    FOR DELETE USING (auth.uid() = user_id);

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

-- 포인트 잔액 뷰
CREATE OR REPLACE VIEW user_points AS
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
BEGIN
  INSERT INTO point_transactions (user_id, amount, type, description)
  VALUES (p_user_id, p_points, p_type, p_description);
END;
$$;

-- ================================================================
-- 건강 분석 히스토리 (AI 건강분석 결과 저장)
-- 추가: 2026-04-16
-- ================================================================

CREATE TABLE IF NOT EXISTS health_history (
  id                 BIGSERIAL PRIMARY KEY,
  user_id            UUID REFERENCES auth.users NOT NULL,
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
CREATE POLICY notifications_insert_service ON notifications
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ── 11.2 알림 자동 생성 트리거 (like / comment / follow) ──────────────────
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE
    v_post_author_id UUID;
    v_sender_name TEXT;
BEGIN
    SELECT author_id INTO v_post_author_id FROM posts WHERE id = NEW.post_id;
    IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
        RETURN NEW;
    END IF;
    SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.user_id;

    INSERT INTO notifications (user_id, sender_id, type, title, body, post_id, data, is_sent)
    VALUES (
        v_post_author_id, NEW.user_id, 'like',
        '새로운 좋아요',
        v_sender_name || '님이 회원님의 게시글을 좋아합니다.',
        NEW.post_id,
        jsonb_build_object('post_id', NEW.post_id::text, 'sender_id', NEW.user_id::text),
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    SELECT author_id INTO v_post_author_id FROM posts WHERE id = NEW.post_id;
    IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
        RETURN NEW;
    END IF;
    SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.user_id;

    v_preview := LEFT(COALESCE(NEW.content, ''), 50);
    IF LENGTH(COALESCE(NEW.content, '')) > 50 THEN
        v_preview := v_preview || '...';
    END IF;

    INSERT INTO notifications (user_id, sender_id, type, title, body, post_id, comment_id, data, is_sent)
    VALUES (
        v_post_author_id, NEW.user_id, 'comment',
        '새로운 댓글',
        v_sender_name || ': ' || v_preview,
        NEW.post_id, NEW.id,
        jsonb_build_object(
            'post_id', NEW.post_id::text,
            'comment_id', NEW.id::text,
            'sender_id', NEW.user_id::text
        ),
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
    AFTER INSERT ON comments FOR EACH ROW EXECUTE FUNCTION notify_on_comment();

CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    IF NEW.follower_id = NEW.following_id THEN
        RETURN NEW;
    END IF;
    SELECT COALESCE(display_name, '사용자') INTO v_sender_name FROM users WHERE id = NEW.follower_id;

    INSERT INTO notifications (user_id, sender_id, type, title, body, data, is_sent)
    VALUES (
        NEW.following_id, NEW.follower_id, 'follow',
        '새로운 팔로워',
        v_sender_name || '님이 회원님을 팔로우하기 시작했어요.',
        jsonb_build_object('sender_id', NEW.follower_id::text),
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_create_notif_prefs ON users;
CREATE TRIGGER trigger_create_notif_prefs
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- 기존 사용자 backfill
INSERT INTO notification_preferences (user_id)
SELECT id FROM users
ON CONFLICT (user_id) DO NOTHING;
