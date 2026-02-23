-- 이메일 인증이 완료되지 않은 사용자들의 users 테이블 레코드 삭제
-- auth.users에는 남겨두고, public.users에서만 삭제

-- 1. 이메일 인증이 완료되지 않은 사용자들을 public.users에서 삭제
DELETE FROM public.users
WHERE id IN (
    SELECT au.id
    FROM auth.users au
    WHERE au.email_confirmed_at IS NULL
);

-- 2. 결과 확인용 쿼리 (주석 해제하여 실행 가능)
-- SELECT
--     au.id,
--     au.email,
--     au.email_confirmed_at,
--     pu.id as public_user_id
-- FROM auth.users au
-- LEFT JOIN public.users pu ON au.id = pu.id
-- WHERE au.email_confirmed_at IS NULL;
