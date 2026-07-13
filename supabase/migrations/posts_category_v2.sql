-- ============================================================
-- posts.category v2 — 피드 라운지 재편(2026-07) 카테고리 체계 문서화
-- ------------------------------------------------------------
-- 작성일: 2026-07-09
-- 선행: migrations/posts_category.sql (컬럼 신설 + 구 백필 + 인덱스)
--
-- 신 체계 (라운지):
--   chat(잡담) / brag(자랑) / qa(궁금해요) / info(정보)
--   - 'qa'는 구 체계 값 재사용(웹 검토 승인) → 데이터 백필 불필요
--   - chat/brag/info 3종만 신규 도입 (앱 글 작성 화면에서 저장)
--
-- 구 체계 값 처리 (백필 없음이 의도된 결정):
--   quiz/careguide/education/policy/event/health/training/food/life
--   - 라운지 카테고리 필터는 eq('category', 신값) 조회이므로 구값 글은
--     필터에서 자연 제외되고 '전체'에서만 노출된다 (폴백 설계).
--   - careguide/education/policy 글은 발견 탭 운영 카드 소스로 재사용.
--   - 앱 라벨 표기는 lib/shared/constants/community_categories.dart 의
--     CommunityCategories.label()이 신구 모두 처리한다.
--
-- 스키마 변경 없음: category는 무제약 TEXT 유지(petspace_setup.sql:2918
-- 계열 확인 — CHECK 제약 없음). 본 파일은 COMMENT 갱신만 수행한다.
--
-- 적용 방법: Supabase Dashboard → SQL Editor에서 전체 실행. 멱등.
-- ============================================================

COMMENT ON COLUMN posts.category IS
  '커뮤니티(라운지) 글의 카테고리. 신 체계(2026-07): chat(잡담)/brag(자랑)/'
  'qa(궁금해요)/info(정보). 구 체계 잔존 값(quiz/careguide/education/policy/'
  'event/health/training/food/life)은 라운지 필터에서 제외되고 전체·발견 '
  '운영 카드에서만 노출. 미분류는 NULL. 사진 글(post_type=photo)은 사용 안 함.';
