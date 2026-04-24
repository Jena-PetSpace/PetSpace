-- ============================================================================
-- notification_preferences: 사용자별 알림 설정
-- ============================================================================
-- Edge Function이 FCM 발송 전 이 테이블을 참조해서 발송 여부 결정.
-- 기본값: 모두 TRUE (신규 사용자는 알림 허용 상태).

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

-- updated_at 자동 갱신 트리거
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
    FOR EACH ROW
    EXECUTE FUNCTION touch_notification_preferences_updated_at();

-- RLS
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

-- ── 사용자 생성 시 기본 preferences 자동 생성 ─────────────────────────────
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
    FOR EACH ROW
    EXECUTE FUNCTION create_default_notification_preferences();

-- ── 기존 사용자 backfill ──────────────────────────────────────────────────
INSERT INTO notification_preferences (user_id)
SELECT id FROM users
ON CONFLICT (user_id) DO NOTHING;
