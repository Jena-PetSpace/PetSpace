-- Kakao OIDC 전환 전 운영 현황 SELECT-only 집계
--
-- 실행 위치: Supabase Dashboard > SQL Editor (사람이 직접 실행)
-- 예상 결과: 숫자와 boolean으로만 구성된 정확히 한 행
-- 안전 근거: SELECT/CTE와 시스템 권한 조회만 사용하며 DML/DDL/RPC 호출이 없다.
-- 금지: WHERE 절 제거, 상세 행/이메일/UUID/subject 출력, 결과 원문 외부 전송
-- 공유: 각 열의 숫자와 boolean만 전달한다.
-- 전제: hosted Supabase의 auth.users/auth.identities 및 public.users 정본 스키마

WITH
kakao_identity_by_user AS (
  SELECT
    i.user_id,
    count(*)::bigint AS identity_count,
    count(DISTINCT coalesce(
      nullif(i.identity_data->>'sub', ''),
      nullif(i.provider_id, '')
    ))::bigint AS subject_count,
    min(coalesce(
      nullif(i.identity_data->>'sub', ''),
      nullif(i.provider_id, '')
    )) AS one_verified_subject
  FROM auth.identities AS i
  WHERE i.provider = 'kakao'
  GROUP BY i.user_id
),
email_identity_by_user AS (
  SELECT
    i.user_id,
    count(*)::bigint AS email_identity_count
  FROM auth.identities AS i
  WHERE i.provider = 'email'
  GROUP BY i.user_id
),
kakao_candidates AS (
  SELECT
    au.id,
    au.email AS auth_email,
    au.email_confirmed_at,
    nullif(au.encrypted_password, '') IS NOT NULL AS has_encrypted_password,
    pu.id IS NOT NULL AS has_public_profile,
    pu.email AS profile_email,
    pu.provider AS profile_provider,
    pu.deleted_at AS profile_deleted_at,
    nullif(au.raw_user_meta_data->>'kakao_id', '') AS unverified_metadata_kakao_id,
    coalesce(kib.identity_count, 0) AS kakao_identity_count,
    coalesce(kib.subject_count, 0) AS kakao_identity_subject_count,
    kib.one_verified_subject,
    coalesce(eib.email_identity_count, 0) AS email_identity_count
  FROM auth.users AS au
  LEFT JOIN public.users AS pu ON pu.id = au.id
  LEFT JOIN kakao_identity_by_user AS kib ON kib.user_id = au.id
  LEFT JOIN email_identity_by_user AS eib ON eib.user_id = au.id
  WHERE pu.provider = 'kakao'
     OR lower(coalesce(au.email, '')) LIKE 'kakao!_%@kakao.user' ESCAPE '!'
     OR au.raw_app_meta_data->>'provider' = 'kakao'
     OR jsonb_exists(
       coalesce(au.raw_app_meta_data->'providers', '[]'::jsonb),
       'kakao'
     )
     OR nullif(au.raw_user_meta_data->>'kakao_id', '') IS NOT NULL
     OR coalesce(kib.identity_count, 0) > 0
),
verified_identity_subjects AS (
  SELECT DISTINCT
    i.user_id,
    coalesce(
      nullif(i.identity_data->>'sub', ''),
      nullif(i.provider_id, '')
    ) AS verified_subject
  FROM auth.identities AS i
  JOIN kakao_candidates AS kc ON kc.id = i.user_id
  WHERE i.provider = 'kakao'
    AND coalesce(
      nullif(i.identity_data->>'sub', ''),
      nullif(i.provider_id, '')
    ) IS NOT NULL
),
verified_duplicate_subject_groups AS (
  SELECT vis.verified_subject
  FROM verified_identity_subjects AS vis
  GROUP BY vis.verified_subject
  HAVING count(DISTINCT vis.user_id) > 1
),
metadata_duplicate_subject_groups AS (
  SELECT kc.unverified_metadata_kakao_id
  FROM kakao_candidates AS kc
  WHERE kc.unverified_metadata_kakao_id IS NOT NULL
  GROUP BY kc.unverified_metadata_kakao_id
  HAVING count(DISTINCT kc.id) > 1
),
function_contracts AS (
  SELECT *
  FROM (VALUES
    (
      'confirm_kakao_user_by_email',
      to_regprocedure('public.confirm_kakao_user_by_email(text)')
    ),
    (
      'confirm_my_email',
      to_regprocedure('public.confirm_my_email()')
    )
  ) AS contracts(contract_name, function_oid)
),
function_acl AS (
  SELECT
    fc.contract_name,
    fc.function_oid,
    EXISTS (
      SELECT 1
      FROM pg_proc AS p
      CROSS JOIN LATERAL aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) AS privilege
      WHERE p.oid = fc.function_oid::oid
        AND privilege.grantee = 0
        AND privilege.privilege_type = 'EXECUTE'
    ) AS public_can_execute,
    CASE
      WHEN to_regrole('anon') IS NULL OR fc.function_oid IS NULL THEN false
      ELSE has_function_privilege(
        to_regrole('anon'), fc.function_oid::oid, 'EXECUTE'
      )
    END AS anon_can_execute,
    CASE
      WHEN to_regrole('authenticated') IS NULL OR fc.function_oid IS NULL THEN false
      ELSE has_function_privilege(
        to_regrole('authenticated'), fc.function_oid::oid, 'EXECUTE'
      )
    END AS authenticated_can_execute
  FROM function_contracts AS fc
),
email_contract AS (
  SELECT
    (c.is_nullable = 'NO') AS public_users_email_not_null
  FROM information_schema.columns AS c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'users'
    AND c.column_name = 'email'
)
SELECT
  (SELECT count(*) FROM kakao_candidates)::bigint
    AS kakao_candidate_total,
  (SELECT count(*) FROM public.users WHERE provider = 'kakao')::bigint
    AS public_profile_kakao_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE lower(coalesce(auth_email, '')) LIKE 'kakao!_%@kakao.user' ESCAPE '!')::bigint
    AS pseudo_email_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE auth_email IS NOT NULL
      AND lower(auth_email) NOT LIKE 'kakao!_%@kakao.user' ESCAPE '!')::bigint
    AS real_email_total,
  (SELECT count(*) FROM kakao_candidates WHERE auth_email IS NULL)::bigint
    AS null_auth_email_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE email_confirmed_at IS NOT NULL)::bigint
    AS candidate_email_confirmed_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE email_confirmed_at IS NOT NULL
      AND lower(coalesce(auth_email, '')) LIKE 'kakao!_%@kakao.user' ESCAPE '!')::bigint
    AS pseudo_email_confirmed_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE email_confirmed_at IS NOT NULL
      AND auth_email IS NOT NULL
      AND lower(auth_email) NOT LIKE 'kakao!_%@kakao.user' ESCAPE '!')::bigint
    AS real_email_confirmed_total,
  (SELECT count(DISTINCT user_id) FROM kakao_identity_by_user)::bigint
    AS kakao_identity_user_total,
  (SELECT count(*) FROM kakao_candidates WHERE kakao_identity_count > 0)::bigint
    AS candidate_with_kakao_identity_total,
  (SELECT count(*) FROM kakao_candidates WHERE kakao_identity_count = 0)::bigint
    AS candidate_without_kakao_identity_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE kakao_identity_subject_count > 1)::bigint
    AS candidate_with_multiple_verified_subjects_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE one_verified_subject IS NULL)::bigint
    AS candidate_without_verified_subject_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE unverified_metadata_kakao_id IS NOT NULL)::bigint
    AS candidate_with_unverified_metadata_hint_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE one_verified_subject IS NULL
      AND unverified_metadata_kakao_id IS NULL)::bigint
    AS candidate_without_any_subject_hint_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE lower(coalesce(auth_email, '')) LIKE 'kakao!_%@kakao.user' ESCAPE '!'
      AND one_verified_subject =
          regexp_replace(split_part(lower(auth_email), '@', 1), '^kakao_', ''))::bigint
    AS pseudo_email_verified_subject_match_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE lower(coalesce(auth_email, '')) LIKE 'kakao!_%@kakao.user' ESCAPE '!'
      AND unverified_metadata_kakao_id =
          regexp_replace(split_part(lower(auth_email), '@', 1), '^kakao_', ''))::bigint
    AS pseudo_email_metadata_hint_match_total,
  (SELECT count(*) FROM verified_duplicate_subject_groups)::bigint
    AS verified_duplicate_subject_group_total,
  (SELECT count(*) FROM metadata_duplicate_subject_groups)::bigint
    AS unverified_metadata_duplicate_group_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE email_identity_count > 0)::bigint
    AS candidate_with_email_identity_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE has_encrypted_password)::bigint
    AS candidate_with_encrypted_password_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE profile_deleted_at IS NOT NULL)::bigint
    AS candidate_deleted_profile_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE profile_email IS NOT NULL
      AND auth_email IS NOT NULL
      AND lower(profile_email) <> lower(auth_email))::bigint
    AS same_uuid_email_mismatch_total,
  (SELECT count(DISTINCT kc.id)
   FROM kakao_candidates AS kc
   JOIN public.users AS other_profile
     ON lower(other_profile.email) = lower(kc.auth_email)
    AND other_profile.id <> kc.id
   WHERE kc.auth_email IS NOT NULL)::bigint
    AS cross_owner_email_collision_total,
  (SELECT count(*) FROM kakao_candidates
    WHERE NOT has_public_profile)::bigint
    AS candidate_without_public_profile_total,
  (SELECT count(*)
   FROM public.users AS pu
   LEFT JOIN auth.users AS au ON au.id = pu.id
   WHERE pu.provider = 'kakao' AND au.id IS NULL)::bigint
    AS kakao_profile_without_auth_user_total,
  coalesce((SELECT public_users_email_not_null FROM email_contract), false)
    AS public_users_email_not_null,
  coalesce((SELECT function_oid IS NOT NULL FROM function_acl
    WHERE contract_name = 'confirm_kakao_user_by_email'), false)
    AS risky_function_exists,
  coalesce((SELECT public_can_execute FROM function_acl
    WHERE contract_name = 'confirm_kakao_user_by_email'), false)
    AS risky_function_public_can_execute,
  coalesce((SELECT anon_can_execute FROM function_acl
    WHERE contract_name = 'confirm_kakao_user_by_email'), false)
    AS risky_function_anon_can_execute,
  coalesce((SELECT authenticated_can_execute FROM function_acl
    WHERE contract_name = 'confirm_kakao_user_by_email'), false)
    AS risky_function_authenticated_can_execute,
  coalesce((SELECT function_oid IS NOT NULL FROM function_acl
    WHERE contract_name = 'confirm_my_email'), false)
    AS self_confirm_function_exists,
  coalesce((SELECT public_can_execute FROM function_acl
    WHERE contract_name = 'confirm_my_email'), false)
    AS self_confirm_public_can_execute,
  coalesce((SELECT anon_can_execute FROM function_acl
    WHERE contract_name = 'confirm_my_email'), false)
    AS self_confirm_anon_can_execute,
  coalesce((SELECT authenticated_can_execute FROM function_acl
    WHERE contract_name = 'confirm_my_email'), false)
    AS self_confirm_authenticated_can_execute;
