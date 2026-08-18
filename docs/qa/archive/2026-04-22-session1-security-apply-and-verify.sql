-- ============================================================================
-- 세션1 보안 수정 "적용 + 검증" 통합 스크립트 (1-C breeds RLS / 1-B increment_user_points)
--
-- 실행 위치: Supabase Dashboard → SQL Editor → 전체 선택 후 Run
-- 결과: 맨 아래 SELECT로 Results 탭에 표(table)로 출력된다. (NOTICE 안 봐도 됨)
--
-- ⚠️ SQL Editor 기본 컨텍스트는 postgres/service_role(BYPASSRLS)이므로
--    검증 블록은 DO $$ 안에서 SET LOCAL role authenticated/anon 으로 역할을 흉내 낸 뒤
--    측정하고, RESET ROLE 후 결과를 임시 테이블에 기록한다.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- PART 0. 수정본 적용 (1-B / 1-C) — 이미 적용돼 있어도 멱등이라 재실행 안전
-- ════════════════════════════════════════════════════════════════════════

-- [1-B] increment_user_points: 2-파라미터 오버로드 제거(모호성 해소) + auth.uid() 강제
DROP FUNCTION IF EXISTS increment_user_points(UUID, INT);

CREATE OR REPLACE FUNCTION increment_user_points(
  p_user_id    UUID,
  p_points     INT,
  p_type       TEXT DEFAULT 'quest',
  p_description TEXT DEFAULT '퀘스트 완료'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION '인증되지 않은 호출입니다.' USING ERRCODE = '42501';
  END IF;
  INSERT INTO point_transactions (user_id, amount, type, description)
  VALUES (v_uid, p_points, p_type, p_description);
END;
$$;

REVOKE EXECUTE ON FUNCTION increment_user_points(UUID, INTEGER, TEXT, TEXT) FROM anon;

-- [1-C] breeds 쓰기 정책 3개 제거 (SELECT만 유지)
DROP POLICY IF EXISTS "breeds: 인증 사용자 삽입" ON public.breeds;
DROP POLICY IF EXISTS "breeds: 인증 사용자 수정" ON public.breeds;
DROP POLICY IF EXISTS "breeds: 인증 사용자 삭제" ON public.breeds;


-- ════════════════════════════════════════════════════════════════════════
-- PART 1. 검증 결과를 담을 임시 테이블 (세션 종료 시 자동 소멸)
-- ════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS _sess1_verify;
CREATE TEMP TABLE _sess1_verify (
  seq     int generated always as identity,
  항목     text,
  결과     text,
  기대     text,
  판정     text
);


-- ════════════════════════════════════════════════════════════════════════
-- PART 2. 1-C breeds: authenticated 로 SELECT 허용 / 쓰기 거부
-- ════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_cnt     integer;
  v_rows    integer;
  v_sel_ok  boolean;
  v_ins_blk boolean := false;
  v_upd_blk boolean := false;
  v_del_blk boolean := false;
BEGIN
  -- authenticated 역할 흉내
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claims',
    '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000001"}', true);

  -- (b) SELECT 허용?
  BEGIN
    SELECT count(*) INTO v_cnt FROM public.breeds;
    v_sel_ok := (v_cnt > 0);
  EXCEPTION WHEN insufficient_privilege THEN
    v_sel_ok := false;
  END;

  -- (c) INSERT 거부?
  BEGIN
    INSERT INTO public.breeds (species, name_ko, name_en)
    VALUES ('dog', '__검증용_삽입__', 'verify-insert');
    -- 성공하면 거부 안 된 것 → 직접 롤백 위해 예외 유발 없이 표시
    v_ins_blk := false;
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    v_ins_blk := true;
  END;

  -- (d) UPDATE 거부? (RLS상 0건이거나 권한오류 → 둘 다 차단)
  BEGIN
    UPDATE public.breeds SET name_en = 'hacked' WHERE species = 'dog';
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_upd_blk := (v_rows = 0);
  EXCEPTION WHEN insufficient_privilege THEN
    v_upd_blk := true;
  END;

  -- (e) DELETE 거부?
  BEGIN
    DELETE FROM public.breeds WHERE species = 'dog';
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_del_blk := (v_rows = 0);
  EXCEPTION WHEN insufficient_privilege THEN
    v_del_blk := true;
  END;

  -- 역할 원복 후 결과 기록 (임시테이블 쓰기 권한 확보)
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);

  INSERT INTO _sess1_verify(항목, 결과, 기대, 판정) VALUES
    ('1-C-b breeds SELECT 허용', v_sel_ok::text,  'true',  CASE WHEN v_sel_ok  THEN 'PASS' ELSE 'FAIL' END),
    ('1-C-c breeds INSERT 거부', v_ins_blk::text, 'true',  CASE WHEN v_ins_blk THEN 'PASS' ELSE 'FAIL' END),
    ('1-C-d breeds UPDATE 거부', v_upd_blk::text, 'true',  CASE WHEN v_upd_blk THEN 'PASS' ELSE 'FAIL' END),
    ('1-C-e breeds DELETE 거부', v_del_blk::text, 'true',  CASE WHEN v_del_blk THEN 'PASS' ELSE 'FAIL' END);
END $$;


-- ════════════════════════════════════════════════════════════════════════
-- PART 3. 1-B increment_user_points: auth.uid() 강제 / 비인증·anon 차단
-- ════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_uid_block boolean := false;  -- 비인증 차단됐나
  v_anon_block boolean := false; -- anon 차단됐나
BEGIN
  -- (b) 비인증(auth.uid() NULL) 호출 차단?
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claims', '', true);  -- claims 없음 → uid NULL
  BEGIN
    PERFORM increment_user_points(
      '00000000-0000-0000-0000-0000000000BB'::uuid, 50, 'quest', '검증-비인증');
  EXCEPTION WHEN insufficient_privilege THEN
    v_uid_block := true;
  END;
  RESET ROLE;

  -- (c) anon 호출 차단? (EXECUTE REVOKE)
  SET LOCAL role anon;
  BEGIN
    PERFORM increment_user_points(
      '00000000-0000-0000-0000-0000000000BB'::uuid, 50, 'quest', '검증-anon');
  EXCEPTION WHEN insufficient_privilege THEN
    v_anon_block := true;
  END;
  RESET ROLE;

  INSERT INTO _sess1_verify(항목, 결과, 기대, 판정) VALUES
    ('1-B-b 비인증(uid NULL) 차단', v_uid_block::text,  'true', CASE WHEN v_uid_block  THEN 'PASS' ELSE 'FAIL' END),
    ('1-B-c anon EXECUTE 차단',     v_anon_block::text, 'true', CASE WHEN v_anon_block THEN 'PASS' ELSE 'FAIL' END);
END $$;


-- ════════════════════════════════════════════════════════════════════════
-- PART 4. 1-B auth.uid() 강제 검증 (타인 user_id 넘겨도 본인에게만 적립)
--   ⚠️ point_transactions.user_id 가 auth.users FK면, 가짜 uuid는 FK 위반 발생.
--      그래서 이 케이스는 "실제 존재하는 두 uid"가 필요 → 선택적으로 수행한다.
--      아래 v_caller / v_victim 에 실제 uid 2개를 넣고 do_run := true 로 바꾸면 검증.
--      (do_run=false면 SKIP 으로 기록)
-- ════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  do_run   boolean := false;  -- ← 실제 uid 2개 넣고 true 로 바꾸면 이 검증 수행
  v_caller uuid := '00000000-0000-0000-0000-0000000000AA';  -- ← 점검자 본인 uid
  v_victim uuid := '00000000-0000-0000-0000-0000000000BB';  -- ← 임의 타인 uid
  v_aa int; v_bb int; v_pass boolean;
BEGIN
  IF NOT do_run THEN
    INSERT INTO _sess1_verify(항목, 결과, 기대, 판정) VALUES
      ('1-B-a auth.uid() 강제(타인지정)', 'SKIP(실uid 필요)', 'AA=1,BB=0', 'SKIP');
    RETURN;
  END IF;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claims',
    format('{"role":"authenticated","sub":"%s"}', v_caller), true);

  PERFORM increment_user_points(v_victim, 50, 'quest', '검증-타인지정');

  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);

  SELECT count(*) INTO v_aa FROM point_transactions
    WHERE user_id = v_caller AND description = '검증-타인지정';
  SELECT count(*) INTO v_bb FROM point_transactions
    WHERE user_id = v_victim AND description = '검증-타인지정';
  v_pass := (v_aa >= 1 AND v_bb = 0);

  -- 검증용 적립 정리
  DELETE FROM point_transactions WHERE description = '검증-타인지정';

  INSERT INTO _sess1_verify(항목, 결과, 기대, 판정) VALUES
    ('1-B-a auth.uid() 강제(타인지정)',
     format('본인(AA)=%s, 타인(BB)=%s', v_aa, v_bb), 'AA>=1,BB=0',
     CASE WHEN v_pass THEN 'PASS' ELSE 'FAIL' END);
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _sess1_verify(항목, 결과, 기대, 판정) VALUES
    ('1-B-a auth.uid() 강제(타인지정)', 'ERROR: '||SQLERRM, 'AA>=1,BB=0', 'CHECK');
END $$;


-- ════════════════════════════════════════════════════════════════════════
-- PART 5. breeds 현재 정책 목록도 함께 기록 (1-C-a)
-- ════════════════════════════════════════════════════════════════════════
INSERT INTO _sess1_verify(항목, 결과, 기대, 판정)
SELECT '1-C-a breeds 정책: '||polname,
       CASE polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT'
                   WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE'
                   WHEN '*' THEN 'ALL' END,
       'SELECT만 존재', 'INFO'
FROM pg_policy pol JOIN pg_class c ON c.oid = pol.polrelid
WHERE c.relname = 'breeds';


-- ════════════════════════════════════════════════════════════════════════
-- ★ 최종 결과 출력 (Results 탭에 표로 표시) ★
-- ════════════════════════════════════════════════════════════════════════
SELECT 항목, 결과, 기대, 판정 FROM _sess1_verify ORDER BY seq;
