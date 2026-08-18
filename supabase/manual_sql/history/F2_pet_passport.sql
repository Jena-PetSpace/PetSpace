-- ============================================================
-- F-2 반려동물 펫 여권(Pet Passport) 데이터 모델
-- ------------------------------------------------------------
-- 작성일: 2026-06-08
-- 목적:
--   홈 상단 "반려동물 여권 카드" + 등록 페이지 여권 입력을 위한
--   pets 테이블 컬럼 5개 추가. 모두 nullable → 기존 행/미입력 안전.
--
--   | 컬럼                 | 타입                | 설명                                    |
--   |---------------------|--------------------|-----------------------------------------|
--   | passport_no         | text UNIQUE(부분)   | 여권번호. 등록 시 1회 생성('P'+영문2+숫자5).|
--   | passport_surname    | text               | 영문 성(수동 입력)                        |
--   | passport_given_name | text               | 영문 이름(수동 입력)                      |
--   | name_hanguel        | text               | 한글성명(수동 입력, 기존 name 과 별개)     |
--   | country_code        | text default 'KOR' | 국가코드(ISO 3166-1 alpha-3, 기본 KOR)    |
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행.
--   ※ 마스터 SQL(petspace_setup.sql)은 직접 DB 변경이 아니라 커밋용으로만
--     동일 컬럼을 반영(신규 설치 일관성). 본 파일이 실제 적용 대상.
--
-- 검증 시나리오:
--   1) pets 에 컬럼 5개가 추가된다(미입력 행은 모두 null/기본값 KOR).
--   2) passport_no 가 같은 값으로 2건 INSERT 시 UNIQUE 위반(부분 인덱스).
--   3) passport_no 가 null 인 행은 여러 건 허용된다(부분 인덱스 = null 제외).
-- ============================================================

-- ── 1) 여권 컬럼 추가 (모두 nullable → 기존 행/미입력 안전) ──────
ALTER TABLE public.pets
  ADD COLUMN IF NOT EXISTS passport_no         TEXT,
  ADD COLUMN IF NOT EXISTS passport_surname    TEXT,
  ADD COLUMN IF NOT EXISTS passport_given_name TEXT,
  ADD COLUMN IF NOT EXISTS name_hanguel        TEXT,
  ADD COLUMN IF NOT EXISTS country_code        TEXT DEFAULT 'KOR';

COMMENT ON COLUMN public.pets.passport_no         IS '펫 여권번호(등록 시 1회 생성, P 시작). 공식/피드 대비 저장.';
COMMENT ON COLUMN public.pets.passport_surname    IS '여권 영문 성(수동 입력).';
COMMENT ON COLUMN public.pets.passport_given_name IS '여권 영문 이름(수동 입력).';
COMMENT ON COLUMN public.pets.name_hanguel        IS '여권 표기용 한글성명(수동 입력, 기존 name 과 별개).';
COMMENT ON COLUMN public.pets.country_code        IS '국가코드(ISO 3166-1 alpha-3, 기본 KOR).';

-- ── 2) 여권번호 UNIQUE (부분 인덱스: null 제외 → 미발급 행 다수 허용) ──
CREATE UNIQUE INDEX IF NOT EXISTS uq_pets_passport_no
  ON public.pets (passport_no)
  WHERE passport_no IS NOT NULL;

-- ── 3) RLS: 기존 pets 정책(본인 펫만) 그대로 적용 → 신규 컬럼 별도 정책 불필요.

-- ============================================================
-- 검증용 SQL (실행 후 주석 처리하거나 삭제)
-- ============================================================
-- 컬럼 5개 추가 확인
-- SELECT column_name, data_type, column_default
--   FROM information_schema.columns
--  WHERE table_name = 'pets'
--    AND column_name IN ('passport_no','passport_surname','passport_given_name','name_hanguel','country_code')
--  ORDER BY column_name;
--
-- UNIQUE 부분 인덱스 확인
-- SELECT indexname, indexdef FROM pg_indexes
--  WHERE tablename = 'pets' AND indexname = 'uq_pets_passport_no';
