-- ============================================================
-- E-1 반려동물 MBTI(성격 유형 검사) 데이터 모델
-- ------------------------------------------------------------
-- 작성일: 2026-06-03
-- 목적:
--   반려동물 MBTI 기능의 검사 결과 저장소.
--   - pet_mbti_results: 검사할 때마다 INSERT 누적(이력 보존, UPDATE 미사용).
--   - pets 캐시 컬럼: 프로필/홈 카드 빠른 표시용 최신 유형 1건.
--   외부 API 호출 0 — 문항/유형/궁합은 앱 번들 JSON, 채점은 클라이언트.
--
-- 이력 정책:
--   결과는 절대 덮어쓰지 않음. "다시 검사" 시에도 새 row를 INSERT 하고
--   pets.current_mbti_type / current_mbti_updated_at 캐시만 최신으로 갱신.
--   → 최신 1건 조회는 created_at DESC LIMIT 1 (또는 pets 캐시 컬럼)로 수행.
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행하거나,
--   `supabase db push` 로 마이그레이션 반영.
--   ※ 마스터 SQL(petspace_setup.sql)은 수정하지 않음. 본 파일만 별도 적용.
--
-- 검증 시나리오:
--   1) 본인 소유 pet 으로 결과 2건 INSERT → 두 row 모두 조회되고
--      created_at DESC LIMIT 1 이 최신 1건을 반환한다.
--   2) 타인 소유 pet 의 pet_id 로 INSERT/SELECT 시도 → RLS 로 차단된다.
--   3) UPDATE 정책이 없으므로 기존 row 수정 불가(이력 불변).
-- ============================================================

-- ── 1) pet_mbti_results: 검사 결과 이력 테이블 ───────────────
CREATE TABLE IF NOT EXISTS pet_mbti_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat', 'etc')),
    type_code TEXT NOT NULL CHECK (char_length(type_code) = 4),  -- 예: 'ENFP'
    axis_scores JSONB NOT NULL DEFAULT '{}'::jsonb,              -- {"EI":{"E":4,"I":1}, ...} 축별 합=5
    answers JSONB NOT NULL DEFAULT '[]'::jsonb,                  -- [{"q_id":"dog_01","choice":"A"}, ...]
    content_version INTEGER NOT NULL DEFAULT 1,                  -- 문항/콘텐츠 버전 (과거 결과 호환)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE pet_mbti_results IS
  '반려동물 MBTI 검사 결과 이력. 검사마다 INSERT 누적(UPDATE 미사용). 최신 1건은 created_at DESC.';
COMMENT ON COLUMN pet_mbti_results.species IS 'dog / cat / etc(범용 문항)';
COMMENT ON COLUMN pet_mbti_results.type_code IS '4글자 MBTI 코드. 예: ENFP';
COMMENT ON COLUMN pet_mbti_results.axis_scores IS '축별 극 카운트. 축당 합=5. 예: {"EI":{"E":4,"I":1}}';
COMMENT ON COLUMN pet_mbti_results.answers IS '응답 원본 배열. 재계산/감사용.';
COMMENT ON COLUMN pet_mbti_results.content_version IS 'JSON meta.version. 과거 결과 호환용.';

-- pet 별 최신 이력 조회 최적화 (created_at DESC LIMIT 1)
CREATE INDEX IF NOT EXISTS idx_pet_mbti_results_pet_created
    ON pet_mbti_results (pet_id, created_at DESC);

-- ── 2) pets 캐시 컬럼 (최신 유형 빠른 표시용) ────────────────
ALTER TABLE pets ADD COLUMN IF NOT EXISTS current_mbti_type TEXT;
ALTER TABLE pets ADD COLUMN IF NOT EXISTS current_mbti_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN pets.current_mbti_type IS
  'MBTI 최신 결과 type_code 캐시. 프로필/홈 카드 표시용. 원천은 pet_mbti_results.';
COMMENT ON COLUMN pets.current_mbti_updated_at IS 'current_mbti_type 캐시 갱신 시각.';

-- ── 3) RLS: 본인 소유 pet 의 결과만 select / insert / delete ──
--    update 정책 없음 → 이력 불변(덮어쓰기 불가).
ALTER TABLE pet_mbti_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own pet mbti results" ON pet_mbti_results;
CREATE POLICY "Users can view own pet mbti results" ON pet_mbti_results
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own pet mbti results" ON pet_mbti_results;
CREATE POLICY "Users can insert own pet mbti results" ON pet_mbti_results
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete own pet mbti results" ON pet_mbti_results;
CREATE POLICY "Users can delete own pet mbti results" ON pet_mbti_results
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM pets p
            WHERE p.id = pet_mbti_results.pet_id
              AND p.user_id = auth.uid()
        )
    );

-- ============================================================
-- 검증용 SQL (실행 후 주석 처리하거나 삭제)
-- ============================================================
-- 본인 소유 pet 으로 결과 2건 INSERT 후 최신 1건 조회 동작 확인
-- DO $$
-- DECLARE
--   v_pet UUID := '<OWN_PET_UUID>';
--   v_latest TEXT;
--   v_count INTEGER;
-- BEGIN
--   INSERT INTO pet_mbti_results(pet_id, species, type_code, axis_scores, answers)
--   VALUES (v_pet, 'dog', 'ENFP', '{"EI":{"E":4,"I":1}}'::jsonb, '[]'::jsonb);
--   INSERT INTO pet_mbti_results(pet_id, species, type_code, axis_scores, answers)
--   VALUES (v_pet, 'dog', 'INTJ', '{"EI":{"E":1,"I":4}}'::jsonb, '[]'::jsonb);
--   SELECT COUNT(*) INTO v_count FROM pet_mbti_results WHERE pet_id = v_pet;
--   SELECT type_code INTO v_latest FROM pet_mbti_results
--     WHERE pet_id = v_pet ORDER BY created_at DESC LIMIT 1;
--   RAISE NOTICE '이력 수 = %, 최신 유형 = %', v_count, v_latest;
--   ASSERT v_count >= 2, 'E-1 이력 누적 실패';
-- END$$;
