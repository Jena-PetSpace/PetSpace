-- ================================================================
-- PetSpace 채팅 기능 데이터베이스 설정
-- ================================================================
--
-- petspace_setup.sql 실행 후 이 파일을 Supabase SQL Editor에서 실행
--
-- ================================================================

-- ================================================================
-- PART 1: Tables (3개)
-- ================================================================

-- 1. Chat Rooms
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

-- 2. Chat Participants
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

-- 3. Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT,
    type VARCHAR(10) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'system')),
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

-- ================================================================
-- PART 2: Indexes
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_chat_rooms_created_by ON chat_rooms(created_by);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_last_message_at ON chat_rooms(last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_chat_participants_room_id ON chat_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_room_user ON chat_participants(room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_active ON chat_participants(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(room_id, created_at DESC);

-- ================================================================
-- PART 3: Functions & Triggers
-- ================================================================

-- chat_rooms updated_at 자동 갱신
DROP TRIGGER IF EXISTS update_chat_rooms_updated_at ON chat_rooms;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE UPDATE ON chat_rooms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 새 메시지 INSERT 시 chat_rooms.last_message 자동 갱신
CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER AS $$
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

DROP TRIGGER IF EXISTS on_chat_message_insert ON chat_messages;
CREATE TRIGGER on_chat_message_insert
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_room_last_message();

-- 전체 안읽은 메시지 수 조회 (뱃지용)
CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
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

-- 채팅방별 안읽은 메시지 수 조회
CREATE OR REPLACE FUNCTION get_room_unread_count(p_room_id UUID, p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
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

-- ================================================================
-- PART 4: Row Level Security
-- ================================================================

ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Users (기존 정책 수정: 채팅 유저 검색을 위해 모든 프로필 조회 허용)
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.users;
CREATE POLICY "Authenticated users can view all profiles" ON public.users
    FOR SELECT TO authenticated
    USING (true);

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

-- ================================================================
-- PART 5: Storage RLS for chat images
-- ================================================================

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
-- PART 6: Enable Realtime
-- ================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_participants'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;
    END IF;
END $$;

-- ================================================================
-- DONE
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE '  PetSpace 채팅 기능 DB 설정 완료!';
    RAISE NOTICE '  테이블 3개, 인덱스, RLS, 트리거, 함수, Realtime';
    RAISE NOTICE '================================================';
END $$;
