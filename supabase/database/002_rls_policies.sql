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
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Pets table policies
CREATE POLICY "Users can view own pets" ON pets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pets" ON pets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pets" ON pets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own pets" ON pets
    FOR DELETE USING (auth.uid() = user_id);

-- Posts table policies
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = author_id);

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
CREATE POLICY "Users can only see own emotion history" ON emotion_history
    FOR ALL USING (auth.uid() = user_id);

-- Comments table policies
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert comments" ON comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update own comments" ON comments
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Users can delete own comments" ON comments
    FOR DELETE USING (auth.uid() = author_id);

-- Follows table policies
CREATE POLICY "Users can view follows" ON follows
    FOR SELECT USING (true);

CREATE POLICY "Users can follow others" ON follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow others" ON follows
    FOR DELETE USING (auth.uid() = follower_id);

-- Likes table policies
CREATE POLICY "Users can view likes" ON likes
    FOR SELECT USING (true);

CREATE POLICY "Users can like posts" ON likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike posts" ON likes
    FOR DELETE USING (auth.uid() = user_id);

-- Notifications table policies
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- User devices table policies
CREATE POLICY "Users can manage own devices" ON user_devices
    FOR ALL USING (auth.uid() = user_id);

-- Create function to handle user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users (id, email, display_name, photo_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email),
        NEW.raw_user_meta_data->>'photo_url'
    );
    RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Trigger to automatically create user profile on signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

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