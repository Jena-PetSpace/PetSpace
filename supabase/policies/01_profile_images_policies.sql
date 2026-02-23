-- ============================================
-- Storage RLS Policy: 프로필 이미지
-- ============================================
--
-- 경로: images/profiles/{user_id}/profile_xxxxx.jpg
--
-- ============================================

-- 기존 정책 삭제 (업데이트용)
DROP POLICY IF EXISTS "Users can upload own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;

-- 1. 프로필 이미지 업로드 허용 (INSERT)
CREATE POLICY "Users can upload own profile images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 2. 프로필 이미지 업데이트 허용 (UPDATE)
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

-- 3. 프로필 이미지 삭제 허용 (DELETE)
CREATE POLICY "Users can delete own profile images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 4. 프로필 이미지 공개 조회 허용 (SELECT)
CREATE POLICY "Public can view profile images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'profiles'
);
