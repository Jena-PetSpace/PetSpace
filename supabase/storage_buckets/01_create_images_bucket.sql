-- ============================================
-- Storage Bucket: images 버킷 생성
-- ============================================
--
-- 프로필 이미지, 반려동물 이미지, 게시물 이미지를 저장하는 공개 버킷
--
-- ============================================

-- images 버킷 생성 (이미 있으면 무시)
INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

-- 버킷 정보 확인
SELECT * FROM storage.buckets WHERE id = 'images';
