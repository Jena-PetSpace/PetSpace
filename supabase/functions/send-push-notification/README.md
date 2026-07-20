# send-push-notification Edge Function

`notifications`의 단일 canonical 행을 ID로 다시 읽고 사용자 설정과 활성
기기를 확인한 뒤 FCM으로 전송하는 함수입니다.

이 문서는 로컬 P2A-1 계약을 설명합니다. Migration 적용과 Edge Function
배포는 별도 운영 승인 전에는 실행하지 않습니다.

## 흐름

```text
도메인 이벤트
  → create_notification()의 유형별 preference gate
  → notifications INSERT (event_key로 멱등)
  → trg_push_on_notification
  → send-push-notification({ notification_id })
  → canonical notification 재조회
  → enabled_push=true 확인
  → user_devices.is_active=true 기기 조회
  → FCM 전송
  → 1대 이상 성공 시 is_sent=true, sent_at 갱신
```

`send-notification`은 `create_notification` RPC만 호출합니다. FCM을 직접
전송하지 않습니다.

## 요청 계약

```json
{
  "notification_id": "notification UUID"
}
```

제목, 본문, 수신자, 유형, data를 요청에서 신뢰하지 않고 DB 행에서 다시
읽습니다. 이미 `is_sent=true`인 행은 멱등하게 건너뜁니다.

## 설정 의미

- 유형별 OFF: `notifications` 행과 기기 push를 모두 생성하지 않습니다.
- `enabled_push=false`: 인앱 알림 행은 보존하고 기기 push만 차단합니다.
- preference 행 부재 또는 조회 실패: fail-closed로 전송하지 않습니다.
- 활성 기기 없음: 전송하지 않으며 `is_sent`를 성공으로 표시하지 않습니다.
- 만료된 FCM token: token 값을 로그에 남기지 않고 해당 기기를
  `is_active=false`로 비활성화합니다.

## 필수 환경 변수

| 이름 | 설명 |
|---|---|
| `SUPABASE_URL` | Supabase 프로젝트 URL |
| `SUPABASE_SERVICE_ROLE_KEY` | server-side DB 접근 키 |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Firebase 서비스 계정 JSON |
| `FIREBASE_PROJECT_ID` | Firebase 프로젝트 ID |

## 운영 적용 전 체크

1. `J1_notification_contract.sql`을 staging에서 검토·적용
2. `app.settings.supabase_url`과 service role key의 안전한 저장 방식 확정
3. 세 Edge Function을 staging에 배포
4. 유형 ON/OFF, 전체 push OFF, 다기기, 만료 token, 재시도 E2E
5. blocker/high 0과 별도 운영 승인 후 production 적용

토큰, service role key, 사용자 payload 전문은 로그에 남기지 않습니다.
