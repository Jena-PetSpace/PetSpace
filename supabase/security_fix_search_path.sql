-- ================================================================
-- Supabase Security Advisor 경고 수정
-- "Function Search Path Mutable" 20개 해결
-- Supabase SQL Editor에서 실행해주세요
-- ================================================================

-- petspace_setup.sql 함수들
ALTER FUNCTION update_updated_at_column() SET search_path = public;
ALTER FUNCTION increment_likes_count() SET search_path = public;
ALTER FUNCTION decrement_likes_count() SET search_path = public;
ALTER FUNCTION increment_comments_count() SET search_path = public;
ALTER FUNCTION decrement_comments_count() SET search_path = public;
ALTER FUNCTION update_reports_updated_at() SET search_path = public;
ALTER FUNCTION increment_post_likes(UUID) SET search_path = public;
ALTER FUNCTION decrement_post_likes(UUID) SET search_path = public;
ALTER FUNCTION increment_comment_likes(UUID) SET search_path = public;
ALTER FUNCTION decrement_comment_likes(UUID) SET search_path = public;
ALTER FUNCTION handle_new_user() SET search_path = public;
ALTER FUNCTION get_user_pets(UUID) SET search_path = public;
ALTER FUNCTION get_feed_posts(UUID, INTEGER, INTEGER) SET search_path = public;
ALTER FUNCTION get_emotion_statistics(UUID) SET search_path = public;
ALTER FUNCTION confirm_kakao_user_by_email(TEXT) SET search_path = public;

-- chat_setup.sql 함수들
ALTER FUNCTION update_chat_room_last_message() SET search_path = public;
ALTER FUNCTION get_total_unread_count(UUID) SET search_path = public;
ALTER FUNCTION get_room_unread_count(UUID, UUID) SET search_path = public;
ALTER FUNCTION is_room_member(UUID, UUID) SET search_path = public;
ALTER FUNCTION find_direct_chat(UUID, UUID) SET search_path = public;
