-- ============================================================
-- 게시물 카테고리 컬럼화(posts.category) — 피드 Q&A 분류 정규화
-- ------------------------------------------------------------
-- 작성일: 2026-06-15
-- 목적:
--   Q&A(커뮤니티) 글의 카테고리(건강/훈련/먹거리/생활/Q&A)를 그동안
--   hashtags 배열에서 역추론하던 방식을 폐기하고, posts.category 컬럼에
--   1글=1카테고리로 명시 저장한다. 정렬·필터·집계가 가능해지고 사진 글이
--   Q&A 목록에 새는 오염을 post_type 필터와 함께 차단한다.
--
-- 배경(라이브 DB 실측, 2026-06-15):
--   - posts.category 컬럼 없음 → 신설
--   - posts.post_type 존재(photo/community/emotion)
--   - alive 글 6건: community 1 · photo 2 · emotion 3
--   - 카테고리 태그(health/training/food/life/qa)를 가진 글 0건
--     → 백필로 실제 변경되는 행은 사실상 없음. 안전장치로만 포함.
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체 실행.
--   멱등(IF NOT EXISTS / 조건부 UPDATE) — 재실행 안전.
--
-- 검증:
--   1) posts.category 컬럼 존재(nullable, default 없음)
--   2) 백필 UPDATE 후 category가 채워진 행 = hashtags에 분류 태그가 있던 글뿐
--      (현재 0건이므로 변경 행 0)
--   3) 분석 공유 등 카테고리 미상 community 글은 category NULL 유지(억지 분류 금지)
--   4) 사진 피드 조회(get_recommended_posts 등)는 category 미참조 → 회귀 없음
-- ============================================================

-- 1) category 컬럼 신설 (nullable, default 없음 — 미분류는 정직하게 NULL)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS category TEXT;

COMMENT ON COLUMN posts.category IS
  '커뮤니티(Q&A) 글의 카테고리: health/training/food/life/qa. '
  '미분류(분석 공유 등)는 NULL. 사진 글(post_type=photo)은 사용 안 함.';

-- 2) 백필: hashtags에 분류 태그가 있는 글의 category를 채운다(멱등).
--    이미 category가 채워진 행은 건드리지 않는다(WHERE category IS NULL).
--    우선순위: 명시적 카테고리 태그만. 'community' 같은 종류 태그는 카테고리 아님.
UPDATE posts SET category = 'health'
  WHERE category IS NULL AND hashtags @> ARRAY['health'];
UPDATE posts SET category = 'training'
  WHERE category IS NULL AND hashtags @> ARRAY['training'];
UPDATE posts SET category = 'food'
  WHERE category IS NULL AND hashtags @> ARRAY['food'];
UPDATE posts SET category = 'life'
  WHERE category IS NULL AND hashtags @> ARRAY['life'];
UPDATE posts SET category = 'qa'
  WHERE category IS NULL AND hashtags @> ARRAY['qa'];

-- 주의: magazine 글은 category로 분류하지 않는다(매거진은 별도 노출 경로).
--       community 글 중 분류 태그가 없는 글은 NULL 유지 → 'qa'로 억지 분류 금지.

-- 3) 조회 성능: 카테고리 필터 인덱스(soft delete 제외 부분 인덱스)
CREATE INDEX IF NOT EXISTS idx_posts_category
  ON posts(category) WHERE deleted_at IS NULL;
