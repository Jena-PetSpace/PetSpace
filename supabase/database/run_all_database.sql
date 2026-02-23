-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR UNIQUE NOT NULL,
    display_name VARCHAR(50),
    username VARCHAR(30) UNIQUE,
    photo_url TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settings JSONB DEFAULT '{}'::jsonb,
    -- 온보딩 및 소셜 기능 컬럼
    is_onboarding_completed BOOLEAN DEFAULT FALSE,
    pets UUID[] DEFAULT ARRAY[]::UUID[],
    following UUID[] DEFAULT ARRAY[]::UUID[],
    followers UUID[] DEFAULT ARRAY[]::UUID[]
);

-- Pets table
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

-- Posts table
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    emotion_analysis JSONB NOT NULL,
    caption TEXT,
    hashtags TEXT[],
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emotion history table
CREATE TABLE IF NOT EXISTS emotion_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    emotion_analysis JSONB NOT NULL,
    memo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comments table
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Follows table
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id)
);

-- Likes table
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- Notifications table (additional for push notifications)
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

-- User devices table (for FCM tokens)
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- =========================================
-- ADD MISSING COLUMNS FIRST (BEFORE INDEXES!)
-- =========================================
-- 기존 테이블에 컬럼이 없을 경우를 대비해 인덱스 생성 전에 먼저 추가

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pets UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS following UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE users ADD COLUMN IF NOT EXISTS followers UUID[] DEFAULT ARRAY[]::UUID[];

-- 컬럼 설명 추가
COMMENT ON COLUMN users.is_onboarding_completed IS '온보딩 프로세스 완료 여부';
COMMENT ON COLUMN users.pets IS '사용자가 소유한 반려동물 UUID 배열';
COMMENT ON COLUMN users.following IS '사용자가 팔로우하는 사용자 UUID 배열';
COMMENT ON COLUMN users.followers IS '사용자를 팔로우하는 사용자 UUID 배열';

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON pets(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_pet_id ON posts(pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emotion_history_user_id ON emotion_history(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_pet_id ON emotion_history(pet_id);
CREATE INDEX IF NOT EXISTS idx_emotion_history_created_at ON emotion_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_author_id ON comments(author_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
-- Composite index for efficient "mark all as read" queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, read);
-- Indexes for users table array columns
CREATE INDEX IF NOT EXISTS idx_users_pets ON users USING GIN(pets);
CREATE INDEX IF NOT EXISTS idx_users_following ON users USING GIN(following);
CREATE INDEX IF NOT EXISTS idx_users_followers ON users USING GIN(followers);
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users(is_onboarding_completed);

-- JSONB indexes for emotion analysis queries
CREATE INDEX IF NOT EXISTS idx_posts_emotion_analysis ON posts USING GIN(emotion_analysis);
CREATE INDEX IF NOT EXISTS idx_emotion_history_emotion_analysis ON emotion_history USING GIN(emotion_analysis);

-- Text search index for hashtags
CREATE INDEX IF NOT EXISTS idx_posts_hashtags ON posts USING GIN(hashtags);

-- Functions for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updating timestamps
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_devices_updated_at ON user_devices;
CREATE TRIGGER update_user_devices_updated_at BEFORE UPDATE ON user_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Functions for maintaining counters
CREATE OR REPLACE FUNCTION increment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION increment_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION decrement_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ language 'plpgsql';

-- Triggers for maintaining counters
DROP TRIGGER IF EXISTS likes_count_increment ON likes;
CREATE TRIGGER likes_count_increment AFTER INSERT ON likes
    FOR EACH ROW EXECUTE FUNCTION increment_likes_count();

DROP TRIGGER IF EXISTS likes_count_decrement ON likes;
CREATE TRIGGER likes_count_decrement AFTER DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION decrement_likes_count();

DROP TRIGGER IF EXISTS comments_count_increment ON comments;
CREATE TRIGGER comments_count_increment AFTER INSERT ON comments
    FOR EACH ROW EXECUTE FUNCTION increment_comments_count();

DROP TRIGGER IF EXISTS comments_count_decrement ON comments;
CREATE TRIGGER comments_count_decrement AFTER DELETE ON comments
    FOR EACH ROW EXECUTE FUNCTION decrement_comments_count();

-- =========================================
-- Part 2: RLS Policies
-- =========================================

-- Enable Row Level Security on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Users table policies
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Pets table policies
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

-- Posts table policies
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
CREATE POLICY "Users can insert own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can update own posts" ON posts;
CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can delete own posts" ON posts;
CREATE POLICY "Users can delete own posts" ON posts
    FOR DELETE USING (auth.uid() = author_id);

-- Alternative policy for private posts (commented out for now)
/*
CREATE POLICY "Users can view public posts or posts from followed users" ON posts
    FOR SELECT USING (
        author_id IN (
            SELECT following_id FROM follows WHERE follower_id = auth.uid()
        ) OR author_id = auth.uid()
    );
*/

-- Emotion history table policies
DROP POLICY IF EXISTS "Users can only see own emotion history" ON emotion_history;
CREATE POLICY "Users can only see own emotion history" ON emotion_history
    FOR ALL USING (auth.uid() = user_id);

-- Comments table policies
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert comments" ON comments;
CREATE POLICY "Users can insert comments" ON comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can update own comments" ON comments;
CREATE POLICY "Users can update own comments" ON comments
    FOR UPDATE USING (auth.uid() = author_id);

DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
CREATE POLICY "Users can delete own comments" ON comments
    FOR DELETE USING (auth.uid() = author_id);

-- Follows table policies
DROP POLICY IF EXISTS "Users can view follows" ON follows;
CREATE POLICY "Users can view follows" ON follows
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can follow others" ON follows;
CREATE POLICY "Users can follow others" ON follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can unfollow others" ON follows;
CREATE POLICY "Users can unfollow others" ON follows
    FOR DELETE USING (auth.uid() = follower_id);

-- Likes table policies
DROP POLICY IF EXISTS "Users can view likes" ON likes;
CREATE POLICY "Users can view likes" ON likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can like posts" ON likes;
CREATE POLICY "Users can like posts" ON likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike posts" ON likes;
CREATE POLICY "Users can unlike posts" ON likes
    FOR DELETE USING (auth.uid() = user_id);

-- Notifications table policies
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- User devices table policies
DROP POLICY IF EXISTS "Users can manage own devices" ON user_devices;
CREATE POLICY "Users can manage own devices" ON user_devices
    FOR ALL USING (auth.uid() = user_id);

-- Create function to handle user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- 이메일 인증이 완료된 경우에만 users 테이블에 추가
    IF NEW.email_confirmed_at IS NOT NULL THEN
        INSERT INTO public.users (id, email, display_name, photo_url, is_onboarding_completed)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
            NEW.raw_user_meta_data->>'photo_url',
            FALSE
        )
        ON CONFLICT (id) DO NOTHING;  -- 이미 존재하면 무시
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger to automatically create user profile on signup
-- INSERT: 소셜 로그인 (즉시 인증됨)
-- UPDATE: 이메일 인증 완료 시
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    WHEN (NEW.email_confirmed_at IS NOT NULL)
    EXECUTE FUNCTION handle_new_user();

-- Drop existing functions first (return types changed)
DROP FUNCTION IF EXISTS get_user_pets(uuid);
DROP FUNCTION IF EXISTS get_feed_posts(uuid, integer, integer);

-- Create function to get user's pets
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
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.name, p.type, p.breed, p.birth_date, p.gender, p.avatar_url, p.created_at
    FROM pets p
    WHERE p.user_id = user_uuid
    ORDER BY p.created_at DESC;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Create function to get feed posts with user and pet information
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
        p.id,
        p.author_id,
        u.display_name as author_name,
        u.photo_url as author_photo,
        p.pet_id,
        pet.name as pet_name,
        pet.type as pet_type,
        p.image_url,
        p.emotion_analysis,
        p.caption,
        p.hashtags,
        p.likes_count,
        p.comments_count,
        p.created_at,
        EXISTS(SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = user_uuid) as is_liked
    FROM posts p
    LEFT JOIN users u ON p.author_id = u.id
    LEFT JOIN pets pet ON p.pet_id = pet.id
    WHERE p.author_id IN (
        SELECT following_id FROM follows WHERE follower_id = user_uuid
        UNION
        SELECT user_uuid -- Include user's own posts
    ) OR user_uuid IS NULL -- For public feed
    ORDER BY p.created_at DESC
    LIMIT limit_count OFFSET offset_count;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Create function to get emotion statistics
CREATE OR REPLACE FUNCTION get_emotion_statistics(
    user_uuid UUID,
    pet_uuid UUID DEFAULT NULL,
    days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    emotion VARCHAR,
    avg_score NUMERIC,
    count BIGINT
) AS $$
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
$$ language 'plpgsql' SECURITY DEFINER;

-- =========================================
-- Part 3: Social Features Extension
-- =========================================

-- Social Features Extension Migration
-- 기존 001_initial_schema.sql에 추가 테이블 생성
-- (follows, likes, notifications는 이미 존재하므로 제외)

-- =====================================================
-- 1. COMMENT_LIKES 테이블 (댓글 좋아요)
-- =====================================================
CREATE TABLE IF NOT EXISTS comment_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_id ON comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_created_at ON comment_likes(created_at DESC);

-- =====================================================
-- 2. REPORTS 테이블 (신고)
-- =====================================================
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

CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_post_id ON reports(reported_post_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_comment_id ON reports(reported_comment_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

-- Reports updated_at 트리거
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_reports_updated_at ON reports;
CREATE TRIGGER trigger_update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION update_reports_updated_at();

-- =====================================================
-- 3. USER_BLOCKS 테이블 (사용자 차단)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker_id ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_id ON user_blocks(blocked_id);

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '================================================';
  RAISE NOTICE '소셜 기능 확장 마이그레이션 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '생성된 테이블:';
  RAISE NOTICE '  - comment_likes (댓글 좋아요)';
  RAISE NOTICE '  - reports (신고)';
  RAISE NOTICE '  - user_blocks (사용자 차단)';
  RAISE NOTICE '';
  RAISE NOTICE '기존 테이블 (이미 존재):';
  RAISE NOTICE '  - follows (팔로우)';
  RAISE NOTICE '  - likes (게시물 좋아요)';
  RAISE NOTICE '  - notifications (알림)';
  RAISE NOTICE '================================================';
END $$;


-- =========================================
-- Part 4: Social Features RLS
-- =========================================

-- RLS Policies for Social Features Extension Tables
-- comment_likes, reports, user_blocks

-- =====================================================
-- COMMENT_LIKES 테이블 RLS
-- =====================================================
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all comment likes" ON comment_likes;
CREATE POLICY "Users can view all comment likes"
  ON comment_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create comment likes for themselves" ON comment_likes;
CREATE POLICY "Users can create comment likes for themselves"
  ON comment_likes FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comment likes" ON comment_likes;
CREATE POLICY "Users can delete their own comment likes"
  ON comment_likes FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- REPORTS 테이블 RLS
-- =====================================================
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own reports" ON reports;
CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT USING (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports"
  ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- =====================================================
-- USER_BLOCKS 테이블 RLS
-- =====================================================
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own blocks" ON user_blocks;
CREATE POLICY "Users can view their own blocks"
  ON user_blocks FOR SELECT USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can create blocks for themselves" ON user_blocks;
CREATE POLICY "Users can create blocks for themselves"
  ON user_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can delete their own blocks" ON user_blocks;
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


-- =========================================
-- Part 5: Post Likes Functions
-- =========================================

-- 게시물 좋아요 수 증가/감소 함수
CREATE OR REPLACE FUNCTION increment_post_likes(post_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE posts
  SET likes_count = likes_count + 1
  WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_post_likes(post_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE posts
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = post_id;
END;
$$;

-- 댓글 좋아요 수 증가/감소 함수
CREATE OR REPLACE FUNCTION increment_comment_likes(comment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE comments
  SET likes_count = likes_count + 1
  WHERE id = comment_id;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_comment_likes(comment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE comments
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = comment_id;
END;
$$;

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '================================================';
  RAISE NOTICE '좋아요 함수 생성 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '생성된 함수:';
  RAISE NOTICE '  - increment_post_likes';
  RAISE NOTICE '  - decrement_post_likes';
  RAISE NOTICE '  - increment_comment_likes';
  RAISE NOTICE '  - decrement_comment_likes';
  RAISE NOTICE '================================================';
END $$;

-- =====================================================
-- 최종 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '✅ 전체 마이그레이션 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE '생성된 테이블:';
  RAISE NOTICE '  1. users (온보딩 및 소셜 기능 컬럼 포함)';
  RAISE NOTICE '  2. pets';
  RAISE NOTICE '  3. posts';
  RAISE NOTICE '  4. emotion_history';
  RAISE NOTICE '  5. comments';
  RAISE NOTICE '  6. follows';
  RAISE NOTICE '  7. likes';
  RAISE NOTICE '  8. notifications';
  RAISE NOTICE '  9. user_devices';
  RAISE NOTICE '  10. comment_likes';
  RAISE NOTICE '  11. reports';
  RAISE NOTICE '  12. user_blocks';
  RAISE NOTICE '';
  RAISE NOTICE 'Users 테이블 중요 컬럼:';
  RAISE NOTICE '  ✅ is_onboarding_completed - 온보딩 완료 여부';
  RAISE NOTICE '  ✅ pets - 반려동물 ID 배열';
  RAISE NOTICE '  ✅ following - 팔로잉 ID 배열';
  RAISE NOTICE '  ✅ followers - 팔로워 ID 배열';
  RAISE NOTICE '';
  RAISE NOTICE 'RLS 정책: ✅ 설정 완료';
  RAISE NOTICE '인덱스: ✅ 생성 완료';
  RAISE NOTICE '트리거: ✅ 생성 완료';
  RAISE NOTICE '함수: ✅ 생성 완료';
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '🎉 멍냥다이어리 데이터베이스 준비 완료!';
  RAISE NOTICE '================================================';
END $$;
