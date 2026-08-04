-- ============================================================
-- H-2 소셜 로그인 계정 자동 연동(email identity linking) 활성화
-- ------------------------------------------------------------
-- 작성일: 2026-07-04
-- 목적:
--   Apple/Google/Kakao 로그인 시 "이미 같은 이메일로 가입된 계정"이
--   있으면 Supabase Auth 가 자동으로 identity 를 기존 계정에 연동하도록
--   전제조건(기존 계정 이메일 '확인됨' 상태)을 충족시킨다.
--
-- 배경(왜 필요한가):
--   users.email 에 UNIQUE 제약이 있다(petspace_setup.sql).
--   Supabase Auth 자동 계정 연동은 "기존 계정의 email_confirmed_at 이
--   설정(확인됨)"일 때만 동작한다. 미확인 이메일에 자동 연동하면
--   pre-account-takeover 위험이 있어 GoTrue 가 막기 때문.
--   과거 플로우로 생성됐거나 OTP 인증을 완료하지 않은 기존 계정들이
--   email_confirmed_at = NULL(미확인) 상태 → Apple 로그인이 기존 계정에
--   연동되지 못하고 새 계정(새 id)을 만들다가 users_email_key(23505)
--   유니크 위반으로 실패한다.
--
--   ⚠️ 보안: 백필은 "소셜 identity(google/apple/kakao)를 가진 계정"으로
--      제한한다. 이들의 이메일은 provider 가 이미 검증했으므로 안전하다.
--      email/pw 계정은 OTP 인증 완료 시 GoTrue 가 email_confirmed_at 을
--      설정하므로 백필이 필요 없고, OTP 미완료 계정을 백필하면 공격자가
--      남의 이메일로 선점해둔 계정에 피해자의 소셜 로그인이 연동되는
--      pre-account-takeover 가 가능해진다(어차피 미완료 계정은 로그인
--      게이트에 막혀 있어 백필하지 않아도 잃는 것이 없다).
--      admin API 로 생성된 카카오 계정(identity 가 'email'인 경우)은 다음
--      카카오 로그인 시 confirm_kakao_user_by_email RPC 가 확인 처리한다.
--
-- 적용 방법:
--   Supabase Dashboard → SQL Editor 에서 본 파일 전체를 실행.
--
-- ⚠️ Authentication → Providers → Email → "Confirm email" 은 반드시 ON 유지.
--   앱의 이메일 가입은 GoTrue 의 Confirm signup 메일(6자리 OTP, {{ .Token }}
--   템플릿)에 의존한다(signUpWithEmail → resend(OtpType.signup) → verifyOtp).
--   OFF 로 바꾸면 확인 메일이 발송되지 않고 가입 즉시 확인 처리되어 OTP
--   인증이 무력화되고, 남의 이메일로 가입 → 소셜 로그인 자동 연동을 가로채는
--   계정 선점(pre-account-takeover)이 가능해진다.
--   연동 전제조건(이메일 '확인됨')은 ON 상태에서도 전부 충족된다:
--     · 기존 계정   → 아래 1) 백필
--     · 신규 이메일 → OTP 인증 완료 시 GoTrue 가 설정
--     · Apple/Google→ provider 검증 이메일 → GoTrue 가 자동 설정
--     · Kakao       → confirm_kakao_user_by_email RPC
-- ============================================================

-- ------------------------------------------------------------
-- 0) handle_new_user 트리거 안전화 — 고아 판정에 auth.users 부재 확인 추가
--    기존 트리거(윈도우 세션 수정본)는 "같은 email·다른 id" 행을 무조건
--    고아로 보고 삭제했다. 그러나 소셜 로그인이 기존 계정에 연동되지 못하고
--    같은 email 로 새 auth 계정을 만드는 경우(본 마이그레이션이 고치려는
--    바로 그 상황), 기존 행은 살아있는 계정이므로 삭제하면 CASCADE 로
--    펫·게시물·채팅까지 전부 지워진다. "auth.users 에 해당 id 가 없는"
--    진짜 고아만 삭제하도록 교정한다. (petspace_setup.sql 과 동일 정의)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_orphan_id UUID;
    v_orphan_deleted_at TIMESTAMPTZ;
BEGIN
    BEGIN
        -- 진짜 고아 행(같은 email·다른 id·auth.users 에 없음)만 정리 대상.
        -- 살아있는 중복은 그대로 두어 INSERT 가 email 충돌로 실패하게 하고
        -- (아래 EXCEPTION 로그), 앱 단의 23505 안내 메시지로 처리한다.
        SELECT u.id, u.deleted_at INTO v_orphan_id, v_orphan_deleted_at
        FROM public.users u
        WHERE u.email = NEW.email
          AND u.id <> NEW.id
          AND NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = u.id)
        LIMIT 1;

        -- deleted_at IS NOT NULL(탈퇴 유예 중)이면 30일 차단 의도를 존중해 유지.
        IF v_orphan_id IS NOT NULL AND v_orphan_deleted_at IS NULL THEN
            DELETE FROM public.users WHERE id = v_orphan_id;
        END IF;

        INSERT INTO public.users (id, email, display_name, photo_url, provider, is_onboarding_completed)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
            COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
            COALESCE(NEW.raw_user_meta_data->>'provider', 'email'),
            FALSE
        )
        ON CONFLICT (id) DO UPDATE SET
            provider = COALESCE(NEW.raw_user_meta_data->>'provider', users.provider),
            photo_url = COALESCE(NEW.raw_user_meta_data->>'photo_url', users.photo_url),
            updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'handle_new_user error for %: %', NEW.email, SQLERRM;
    END;
    RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- 1) 기존 계정 이메일 백필 — 자동 연동 전제조건 충족
--    (소셜 identity 를 가진 미확인 계정만 확인 처리. 위 보안 주석 참조)
-- ------------------------------------------------------------
UPDATE auth.users u
SET email_confirmed_at = COALESCE(u.email_confirmed_at, NOW()),
    updated_at = NOW()
WHERE u.email IS NOT NULL
  AND u.email_confirmed_at IS NULL
  AND EXISTS (
      SELECT 1 FROM auth.identities i
      WHERE i.user_id = u.id
        AND i.provider IN ('google', 'apple', 'kakao')
  );

-- ------------------------------------------------------------
-- 2) 본인 이메일 확인 RPC — 소셜 로그인 직후 앱에서 호출해 향후 연동 보장
--    ⚠️ 반드시 "자기 세션 계정"만 확인 처리한다(auth.uid() 기준).
--       임의 이메일을 받는 형태(confirm_kakao_user_by_email 방식)는 미인증
--       선점 계정을 공격자가 확인 처리해 소셜 연동을 가로챌 수 있다.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS confirm_user_email(text);
DROP FUNCTION IF EXISTS confirm_my_email();
CREATE OR REPLACE FUNCTION confirm_my_email()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = auth.uid()
      AND email_confirmed_at IS NULL;

    RETURN json_build_object('success', true, 'user_id', auth.uid());
END;
$$;

GRANT EXECUTE ON FUNCTION confirm_my_email() TO authenticated;

-- ------------------------------------------------------------
-- 3) orphan auth 계정 정리 함수
--    과거 실패한 소셜 로그인이 남긴 "auth.users 에는 있으나 public.users
--    프로필이 없는" 계정을 제거한다. 자동 연동은 identity 최초 생성 시점에만
--    일어나므로, 남아있는 빈 Apple 계정을 지워야 다음 로그인에서 fresh
--    identity 가 생성되어 (확인 처리된) 기존 계정으로 정상 연동된다.
--
--    반환: 삭제된 계정 수. 삭제 전 검토하려면 아래 SELECT 를 먼저 실행:
--      SELECT u.id, u.email, u.created_at
--      FROM auth.users u
--      LEFT JOIN public.users p ON p.id = u.id
--      WHERE p.id IS NULL;
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS cleanup_orphan_auth_users();
CREATE OR REPLACE FUNCTION cleanup_orphan_auth_users()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    WITH del AS (
        DELETE FROM auth.users u
        WHERE NOT EXISTS (
            SELECT 1 FROM public.users p WHERE p.id = u.id
        )
        RETURNING u.id
    )
    SELECT count(*) INTO v_deleted FROM del;

    RETURN v_deleted;
END;
$$;

-- orphan 정리 즉시 실행(과거 실패 Apple 계정 제거).
-- 진행 중인 정상 가입 계정을 실수로 지우지 않도록, 이미 프로필이 없는
-- 계정만 대상으로 한다(정상 가입은 트리거가 즉시 프로필 생성).
SELECT cleanup_orphan_auth_users() AS orphan_accounts_removed;

-- ============================================================
-- 완료. 이후 Apple 로그인 → 같은 이메일 기존 계정으로 자동 연동됨.
-- ============================================================
