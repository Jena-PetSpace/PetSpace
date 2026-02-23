-- =====================================================
-- 기존 users 테이블에 누락된 컬럼만 추가
-- =====================================================

-- 온보딩 완료 여부 컬럼 추가
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN DEFAULT FALSE;

-- 반려동물 ID 배열 컬럼 추가
ALTER TABLE users
ADD COLUMN IF NOT EXISTS pets UUID[] DEFAULT ARRAY[]::UUID[];

-- 팔로잉 ID 배열 컬럼 추가
ALTER TABLE users
ADD COLUMN IF NOT EXISTS following UUID[] DEFAULT ARRAY[]::UUID[];

-- 팔로워 ID 배열 컬럼 추가
ALTER TABLE users
ADD COLUMN IF NOT EXISTS followers UUID[] DEFAULT ARRAY[]::UUID[];

-- =====================================================
-- 인덱스 생성
-- =====================================================

-- GIN 인덱스 (배열 검색 최적화)
CREATE INDEX IF NOT EXISTS idx_users_pets ON users USING GIN(pets);
CREATE INDEX IF NOT EXISTS idx_users_following ON users USING GIN(following);
CREATE INDEX IF NOT EXISTS idx_users_followers ON users USING GIN(followers);

-- B-tree 인덱스 (온보딩 완료 여부 필터링)
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users(is_onboarding_completed);

-- =====================================================
-- 컬럼 설명 추가
-- =====================================================
COMMENT ON COLUMN users.is_onboarding_completed IS '온보딩 프로세스 완료 여부';
COMMENT ON COLUMN users.pets IS '사용자가 소유한 반려동물 UUID 배열';
COMMENT ON COLUMN users.following IS '사용자가 팔로우하는 사용자 UUID 배열';
COMMENT ON COLUMN users.followers IS '사용자를 팔로우하는 사용자 UUID 배열';

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '✅ Users 테이블 컬럼 추가 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE '추가된 컬럼:';
  RAISE NOTICE '  ✅ is_onboarding_completed (BOOLEAN)';
  RAISE NOTICE '  ✅ pets (UUID[])';
  RAISE NOTICE '  ✅ following (UUID[])';
  RAISE NOTICE '  ✅ followers (UUID[])';
  RAISE NOTICE '';
  RAISE NOTICE '생성된 인덱스:';
  RAISE NOTICE '  ✅ idx_users_pets (GIN)';
  RAISE NOTICE '  ✅ idx_users_following (GIN)';
  RAISE NOTICE '  ✅ idx_users_followers (GIN)';
  RAISE NOTICE '  ✅ idx_users_onboarding (B-tree)';
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '🎉 온보딩 기능 사용 준비 완료!';
  RAISE NOTICE '================================================';
END $$;
