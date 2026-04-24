-- ============================================================================
-- 알림 자동 생성 트리거: like, comment, follow
-- ============================================================================
-- AFTER INSERT 트리거로 notifications 테이블에 자동 레코드 삽입.
-- Cron이 is_sent=false 레코드를 찾아 FCM으로 발송.

-- ── 1. 좋아요 알림 ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE
    v_post_author_id UUID;
    v_sender_name TEXT;
BEGIN
    -- 게시글 작성자 조회
    SELECT author_id INTO v_post_author_id
    FROM posts
    WHERE id = NEW.post_id;

    -- 본인 게시글에는 알림 생성 안 함
    IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
        RETURN NEW;
    END IF;

    -- 발신자 이름
    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM users
    WHERE id = NEW.user_id;

    -- 알림 삽입
    INSERT INTO notifications (user_id, sender_id, type, title, body, post_id, data, is_sent)
    VALUES (
        v_post_author_id,
        NEW.user_id,
        'like',
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
    AFTER INSERT ON likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_like();

-- ── 2. 댓글 알림 ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_post_author_id UUID;
    v_sender_name TEXT;
    v_preview TEXT;
BEGIN
    SELECT author_id INTO v_post_author_id
    FROM posts
    WHERE id = NEW.post_id;

    IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM users
    WHERE id = NEW.user_id;

    -- 댓글 본문 미리보기 (50자)
    v_preview := LEFT(COALESCE(NEW.content, ''), 50);
    IF LENGTH(COALESCE(NEW.content, '')) > 50 THEN
        v_preview := v_preview || '...';
    END IF;

    INSERT INTO notifications (user_id, sender_id, type, title, body, post_id, comment_id, data, is_sent)
    VALUES (
        v_post_author_id,
        NEW.user_id,
        'comment',
        '새로운 댓글',
        v_sender_name || ': ' || v_preview,
        NEW.post_id,
        NEW.id,
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
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_comment();

-- ── 3. 팔로우 알림 ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    -- 본인을 팔로우하는 경우는 없지만 안전 장치
    IF NEW.follower_id = NEW.following_id THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(display_name, '사용자') INTO v_sender_name
    FROM users
    WHERE id = NEW.follower_id;

    INSERT INTO notifications (user_id, sender_id, type, title, body, data, is_sent)
    VALUES (
        NEW.following_id,
        NEW.follower_id,
        'follow',
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
    AFTER INSERT ON follows
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_follow();
