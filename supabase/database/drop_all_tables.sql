-- 모든 기존 테이블 삭제 (주의: 데이터가 모두 삭제됩니다!)
-- 개발 초기 단계에서 깨끗하게 다시 시작할 때 사용

-- 순서대로 삭제 (Foreign Key 때문에 역순으로)
DROP TABLE IF EXISTS user_blocks CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS comment_likes CASCADE;
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS follows CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS emotion_history CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS pets CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 함수들도 삭제
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS increment_likes_count() CASCADE;
DROP FUNCTION IF EXISTS decrement_likes_count() CASCADE;
DROP FUNCTION IF EXISTS increment_comments_count() CASCADE;
DROP FUNCTION IF EXISTS decrement_comments_count() CASCADE;
DROP FUNCTION IF EXISTS update_reports_updated_at() CASCADE;
DROP FUNCTION IF EXISTS get_user_pets(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_feed_posts(UUID, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_emotion_statistics(UUID, UUID, INTEGER) CASCADE;

-- Extension은 유지 (다른 기능에서 사용할 수 있음)
-- DROP EXTENSION IF EXISTS "uuid-ossp";
