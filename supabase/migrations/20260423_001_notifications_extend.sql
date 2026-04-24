-- ============================================================================
-- notifications 테이블 확장: FCM 배치 발송을 위한 is_sent 플래그 추가
-- ============================================================================
-- 기존 notifications 테이블은 이미 존재하므로 컬럼만 추가.
-- is_sent 플래그로 미발송 알림을 Cron이 배치 처리하도록 함.

-- is_sent 컬럼 추가 (이미 있으면 skip)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'is_sent'
    ) THEN
        ALTER TABLE notifications
            ADD COLUMN is_sent BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- post_id, comment_id 참조용 컬럼 추가 (data JSONB로도 가능하나 인덱스 용이)
DO $$
BEGIN
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

-- 인덱스: 수신자 + 생성일 (타임라인 조회)
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

-- Partial 인덱스: is_sent=false만 (Cron 스캔 최적화)
CREATE INDEX IF NOT EXISTS idx_notifications_unsent
    ON notifications(created_at ASC)
    WHERE is_sent = FALSE;

-- 읽지 않은 알림 인덱스
CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(user_id, created_at DESC)
    WHERE read = FALSE;

-- RLS (이미 있으면 skip)
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

-- Service Role만 INSERT 가능 (트리거 + Edge Function)
DROP POLICY IF EXISTS notifications_insert_service ON notifications;
CREATE POLICY notifications_insert_service ON notifications
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
