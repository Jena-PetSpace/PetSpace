# send-push-notification Edge Function

Cron 기반 폴링 방식으로 `notifications` 테이블의 미발송 레코드를 FCM으로 배치 발송합니다.

## 아키텍처 흐름

```
사용자 A가 B의 게시글에 좋아요
     ↓
likes 테이블 INSERT
     ↓ (트리거)
notify_on_like() 함수 실행
     ↓
notifications 테이블 INSERT (is_sent=false)
     ↓ (Cron 30초마다)
send-push-notification 함수 실행
     ↓
user_devices의 fcm_token으로 FCM 발송
     ↓
notifications.is_sent=true 업데이트
     ↓
B의 기기에 푸시 알림 도착
```

## 배포 절차

### 1. Supabase CLI 로그인 (최초 1회)
```bash
supabase login
supabase link --project-ref juukbctqzlrxfnivhgqe
```

### 2. FCM Server Key 설정
Firebase Console → 프로젝트 설정 → 클라우드 메시징 → **서버 키** 복사.

```bash
supabase secrets set FCM_SERVER_KEY=<복사한_키>
```

### 3. Edge Function 배포
```bash
supabase functions deploy send-push-notification
```

### 4. 마이그레이션 적용
```bash
# 20260423_001_notifications_extend.sql 적용
# 20260423_002_notification_triggers.sql 적용
# Dashboard → Database → SQL Editor → 파일 내용 실행
```

### 5. Cron Job 설정

Supabase Dashboard → Database → Extensions → `pg_cron` 활성화:

```sql
-- pg_cron 확장 활성화 (한 번만)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 30초마다 Edge Function 호출
SELECT cron.schedule(
  'send-push-notifications',
  '*/30 * * * * *',  -- 30초마다 (pg_cron v1.5+ 필요)
  $$
  SELECT net.http_post(
    url := 'https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    )
  );
  $$
);
```

> **참고:** pg_cron 1.5+ 이전 버전에서는 초 단위 스케줄 불가. 대신 1분 간격 사용:
> `'*/1 * * * *'` (매분)

### 6. 테스트

**방법 A: 수동 호출**
```bash
curl -X POST \
  https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

응답 예시:
```json
{ "processed": 3, "sent": 3, "skipped": 0 }
```

**방법 B: 실제 시나리오**
1. 두 계정(A, B) 준비 — 각각 iOS/Android 기기에 로그인
2. A 기기에서 B의 게시글에 좋아요
3. 최대 30초 후 B 기기에 푸시 알림 도착
4. 알림 탭 → 해당 게시글로 이동

## 환경 변수

| 이름 | 설명 | 필수 |
|------|------|------|
| `SUPABASE_URL` | Supabase 프로젝트 URL (자동 설정) | ✅ |
| `SUPABASE_SERVICE_ROLE_KEY` | Service Role Key (자동 설정) | ✅ |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging Server Key | ✅ 수동 설정 |

## 모니터링

### 함수 로그 확인
```bash
supabase functions logs send-push-notification
```

### 미발송 알림 확인 (디버깅)
```sql
SELECT id, user_id, type, title, created_at
FROM notifications
WHERE is_sent = FALSE
ORDER BY created_at ASC
LIMIT 20;
```

### FCM 토큰 등록 확인
```sql
SELECT user_id, platform, created_at
FROM user_devices
ORDER BY created_at DESC
LIMIT 20;
```

## 주요 로직

- **배치 크기**: 50건 (한 번의 호출당)
- **발송 기준**: `is_sent=false` AND `read=false`
- **사용자 설정 확인**: `notification_preferences` 테이블의 `enabled_push` + 타입별 플래그
- **기기 없음**: FCM 토큰이 없는 사용자는 `is_sent=true`로 처리해 재시도 중단
- **발송 실패**: 로그 남기고 해당 알림은 다음 Cron 주기에서 재시도 가능

## 문제 해결

### "FCM_SERVER_KEY not configured" 오류
→ `supabase secrets list`로 확인 후 `supabase secrets set FCM_SERVER_KEY=xxx` 재설정

### 알림이 도착하지 않음
1. `user_devices` 테이블에 토큰이 있는지
2. `notifications` 테이블에 레코드가 생성되는지 (트리거 동작)
3. `is_sent` 플래그가 처리되는지 (Cron 동작)
4. FCM Server Key가 올바른지
5. 기기 알림 권한이 허용되어 있는지

### 중복 알림
→ `notifications` 테이블의 UNIQUE 제약이 필요하면 추가:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_dedupe
ON notifications(user_id, type, post_id, comment_id, sender_id)
WHERE created_at > NOW() - INTERVAL '1 hour';
```
