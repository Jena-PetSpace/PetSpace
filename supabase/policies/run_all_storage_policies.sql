-- ============================================
-- Storage RLS Policies 통합 실행 파일
-- ============================================
--
-- 이 파일은 모든 Storage RLS 정책을 한 번에 실행합니다.
--
-- 사용 방법:
-- 1. Supabase Dashboard → SQL Editor
-- 2. New query
-- 3. 이 파일 내용 복사 & 붙여넣기
-- 4. Run 버튼 클릭
--
-- 주의: storage_buckets 폴더의 통합 파일을 먼저 실행하세요!
--
-- ============================================

-- ============================================
-- 1. 프로필 이미지 정책
-- ============================================

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Users can upload own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;

-- 프로필 이미지 업로드 허용
CREATE POLICY "Users can upload own profile images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 프로필 이미지 업데이트 허용
CREATE POLICY "Users can update own profile images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 프로필 이미지 삭제 허용
CREATE POLICY "Users can delete own profile images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 프로필 이미지 공개 조회 허용
CREATE POLICY "Public can view profile images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
);

-- ============================================
-- 2. 반려동물 이미지 정책
-- ============================================

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Users can upload pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete pet images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;

-- 반려동물 이미지 업로드 허용
CREATE POLICY "Users can upload pet images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 반려동물 이미지 업데이트 허용
CREATE POLICY "Users can update pet images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 반려동물 이미지 삭제 허용
CREATE POLICY "Users can delete pet images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 반려동물 이미지 공개 조회 허용
CREATE POLICY "Public can view pet images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
);

-- ============================================
-- 3. 게시물 이미지 정책
-- ============================================

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Users can upload post images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update post images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete post images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view post images" ON storage.objects;

-- 게시물 이미지 업로드 허용
-- 경로: images/posts/{user_id}/{post_id}/{filename}
CREATE POLICY "Users can upload post images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'posts'
  AND (storage.foldername(name))[2] = auth.uid()::text
  -- postId는 체크하지 않음 (동적 생성)
);

-- 게시물 이미지 업데이트 허용
CREATE POLICY "Users can update post images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'posts'
  AND (storage.foldername(name))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'posts'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 게시물 이미지 삭제 허용
CREATE POLICY "Users can delete post images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'posts'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 게시물 이미지 공개 조회 허용
CREATE POLICY "Public can view post images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'posts'
);

-- ============================================
-- 4. 감정 분석 이미지 정책
-- ============================================

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Users can upload emotion analysis images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update emotion analysis images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete emotion analysis images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view emotion analysis images" ON storage.objects;

-- 감정 분석 이미지 업로드 허용
-- 경로: images/emotion_analysis/{user_id}/{analysis_id}/{filename}
CREATE POLICY "Users can upload emotion analysis images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'emotion_analysis'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 감정 분석 이미지 업데이트 허용
CREATE POLICY "Users can update emotion analysis images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'emotion_analysis'
  AND (storage.foldername(name))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'emotion_analysis'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 감정 분석 이미지 삭제 허용
CREATE POLICY "Users can delete emotion analysis images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'emotion_analysis'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 감정 분석 이미지 공개 조회 허용
CREATE POLICY "Public can view emotion analysis images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'emotion_analysis'
);

-- ============================================
-- 완료 메시지
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE '✅ Storage RLS Policies 설정 완료!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE '생성된 정책:';
  RAISE NOTICE '';
  RAISE NOTICE '프로필 이미지 (profiles):';
  RAISE NOTICE '  ✅ Upload (본인만)';
  RAISE NOTICE '  ✅ Update (본인만)';
  RAISE NOTICE '  ✅ Delete (본인만)';
  RAISE NOTICE '  ✅ View (공개)';
  RAISE NOTICE '';
  RAISE NOTICE '반려동물 이미지 (pets):';
  RAISE NOTICE '  ✅ Upload (본인만)';
  RAISE NOTICE '  ✅ Update (본인만)';
  RAISE NOTICE '  ✅ Delete (본인만)';
  RAISE NOTICE '  ✅ View (공개)';
  RAISE NOTICE '';
  RAISE NOTICE '게시물 이미지 (posts):';
  RAISE NOTICE '  ✅ Upload (본인만)';
  RAISE NOTICE '  ✅ Update (본인만)';
  RAISE NOTICE '  ✅ Delete (본인만)';
  RAISE NOTICE '  ✅ View (공개)';
  RAISE NOTICE '';
  RAISE NOTICE '감정 분석 이미지 (emotion_analysis):';
  RAISE NOTICE '  ✅ Upload (본인만)';
  RAISE NOTICE '  ✅ Update (본인만)';
  RAISE NOTICE '  ✅ Delete (본인만)';
  RAISE NOTICE '  ✅ View (공개)';
  RAISE NOTICE '';
  RAISE NOTICE '파일 경로 구조:';
  RAISE NOTICE '  - images/profiles/{user_id}/profile_xxxxx.jpg';
  RAISE NOTICE '  - images/pets/{user_id}/{pet_id}/pet_xxxxx.jpg';
  RAISE NOTICE '  - images/posts/{user_id}/{post_id}/xxxxx.jpg';
  RAISE NOTICE '  - images/emotion_analysis/{user_id}/{analysis_id}/xxxxx.jpg';
  RAISE NOTICE '';
  RAISE NOTICE '다음 단계: database 폴더의 통합 파일을 실행하세요.';
  RAISE NOTICE '================================================';
END $$;
