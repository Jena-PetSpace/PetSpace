-- ============================================================================
-- I1: 약관 동의 기록 (세션4)
-- users 테이블에 약관/개인정보/위치/마케팅 동의 시점·버전 기록 컬럼 추가.
-- 스토어 심사·개인정보보호법상 "동의 증명"을 위해 동의 시점과 버전을 보존한다.
--
-- 적용: 기존 운영 DB는 이 파일을 SQL Editor에서 실행(ALTER, 멱등).
--       신규 setup은 petspace_setup.sql에도 동일 컬럼이 반영됨.
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS terms_agreed_at      TIMESTAMPTZ,   -- 서비스 이용약관 동의 시점
  ADD COLUMN IF NOT EXISTS privacy_agreed_at    TIMESTAMPTZ,   -- 개인정보 처리방침 동의 시점
  ADD COLUMN IF NOT EXISTS location_agreed_at   TIMESTAMPTZ,   -- 위치기반 서비스 약관 동의 시점 (선택)
  ADD COLUMN IF NOT EXISTS marketing_agreed_at  TIMESTAMPTZ,   -- 마케팅 정보 수신 동의 시점 (선택)
  ADD COLUMN IF NOT EXISTS terms_version        VARCHAR(20),   -- 동의 당시 이용약관 버전 (예: service_terms_v7)
  ADD COLUMN IF NOT EXISTS privacy_version      VARCHAR(20),   -- 동의 당시 개인정보처리방침 버전 (예: privacy_policy_v6)
  ADD COLUMN IF NOT EXISTS location_version     VARCHAR(20),   -- 동의 당시 위치약관 버전 (예: location_terms_v5)
  ADD COLUMN IF NOT EXISTS marketing_version    VARCHAR(20);   -- 동의 당시 마케팅 동의 버전 (예: marketing_consent_v4)

COMMENT ON COLUMN public.users.terms_agreed_at IS '서비스 이용약관 동의 시점 (NULL=미동의)';
COMMENT ON COLUMN public.users.location_agreed_at IS '위치기반 서비스 약관 동의 시점 (선택, NULL=미동의)';
COMMENT ON COLUMN public.users.marketing_agreed_at IS '마케팅 수신 동의 시점 (선택, NULL=미동의)';
