-- ============================================================
-- H-1 산책 기록(walk_records) + 위치정보 취급대장(location_access_log)
-- ------------------------------------------------------------
-- 작성일: 2026-06-25
-- 목적:
--   위치기반서비스(LBS) 사업신고 첨부2(기술적 보호조치) 증빙 확보.
--   ① 산책 기록 기능의 출시용 정식 DB 스키마(미개발 기능 → 출시 스키마로 설계)
--   ② 위치정보 이용·제공사실 확인자료(취급대장) 자동 기록
--   ③ 두 테이블 RLS 정책(본인 데이터만 접근)
--
--   ⚠️ 캡처용 임시 테이블 아님. 이 스키마가 곧 출시 스키마가 된다
--      (프로덕션 ↔ 커밋 SQL drift 방지).
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행.
--   ※ 마스터 SQL(petspace_setup.sql)은 직접 DB 변경이 아니라 커밋용으로만
--     동일 내용을 반영(신규 설치 일관성). 본 파일이 실제 적용 대상.
--
-- 설계 결정(STEP 0 검증 → 황정현 승인):
--   - user_id FK → public.users(id). (프로젝트 전체가 auth.users 직접 참조 대신
--     public.users 경유 패턴. handle_new_user 트리거로 id 미러링되어
--     auth.uid() = user_id RLS 정상 동작.)
--   - location_access_log.subject_id 는 FK 미부여(uuid not null). 취급대장은
--     위치정보법상 보존 의무가 있는 증빙 기록부 → 사용자 탈퇴(CASCADE)로
--     기록이 삭제되면 안 됨. 트리거가 user_id 값을 복사하므로 정합성 보장.
--   - route 는 jsonb 단일 컬럼. (기존 health_records.data / emotion_analysis
--     JSONB 패턴 일치. MVP·신고 목적엔 분리 테이블이 과설계.)
--   - FK 컬럼 인덱스 3개 추가(기존 모든 테이블 관례).
--   - 취급대장 INSERT 정책 미부여 → security definer 트리거만 기록 가능
--     (사용자 조작 불가).
-- ============================================================


-- ── 1) 산책 기록 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.walk_records (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    pet_id      UUID REFERENCES public.pets(id) ON DELETE SET NULL,
    started_at  TIMESTAMPTZ NOT NULL,
    ended_at    TIMESTAMPTZ,
    distance_m  INTEGER NOT NULL DEFAULT 0,   -- 산책 거리(미터)
    duration_s  INTEGER NOT NULL DEFAULT 0,   -- 산책 시간(초)
    route       JSONB,                        -- 경로 좌표 [{lat,lng,t}] ← 핵심 위치정보
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.walk_records            IS '산책 기록(경로 위치정보 포함). LBS 신고 첨부2 증빙 대상.';
COMMENT ON COLUMN public.walk_records.route      IS '경로 좌표 배열 [{lat,lng,t}]. 개인위치정보 → RLS로 본인만 접근.';
COMMENT ON COLUMN public.walk_records.distance_m IS '산책 거리(미터).';
COMMENT ON COLUMN public.walk_records.duration_s IS '산책 시간(초).';


-- ── 2) 위치정보 이용·제공사실 확인자료 (취급대장) ────────────
-- subject_id 는 의도적으로 FK 미부여(증빙 보존 목적).
CREATE TABLE IF NOT EXISTS public.location_access_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_id  UUID NOT NULL,                                       -- 대상(개인위치정보주체)
    source      TEXT NOT NULL DEFAULT 'device_gps(apple/google)',    -- 취득경로(위치정보사업자)
    service     TEXT NOT NULL DEFAULT 'petspace_walk',               -- 제공 서비스
    provided_to TEXT,                                                -- 제공받는 자(제3자 없음 → NULL)
    used_at     TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE  public.location_access_log             IS '위치정보 이용·제공사실 확인자료(취급대장). 트리거(security definer)만 기록, 사용자 조작 불가. 위치정보법 보존 의무 대상이라 subject_id FK 미부여.';
COMMENT ON COLUMN public.location_access_log.subject_id  IS '개인위치정보주체(=walk_records.user_id 복사값). FK 미부여(탈퇴 후에도 증빙 보존).';
COMMENT ON COLUMN public.location_access_log.source      IS '위치정보 취득경로(위치정보사업자).';
COMMENT ON COLUMN public.location_access_log.provided_to IS '제공받는 제3자. 제3자 제공 없음 → NULL.';


-- ── 3) 인덱스 (FK 컬럼 — 기존 테이블 관례) ───────────────────
CREATE INDEX IF NOT EXISTS idx_walk_records_user_id        ON public.walk_records(user_id);
CREATE INDEX IF NOT EXISTS idx_walk_records_pet_id         ON public.walk_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_walk_records_started_at     ON public.walk_records(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_access_log_subject_id ON public.location_access_log(subject_id);


-- ── 4) 취급대장 자동 기록 트리거 ─────────────────────────────
-- walk_records INSERT 시 location_access_log 에 자동 기록.
-- SECURITY DEFINER: RLS 우회 기록(시스템 자동 기록). 취급대장에 INSERT 정책이
-- 없으므로 이 트리거 경로 외에는 어떤 사용자도 기록을 생성할 수 없다.
CREATE OR REPLACE FUNCTION public.log_location_access()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.location_access_log(subject_id, source, service, provided_to)
    VALUES (NEW.user_id, 'device_gps(apple/google)', 'petspace_walk', NULL);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_walk_log ON public.walk_records;
CREATE TRIGGER trg_walk_log
    AFTER INSERT ON public.walk_records
    FOR EACH ROW EXECUTE FUNCTION public.log_location_access();


-- ── 5) RLS ───────────────────────────────────────────────────
-- walk_records: 본인 데이터만 CRUD.
ALTER TABLE public.walk_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_walk" ON public.walk_records;
CREATE POLICY "select_own_walk" ON public.walk_records
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_walk" ON public.walk_records;
CREATE POLICY "insert_own_walk" ON public.walk_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_walk" ON public.walk_records;
CREATE POLICY "update_own_walk" ON public.walk_records
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_walk" ON public.walk_records;
CREATE POLICY "delete_own_walk" ON public.walk_records
    FOR DELETE USING (auth.uid() = user_id);

-- location_access_log: 본인 기록 SELECT 만 허용.
-- INSERT/UPDATE/DELETE 정책 미부여 → 트리거(security definer)만 기록.
-- 일반 사용자 세션의 직접 INSERT 는 RLS 로 거부된다(STEP 4 검증 항목).
ALTER TABLE public.location_access_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_log" ON public.location_access_log;
CREATE POLICY "select_own_log" ON public.location_access_log
    FOR SELECT USING (auth.uid() = subject_id);


-- ============================================================
-- STEP 4 검증 스크립트 (참고 — 대시보드에서 수동 실행)
-- ------------------------------------------------------------
-- 아래는 적용 후 검증용. 실제 캡처는 황정현이 진행.
-- ① RLS Enabled + 정책 목록 확인:
--    Authentication → Policies 에서 walk_records / location_access_log 노출 확인.
--    또는 SQL:
--      SELECT tablename, policyname, cmd
--      FROM pg_policies
--      WHERE tablename IN ('walk_records','location_access_log')
--      ORDER BY tablename, cmd;
--
-- ② walk_records INSERT 1건 → 취급대장 자동 기록 1건 검증:
--    (본인 세션에서. <UID> 는 auth.uid() 값으로 치환되거나 RLS가 채움)
--      INSERT INTO public.walk_records(user_id, started_at, distance_m, duration_s, route)
--      VALUES (auth.uid(), now(), 1200, 900,
--              '[{"lat":37.5,"lng":127.0,"t":0}]'::jsonb);
--      SELECT count(*) FROM public.location_access_log WHERE subject_id = auth.uid();
--      -- 기대: walk_records 1건 INSERT 직후 location_access_log 에 1건 자동 생성.
--
-- ③ 취급대장 직접 INSERT 거부 검증 (트리거 외 경로 차단 증명):
--    일반 사용자 세션에서 아래 실행 시 RLS 위반으로 거부되어야 한다.
--      INSERT INTO public.location_access_log(subject_id, source, service)
--      VALUES (auth.uid(), 'manual_test', 'petspace_walk');
--      -- 기대: ERROR: new row violates row-level security policy
--      --       (location_access_log 에 INSERT 정책이 없으므로 거부)
-- ============================================================
