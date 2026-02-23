-- ============================================
-- Storage RLS Policy: 반려동물 이미지
-- ============================================
--
-- 경로: images/pets/{user_id}/{pet_id}/pet_xxxxx.jpg
--
-- ============================================

-- 기존 정책 삭제 (업데이트용)
DROP POLICY IF EXISTS "Users can upload pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete pet images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;

-- 1. 반려동물 이미지 업로드 허용 (INSERT)
CREATE POLICY "Users can upload pet images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 2. 반려동물 이미지 업데이트 허용 (UPDATE)
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

-- 3. 반려동물 이미지 삭제 허용 (DELETE)
CREATE POLICY "Users can delete pet images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 4. 반려동물 이미지 공개 조회 허용 (SELECT)
CREATE POLICY "Public can view pet images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = 'pets'
);
