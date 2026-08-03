# Kakao OIDC 인증 전환 작업지시서

> 상태: 구현 전 운영·계정 이전 결정 대기
> 목적: 클라이언트 파생 비밀번호와 임의 이메일 확인 RPC 제거

## 1. 문제

현재 Kakao SDK 로그인 뒤 `kakao user id + client salt`로 Supabase 비밀번호를 만들고
이메일/비밀번호 계정을 생성한다. 이후 SECURITY DEFINER
`confirm_kakao_user_by_email(text)`가 임의 이메일을 받아 `auth.users.email_confirmed_at`을
갱신한다. 클라이언트 비밀은 비밀로 유지할 수 없고, RPC는 호출자와 대상 이메일 소유권을
결속하지 않으므로 공개 출시 계약으로 사용할 수 없다.

## 2. 목표 계약

- Kakao SDK에서 OIDC ID token을 받고 Supabase
  `signInWithIdToken(provider: OAuthProvider.kakao, idToken: ...)`으로 로그인한다.
- 앱에는 Kakao용 Supabase 비밀번호와 salt가 없다.
- `confirm_kakao_user_by_email`은 앱·정본 SQL·운영 DB에서 제거하고 실행 권한도 회수한다.
- 신규 Kakao 사용자는 Supabase Kakao identity로만 생성한다.
- 기존 사용자의 게시물·반려동물·채팅·AI/건강 기록을 가리키는 `public.users.id`를 보존한다.

## 3. 구현 전 읽기 전용 조사

개인정보 값은 출력하지 않고 다음 숫자만 집계한다.

- `auth.users.raw_app_meta_data.provider/providers`별 사용자 수
- `auth.identities.provider = kakao` 사용자 수
- 기존 `provider = kakao` public profile 수
- pseudo email 패턴 계정 수와 실제 Kakao identity 연결 여부
- 동일 이메일 또는 Kakao subject가 둘 이상의 auth user에 연결될 충돌 수
- 탈퇴 대기/정지/데이터 연결이 있는 기존 Kakao 계정 수

## 4. 사람이 결정할 사항

1. 기존 pseudo-email 사용자를 원래 UUID로 identity link할 수 있는지 검증한다.
2. UUID 보존이 불가능한 충돌 계정의 병합·지원·재로그인 정책을 정한다.
3. Kakao OIDC 동의항목과 Supabase provider secret/redirect 설정을 확인한다.
4. 구버전 앱의 최소 지원 기간과 강제 업데이트 시점을 정한다.

## 5. 순차 구현

### KAO-0 콘솔·staging 계약

- Kakao Login에서 OpenID Connect를 활성화한다.
- Android package와 release key hash, iOS bundle/scheme, Supabase Kakao provider와 redirect
  URL을 staging에서 검증한다.
- ID token의 issuer/audience/nonce와 Supabase session 생성을 확인한다.

### KAO-1 앱 이중 경로(제한 기간)

- 신규 로그인은 OIDC만 사용한다.
- 기존 계정 이전이 완료되지 않은 사용자는 일반 회원가입으로 떨어뜨리지 않고 명확한
  지원 경로를 표시한다.
- 파생 비밀번호 생성, legacy password retry, 임의 확인 RPC 호출을 제거한다.
- 오류 원문·토큰·이메일을 release 로그나 사용자 메시지에 노출하지 않는다.

### KAO-2 계정 연결

- 승인된 서버측 migration/관리 도구로만 identity를 연결한다.
- 대상 Kakao subject와 기존 계정 소유권을 서버에서 검증한다.
- UUID/FK 보존, 중복 방지, dry-run, batch 제한, 감사 결과와 rollback mapping을 포함한다.
- 실제 개인정보 목록을 로컬 파일·Git·AI 검토 번들에 넣지 않는다.

### KAO-3 위험 RPC 제거

- 새 migration에서 `REVOKE EXECUTE` 후 `DROP FUNCTION
  confirm_kakao_user_by_email(text)`를 수행한다.
- `supabase/petspace_setup.sql` 정본에서도 제거한다.
- 운영 적용은 OIDC 앱 배포·기존 계정 이전·구버전 차단이 확인된 뒤 사람이 수행한다.

## 6. 테스트

- KakaoTalk 설치/미설치, 계정 로그인, 사용자 취소, 네트워크 실패
- 신규/기존/탈퇴 대기/중복 이메일/연결 충돌
- 앱 재시작과 token refresh, 로그아웃 후 session 제거
- ID token 변조·잘못된 audience·만료 token 거부
- 기존 UUID의 반려동물·게시물·댓글·채팅·분석 기록 보존
- 구버전 앱 차단 또는 지원 문구

## 7. 완료 게이트

- 코드와 canonical SQL에서 `kakaoPasswordSalt`, 파생 비밀번호,
  `confirm_kakao_user_by_email` 참조 0건
- 양쪽 독립 리뷰 blocker/high 0
- staging 실계정 E2E 통과
- 운영 migration과 provider/Edge 변경은 별도 사람 승인
