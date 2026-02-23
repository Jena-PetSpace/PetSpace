-- =============================================
-- 품종 데이터 테이블 생성
-- Migration: 003_create_breeds_table
-- Description: 반려동물 품종 데이터를 DB로 마이그레이션
-- =============================================

-- 1. breeds 테이블 생성
CREATE TABLE IF NOT EXISTS public.breeds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species VARCHAR(10) NOT NULL CHECK (species IN ('dog', 'cat')),
  name_ko VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  description TEXT,
  origin_country VARCHAR(50),
  size VARCHAR(20) CHECK (size IN ('small', 'medium', 'large', 'extra_large')),
  temperament TEXT[],
  lifespan_min INTEGER,
  lifespan_max INTEGER,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT unique_breed_per_species UNIQUE (species, name_ko)
);

-- 2. 인덱스 생성
CREATE INDEX idx_breeds_species ON public.breeds(species);
CREATE INDEX idx_breeds_name_ko ON public.breeds(name_ko);
CREATE INDEX idx_breeds_is_active ON public.breeds(is_active);
CREATE INDEX idx_breeds_display_order ON public.breeds(display_order);

-- 3. RLS (Row Level Security) 활성화
ALTER TABLE public.breeds ENABLE ROW LEVEL SECURITY;

-- 4. RLS 정책: 모든 사용자가 조회 가능
CREATE POLICY "Breeds are viewable by everyone"
  ON public.breeds
  FOR SELECT
  USING (true);

-- 5. RLS 정책: 인증된 사용자만 삽입/수정/삭제 가능 (관리자용)
CREATE POLICY "Authenticated users can insert breeds"
  ON public.breeds
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update breeds"
  ON public.breeds
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete breeds"
  ON public.breeds
  FOR DELETE
  TO authenticated
  USING (true);

-- 6. 초기 데이터 삽입 - 강아지 품종
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order) VALUES
('dog', '말티즈', 'Maltese', 'small', '작고 귀여운 장모종 강아지', 1),
('dog', '푸들', 'Poodle', 'small', '영리하고 사교적인 견종', 2),
('dog', '치와와', 'Chihuahua', 'small', '세계에서 가장 작은 견종', 3),
('dog', '포메라니안', 'Pomeranian', 'small', '폭신한 털을 가진 활발한 강아지', 4),
('dog', '시바견', 'Shiba Inu', 'medium', '일본 원산의 독립적인 성격의 견종', 5),
('dog', '비글', 'Beagle', 'medium', '사냥개 출신의 호기심 많은 견종', 6),
('dog', '웰시코기', 'Welsh Corgi', 'medium', '짧은 다리와 긴 몸통이 특징', 7),
('dog', '골든 리트리버', 'Golden Retriever', 'large', '온순하고 충성스러운 대형견', 8),
('dog', '래브라도 리트리버', 'Labrador Retriever', 'large', '가장 인기있는 가족견', 9),
('dog', '진돗개', 'Jindo', 'medium', '한국 토종견으로 충성심이 강함', 10),
('dog', '요크셔테리어', 'Yorkshire Terrier', 'small', '작지만 용감한 테리어 품종', 11),
('dog', '시츄', 'Shih Tzu', 'small', '중국 원산의 애완견', 12),
('dog', '닥스훈트', 'Dachshund', 'small', '긴 몸과 짧은 다리가 특징', 13),
('dog', '불독', 'Bulldog', 'medium', '주름진 얼굴과 근육질 체형', 14),
('dog', '보더콜리', 'Border Collie', 'medium', '가장 영리한 견종 중 하나', 15);

-- 7. 초기 데이터 삽입 - 고양이 품종
INSERT INTO public.breeds (species, name_ko, name_en, size, description, display_order) VALUES
('cat', '코리안 숏헤어', 'Korean Shorthair', 'medium', '한국 토종 고양이', 1),
('cat', '페르시안', 'Persian', 'medium', '긴 털과 납작한 얼굴이 특징', 2),
('cat', '러시안 블루', 'Russian Blue', 'medium', '은색 푸른 털을 가진 고양이', 3),
('cat', '샴', 'Siamese', 'medium', '독특한 무늬와 파란 눈이 특징', 4),
('cat', '스코티시 폴드', 'Scottish Fold', 'medium', '접힌 귀가 특징인 고양이', 5),
('cat', '먼치킨', 'Munchkin', 'small', '짧은 다리가 특징인 고양이', 6),
('cat', '아메리칸 숏헤어', 'American Shorthair', 'medium', '튼튼하고 건강한 품종', 7),
('cat', '메인쿤', 'Maine Coon', 'large', '가장 큰 고양이 품종 중 하나', 8),
('cat', '브리티시 숏헤어', 'British Shorthair', 'medium', '둥근 얼굴과 두꺼운 털', 9),
('cat', '뱅갈', 'Bengal', 'medium', '야생 표범 무늬를 가진 고양이', 10),
('cat', '노르웨이 숲', 'Norwegian Forest', 'large', '긴 털을 가진 북유럽 원산 고양이', 11),
('cat', '랙돌', 'Ragdoll', 'large', '안으면 인형처럼 축 늘어지는 성격', 12),
('cat', '아비시니안', 'Abyssinian', 'medium', '날씬하고 우아한 체형', 13),
('cat', '터키시 앙고라', 'Turkish Angora', 'medium', '우아하고 긴 털을 가진 고양이', 14),
('cat', '스핑크스', 'Sphynx', 'medium', '털이 없는 독특한 품종', 15);

-- 8. 업데이트 트리거 생성 (updated_at 자동 갱신)
CREATE OR REPLACE FUNCTION update_breeds_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_breeds_updated_at
  BEFORE UPDATE ON public.breeds
  FOR EACH ROW
  EXECUTE FUNCTION update_breeds_updated_at();

-- 9. 품종 검색 함수 (성능 최적화)
CREATE OR REPLACE FUNCTION search_breeds(
  p_species VARCHAR(10),
  p_query TEXT,
  p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  species VARCHAR(10),
  name_ko VARCHAR(100),
  name_en VARCHAR(100),
  description TEXT,
  size VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id,
    b.species,
    b.name_ko,
    b.name_en,
    b.description,
    b.size
  FROM public.breeds b
  WHERE b.species = p_species
    AND b.is_active = true
    AND (
      b.name_ko ILIKE '%' || p_query || '%'
      OR b.name_en ILIKE '%' || p_query || '%'
    )
  ORDER BY b.display_order ASC, b.name_ko ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- 10. 전체 품종 목록 조회 함수
CREATE OR REPLACE FUNCTION get_all_breeds(
  p_species VARCHAR(10) DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  species VARCHAR(10),
  name_ko VARCHAR(100),
  name_en VARCHAR(100),
  description TEXT,
  size VARCHAR(20),
  display_order INTEGER
) AS $$
BEGIN
  IF p_species IS NULL THEN
    RETURN QUERY
    SELECT
      b.id,
      b.species,
      b.name_ko,
      b.name_en,
      b.description,
      b.size,
      b.display_order
    FROM public.breeds b
    WHERE b.is_active = true
    ORDER BY b.species ASC, b.display_order ASC, b.name_ko ASC;
  ELSE
    RETURN QUERY
    SELECT
      b.id,
      b.species,
      b.name_ko,
      b.name_en,
      b.description,
      b.size,
      b.display_order
    FROM public.breeds b
    WHERE b.species = p_species
      AND b.is_active = true
    ORDER BY b.display_order ASC, b.name_ko ASC;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- 완료
COMMENT ON TABLE public.breeds IS '반려동물 품종 정보 테이블';
COMMENT ON COLUMN public.breeds.species IS '동물 종류 (dog/cat)';
COMMENT ON COLUMN public.breeds.name_ko IS '한글 품종명';
COMMENT ON COLUMN public.breeds.name_en IS '영문 품종명';
COMMENT ON COLUMN public.breeds.size IS '크기 (small/medium/large/extra_large)';
COMMENT ON COLUMN public.breeds.display_order IS '표시 순서 (낮을수록 먼저)';
