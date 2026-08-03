-- L1: 30일 계정 영구 삭제가 건강 분석 이력 FK에서 중단되지 않도록 한다.
-- 운영 적용 전 health_history_user_id_fkey 이름과 영향 행을 read-only로 확인한다.

DO $$
BEGIN
  IF to_regclass('public.health_history') IS NOT NULL THEN
    ALTER TABLE public.health_history
      DROP CONSTRAINT IF EXISTS health_history_user_id_fkey;

    ALTER TABLE public.health_history
      ADD CONSTRAINT health_history_user_id_fkey
      FOREIGN KEY (user_id)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END;
$$;
