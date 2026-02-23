-- ============================================
-- Storage Buckets 통합 실행 파일
-- ============================================
--
-- 이 파일은 모든 Storage Bucket 설정을 한 번에 실행합니다.
--
-- 사용 방법:
-- 1. Supabase Dashboard → SQL Editor
-- 2. New query
-- 3. 이 파일 내용 복사 & 붙여넣기
-- 4. Run 버튼 클릭
--
-- ============================================

-- ============================================
-- 1. images 버킷 생성
-- ============================================

-- images 버킷 생성 (이미 있으면 무시)
INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 완료 메시지
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '✅ Storage Buckets 설정 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE '생성된 버킷:';
  RAISE NOTICE '  1. images (public) - 프로필/반려동물/게시물 이미지';
  RAISE NOTICE '';
  RAISE NOTICE '다음 단계: policies 폴더의 통합 파일을 실행하세요.';
  RAISE NOTICE '================================================';
END $$;
