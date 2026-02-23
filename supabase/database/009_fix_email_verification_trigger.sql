-- 이메일 인증 완료된 사용자만 users 테이블에 추가되도록 수정

-- 기존 trigger 삭제
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 기존 함수 삭제
DROP FUNCTION IF EXISTS handle_new_user();

-- 새로운 함수: 이메일 인증 완료 시에만 users 테이블에 추가
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- 이메일 인증이 완료된 경우에만 users 테이블에 추가
    IF NEW.email_confirmed_at IS NOT NULL THEN
        INSERT INTO public.users (id, email, display_name, photo_url, is_onboarding_completed)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
            NEW.raw_user_meta_data->>'photo_url',
            FALSE
        )
        ON CONFLICT (id) DO NOTHING;  -- 이미 존재하면 무시
    END IF;
    RETURN NEW;
END;
$$;

-- INSERT와 UPDATE 모두에 대응하는 trigger 생성
-- INSERT: 소셜 로그인 (즉시 인증됨)
-- UPDATE: 이메일 인증 완료 시
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    WHEN (NEW.email_confirmed_at IS NOT NULL)
    EXECUTE FUNCTION handle_new_user();
