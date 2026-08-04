# Firebase/FCM 출시 활성화 런북

> 상태: 로컬 준비·교차검토 완료, 운영 활성화 대기
> 원칙: secret 값과 사용자 FCM token을 문서·Git·로그에 남기지 않는다.
> 운영 변경: 각 게이트 검증 후 별도 승인으로만 수행한다.

## 1. 2026-08-04 읽기 전용 기준선

- `user_devices`: 15개, 활성 13개
- `notification_preferences`: 11개
- 미발송 `notifications`: 16개
- `create_notification`, `notification_delivery_allowed`, `trg_push_on_notification`: 존재
- DB `app.settings.supabase_url`, `app.settings.service_role_key`: 미설정
- `send-notification`, `send-push-notification`, `notify-admin-new-post`: 미배포
- Edge `FIREBASE_SERVICE_ACCOUNT_KEY`, `FIREBASE_PROJECT_ID`: 미설정
- 앱의 Android Firebase package와 `com.jena.petspace`: 일치
- Android/iOS Firebase project: 일치

현재는 DB 트리거가 설정 부재를 경고 후 건너뛰고 Edge 함수도 없어 기기 푸시가 전달되지 않는다.

## 2. 운영 적용 전 로컬 게이트

1. 원격·포그라운드 로컬 알림이 공용 타입→라우트 매핑을 사용하는지 확인
2. `LocalNotificationService`와 `FCMService`가 동일 navigator key를 받는지 확인
3. Android `social`, `health`, `chat`, `system` 채널과 Edge `channel_id` 매핑 확인
4. `flutter analyze --no-pub`, 관련 계약·서비스 테스트, 전체 테스트 통과
5. 변경 번들의 Codex·Claude blocker/high 0

## 3. 운영 활성화 순서

아래는 한 단계씩 적용하고 값이 아닌 존재·성공 여부만 확인한다. 검증 실패 시 다음 단계로 가지 않는다.

1. `pg_net` 사용 가능 여부 확인
2. Edge secret `FIREBASE_SERVICE_ACCOUNT_KEY`, `FIREBASE_PROJECT_ID` 등록
3. `send-push-notification`을 `--no-verify-jwt` 없이 배포한 뒤 다음을 확인
   - 토큰 없는 요청: Gateway `401`
   - 유효하지만 service role이 아닌 JWT 요청: 함수 `403`
4. 마지막 활성화 단계로 Supabase Dashboard SQL Editor에서 DB
   `app.settings.supabase_url`과 `app.settings.service_role_key` 설정
5. 새 DB 세션에서 두 설정의 **존재 여부만** 확인
6. 테스트 계정·테스트 기기 한 대로 단일 알림 생성
7. `notifications.is_sent=true`, `sent_at` 기록과 기기 수신을 함께 확인
8. `send-notification`, `notify-admin-new-post`는 실제 producer가 필요하다고
   확인된 경우에만 별도 배포

4번은 DB 트리거를 실제 Edge 호출에 연결하는 **최종 활성화 단계**다. 2~3번이 검증되기
전에 실행하지 않는다. `ALTER DATABASE ... SET`은 이미 열려 있는 연결에는 즉시 반영되지
않으므로 5번 검증은 반드시 새 SQL Editor 세션에서 수행한다.

실제 service role key를 `supabase/petspace_setup.sql`이나 실행 로그에 기록하지 않는다.

## 4. 기존 미발송 16건

기본안은 **일괄 재발송하지 않음**이다. 오래된 좋아요·댓글·시스템 알림이 한꺼번에 도착하면
사용자 혼란이 크다. 운영 활성화 전에 사람 승인으로 다음 중 하나를 선택한다.

- 권고: 기존 16건은 인앱 기록으로만 보존하고 푸시 재발송 대상에서 제외
- 예외: 운영상 반드시 필요한 system/health 유형만 건별 검토 후 재발송

어느 경우에도 사용자 payload나 token을 리뷰 문서로 추출하지 않는다.

운영 활성화 후 새로 발생하는 `is_sent=false` 행은 집계만 모니터링한다. 일시적 장애로
전 기기 발송이 실패한 건은 원인을 해소한 뒤 해당 `notification_id`만 권한 있는 운영자가
`send-push-notification`에 수동 재요청하며, 자동 일괄 재발송은 하지 않는다.

## 5. 실기기 E2E

- 앱 상태: 포그라운드 / 백그라운드 / 완전 종료
- 유형: 좋아요, 댓글, 팔로우, 감정 분석, 건강 알림, 시스템 알림
- 확인: 알림 표시, 채널 이름·사운드, 탭 후 목적 화면, 뱃지·인앱 읽음 상태
- 설정: 전체 푸시 OFF, 유형별 OFF, 권한 거부→재허용
- 토큰: 로그아웃 비활성화, 재로그인 활성화, token refresh, 만료 token 비활성화

## 6. 롤백

- Edge 장애 시 새 SQL Editor 세션에서 다음 중 하나로 호출을 중단하고 인앱 알림 행 생성은 유지한다.
  - `ALTER DATABASE postgres RESET "app.settings.service_role_key";`
  - 긴급 차단이 필요하면 `ALTER TABLE public.notifications DISABLE TRIGGER trg_push_on_notification;`
- `ALTER DATABASE ... RESET`도 기존 연결에는 즉시 반영되지 않으므로 새 세션에서 비활성화 여부를 확인한다.
- 잘못된 service account는 Edge secret에서 교체하고 저장소에 넣지 않는다.
- 채널/라우팅 회귀 시 앱 피처를 되돌리되 DB 알림 원본과 사용자 설정은 보존한다.
