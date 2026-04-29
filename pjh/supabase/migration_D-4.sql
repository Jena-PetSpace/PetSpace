-- ============================================================
-- D-4 Migration: FCM 푸시 알림 트리거
-- 실행 위치: Supabase SQL Editor
-- 선행 조건:
--   1. Supabase Vault에 FIREBASE_SERVICE_ACCOUNT_KEY 등록
--   2. Supabase Vault에 FIREBASE_PROJECT_ID 등록
--   3. Edge Function send-push-notification 배포 완료
--   4. ALTER DATABASE postgres SET "app.settings.supabase_url" = '...'; 실행
-- ============================================================

-- ── 1. user_devices 테이블 (FCM 토큰 저장) ──────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_devices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token   text NOT NULL,
  platform    text NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'other')),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fcm_token)
);

-- RLS
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_devices: 본인 기기만 읽기"
  ON public.user_devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기만 삽입"
  ON public.user_devices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기만 수정"
  ON public.user_devices FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "user_devices: 본인 기기만 삭제"
  ON public.user_devices FOR DELETE
  USING (auth.uid() = user_id);

-- ── 2. notifications 트리거 함수 ─────────────────────────────────────────────
-- notifications 테이블에 새 행 INSERT 시 Edge Function 호출

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _supabase_url   text;
  _service_key    text;
  _payload        jsonb;
  _data           jsonb;
BEGIN
  -- app.settings.supabase_url 은 ALTER DATABASE 로 설정
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_key  := current_setting('app.settings.service_role_key', true);

  -- data 필드 구성 (type + post_id)
  _data := jsonb_build_object('type', NEW.type);
  IF NEW.post_id IS NOT NULL THEN
    _data := _data || jsonb_build_object('post_id', NEW.post_id::text);
  END IF;
  IF NEW.sender_id IS NOT NULL THEN
    _data := _data || jsonb_build_object('sender_id', NEW.sender_id::text);
  END IF;

  _payload := jsonb_build_object(
    'user_id', NEW.user_id::text,
    'title',   NEW.title,
    'body',    NEW.body,
    'data',    _data
  );

  -- Edge Function 비동기 호출 (net.http_post — pg_net 확장 필요)
  PERFORM net.http_post(
    url     := _supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _service_key
    ),
    body    := _payload
  );

  RETURN NEW;

EXCEPTION WHEN others THEN
  -- 알림 발송 실패가 INSERT 자체를 막지 않도록 예외 무시
  RAISE WARNING 'notify_push_on_notification 오류: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- ── 3. 트리거 연결 ───────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;

CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_on_notification();

-- ── 4. pg_net 확장 활성화 (미설치 시 실행) ──────────────────────────────────
-- Supabase 대시보드 Extensions 탭에서 활성화하거나 아래 실행:
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── 5. 실행 후 확인 쿼리 ────────────────────────────────────────────────────
-- SELECT * FROM user_devices LIMIT 5;
-- SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'trg_push_on_notification';
