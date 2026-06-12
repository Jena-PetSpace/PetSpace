-- ================================================================
-- G-1: 계정 30일 soft delete
-- 실행: Supabase Dashboard SQL Editor에서 수동 실행 (CI/CLI 자동 실행 금지)
-- 정책:
--   * 탈퇴 = users.deleted_at 기록. 30일 내 재로그인 시 복구 가능.
--   * deleted_at NOT NULL 계정: 본인 외 프로필 조회 차단, posts/comments 타인 조회 차단.
--   * chat_messages는 대화 무결성을 위해 유지 — 앱에서 작성자 미조회 시
--     "탈퇴한 사용자"로 표시 (앱 fallback, 별도 트랙).
--   * 30일 경과분은 pg_cron → Edge Function purge-deleted-accounts 가 영구 삭제.
-- ================================================================

-- 1) users.deleted_at 컬럼
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at
    ON users(deleted_at) WHERE deleted_at IS NOT NULL;

-- 2) RLS: 탈퇴 계정 프로필은 본인만 조회 (복구 안내용)
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON users;
CREATE POLICY "Authenticated users can view all profiles" ON users
    FOR SELECT TO authenticated
    USING (deleted_at IS NULL OR auth.uid() = id);

-- 3) RLS: 탈퇴 계정의 posts/comments 타인 조회 차단
--    기존 정책 원문: USING (deleted_at IS NULL) — posts/comments 자체의 soft delete 조건.
--    신규: 기존 조건 그대로 보존 + 작성자 탈퇴 차단 조건 AND 추가.
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = posts.author_id AND u.deleted_at IS NOT NULL
        )
    );

DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = comments.author_id AND u.deleted_at IS NOT NULL
        )
    );

-- 4) soft delete RPC (Edge Function 장애 시 폴백 겸 단일 경로)
CREATE OR REPLACE FUNCTION request_account_deletion()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NOW()
    WHERE id = auth.uid() AND deleted_at IS NULL;
END;
$$;

-- 5) 복구 RPC (SECURITY DEFINER — RLS 우회하여 본인 deleted_at 해제)
CREATE OR REPLACE FUNCTION restore_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NULL
    WHERE id = auth.uid() AND deleted_at IS NOT NULL;
END;
$$;

-- 6) 기존 hard delete RPC 제거 (승인 조건 — 2026-06-12)
--    SECURITY DEFINER 즉시 삭제 함수가 남으면 30일 soft delete 정책 우회 경로가 공존.
--    앱 호출처는 1-C에서 제거됨, 그 외 호출처 0건 확인 후 DROP.
--    (petspace_setup.sql:927-937 확인 결과: 인자 없음·auth.uid() 기준 → 시그니처 일치)
DROP FUNCTION IF EXISTS delete_user_account();

-- 7) pg_cron 일배치 등록 (대시보드에서 수동 실행 — URL·시크릿 치환 필요)
-- 매일 03:00 KST(18:00 UTC) purge Edge Function 호출:
-- SELECT cron.schedule(
--   'purge-deleted-accounts-daily', '0 18 * * *',
--   $$ SELECT net.http_post(
--        url := 'https://<PROJECT_REF>.supabase.co/functions/v1/purge-deleted-accounts',
--        headers := jsonb_build_object('x-purge-secret', '<PURGE_SHARED_SECRET>')
--      ) $$
-- );
