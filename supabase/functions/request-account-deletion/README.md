# request-account-deletion 운영 준비

이 함수는 호출자 JWT의 사용자만 대상으로 한다. Apple identity가 연결된
계정은 iOS 재인증의 일회용 authorization code와 nonce를 검증하고 Apple
refresh token을 revoke한 뒤에만 30일 soft delete를 기록한다.

## 필요한 Edge secret 이름

- `APPLE_TEAM_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`
- `APPLE_CLIENT_ID` — native iOS bundle ID `com.jena.petspace`

값은 소스, 문서, 로그, Git에 기록하지 않는다. `APPLE_PRIVATE_KEY`는 원문
줄바꿈 또는 `\n` 이스케이프 형식을 허용한다.

## 배포 전 확인

1. Apple Developer에서 Sign in with Apple key와 App ID의 연결을 확인한다.
2. 위 네 secret을 Supabase Edge secret으로 등록한다.
3. 운영 배포 전 `index.ts` diff와 secret 이름만 검토한다.
4. Apple 실계정으로 탈퇴를 실행한다.
5. Apple authorization code 재인증 취소 시 계정이 삭제되지 않는지 확인한다.
6. Apple token 교환·ID token 검증·revoke 중 하나라도 실패하면
   `users.deleted_at`이 변경되지 않는지 확인한다.
7. 성공 시 `users.deleted_at`이 전역 sign-out보다 먼저 기록되는지
   확인한다. 전역 sign-out은 best-effort이며, 실패하더라도 L2 restrictive
   RLS가 기존 토큰의 사용자 소유 데이터 접근을 차단해야 한다.
8. 30일 경과 테스트 계정은 `purge-deleted-accounts`가 Storage, 발신
   알림, 채팅 미리보기, `auth.users`, `public.users`를 순서대로 정리하는지
   별도 검증한다.

## 배포 명령 템플릿

아래 명령은 사용자 운영 승인 후에만 실행한다.

```bash
supabase secrets set \
  APPLE_TEAM_ID=... \
  APPLE_KEY_ID=... \
  APPLE_PRIVATE_KEY=... \
  APPLE_CLIENT_ID=com.jena.petspace

supabase functions deploy request-account-deletion
```

명령 기록이나 캡처에 실제 secret 값을 남기지 않는다.
