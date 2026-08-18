# Kakao OIDC 인증 전환 작업지시서

> 상태: KAO-0 완료 — blocker/high 6건 반영 후 staging 구현 범위 확정 필요
> 목적: 기존 사용자 UUID와 모든 FK를 보존하면서 클라이언트 파생 비밀번호와 임의 이메일 확인 RPC를 제거한다.
> 독립 검토: 2026-08-04 Codex·Claude Opus 5 교차검토 결과 반영

## 1. 문제

현재 Kakao SDK 로그인 뒤 `kakao user id + client salt`로 Supabase 비밀번호를 만들고
이메일/비밀번호 계정을 생성한다. 이후 SECURITY DEFINER
`confirm_kakao_user_by_email(text)`가 호출자가 전달한 이메일을 기준으로
`auth.users.email_confirmed_at`을 갱신한다.

이 구조에는 다음 출시 차단 위험이 있다.

- 클라이언트에 포함된 salt는 비밀이 아니며, 코드를 삭제해도 이미 생성된 파생 비밀번호는
  인증수단으로 계속 남는다.
- `confirm_kakao_user_by_email(text)`에는 정본 SQL 기준 `PUBLIC`/`anon` 실행권 회수가 없다.
- 기존 계정은 이메일 또는 pseudo email로 만들어졌지만 OIDC는 Kakao `sub`로 계정을 식별한다.
  사전 연결 없이 OIDC 로그인을 열면 새 `auth.users.id`가 생기거나 이메일 UNIQUE 충돌로
  로그인이 실패할 수 있다.
- Kakao 이메일은 선택 동의 항목이지만 `public.users.email`은 `NOT NULL UNIQUE`이고
  `ensure_my_user_profile`도 이메일이 없으면 실패한다.

## 2. 목표 계약

- Kakao SDK의 `OAuthToken`에서 OIDC ID token을 받고 Supabase
  `signInWithIdToken(provider: OAuthProvider.kakao, idToken: ..., accessToken: ...)`으로 로그인한다.
- Kakao `sub`가 외부 계정의 지속 식별자이며 이메일을 identity key로 사용하지 않는다.
- 앱에는 Kakao용 Supabase 비밀번호와 salt가 없다.
- 기존 파생 비밀번호는 서버에서 무작위 값으로 회전하거나 email/password identity를 제거하여
  실제 인증수단으로도 무효화한다.
- `confirm_kakao_user_by_email`은 앱·정본 SQL·운영 DB에서 제거하고 실행 권한도 회수한다.
- 자기 세션에 귀속된 이메일 확인이 필요할 때만 `confirm_my_email()`을 사용한다.
- 기존 사용자의 `auth.users.id = public.users.id`와 반려동물·게시물·팔로우·채팅·AI/건강
  기록의 모든 FK를 보존한다.
- 운영 DB, Supabase/Kakao 콘솔, Edge, 배포 변경은 각각 별도 사람 승인을 받는다.

## 3. 구현 전 읽기 전용 조사

사람이 Supabase SQL Editor에서
`docs/qa/2026-08-04-kakao-oidc-preflight-inventory.sql`을 실행한다.

- 쿼리는 DML/DDL/RPC 호출이 없는 SELECT 전용 단일 문이며 한 행의 숫자·불리언만 반환한다.
- 이메일, Kakao ID/subject, UUID, 사용자 행은 출력하거나 로컬·Git·AI 검토로 전달하지 않는다.
- 결과 숫자만 작업지시서의 의사결정 입력으로 사용한다.
- 운영 스키마가 쿼리 전제와 다르거나 실행 오류가 나면 임의 수정하지 않고 중단한다.

필수 확인 범위:

- Kakao 후보 계정 수와 pseudo email/실제 email/NULL email 분포
- `auth.identities.provider = 'kakao'` 연결 수
- identity `sub` 또는 기존 `raw_user_meta_data.kakao_id`가 없는 계정 수
- 동일 Kakao subject가 둘 이상의 UUID 후보에 대응하는 충돌 그룹 수
- `auth.users`/`public.users` 고아 프로필과 교차 소유 이메일 충돌 수
- 이메일 확인 완료, email identity, 기존 encrypted password, 탈퇴 유예 계정 수
- 위험 RPC의 `PUBLIC`/`anon`/`authenticated` 실행 가능 여부

현재 후보 탐지는 public provider, pseudo email, app/user metadata, Kakao identity 중 하나가 있는
계정을 대상으로 한다. 과거 admin/email 경로로 생성되었으나 Kakao 표식이 전혀 남지 않은
실제 이메일 계정은 집계에서 빠질 수 있으므로 `kakao_candidate_total`을 전체 이전 대상이라고
단정하지 않는다.

## 4. 사람 결정과 권고 기본안

1. **이메일 미제공:** 첫 공개 전환은 Kakao `account_email` 동의를 요구하고, 이메일을 제공할 수
   없으면 새 계정을 만들지 않고 설명·지원 경로를 제공한다. 이메일 없는 가입을 지원하려면
   `public.users.email` nullable 전환과 별도 identity 모델을 독립 migration으로 승인한다.
2. **자동 이메일 연결:** 과거 `confirm_kakao_user_by_email`로 확인된 이메일은 소유권 증거로
   신뢰하지 않는다. GoTrue의 동일 이메일 자동 identity linking이 실제로 켜져 있는지 staging에서
   확인하고, 안전한 서버측 차단이 없으면 production Kakao provider를 활성화하지 않는다.
3. **기존 계정 충돌:** 이메일 기준 자동 병합을 전제로 하지 않는다. 기존 UUID 보존이 검증되지
   않은 계정은 로그인을 중단하고 수동 지원 대상으로 분리한다.
4. **기존 계정 연결:** `raw_user_meta_data.kakao_id`는 클라이언트가 수정할 수 있어 단독 증거로
   사용하지 않는다. 기존 로그인 세션의 `auth.uid()`와 그 자리에서 받은 실제 Kakao OIDC token을
   서버가 함께 검증하는 계정별 전환을 기본안으로 한다. pseudo email·metadata 값은 충돌 탐지
   힌트로만 사용한다.
5. **기존 인증수단과 복구:** 계정별 identity 연결과 UUID/FK 확인이 끝난 뒤에만 해당 계정의
   파생 비밀번호를 무효화한다. 연결 실패 계정은 잠그지 않고 현재
   `AppConfig.supportEmail` 정본 값인 `jera.00003@gmail.com`을 표시하여 수동 복구로 보낸다.
6. **콘솔 계약:** Kakao OIDC·동의항목, Android release key hash, iOS bundle/scheme,
   Supabase provider secret/redirect를 staging에서 먼저 확인한다.
7. **구버전:** 최소 지원 버전과 강제 업데이트 시점을 정하고, 구버전 차단 전에는 위험 RPC를
   운영에서 DROP하지 않는다.
8. 위 기본안 변경, 운영 계정 연결 실행, migration 적용, 콘솔 변경은 사람 승인 사항이다.

## 5. 순차 실행

### KAO-0 읽기 전용 사실 확정

- **2026-08-04 완료.** `docs/qa/2026-08-04-kakao-oidc-preflight-inventory.sql`을 운영
  프로젝트에 SELECT-only로 실행했다.
- 기존 Kakao 후보는 2계정이고 UUID/profile 불일치, 교차 소유 이메일 충돌, 고아, 중복,
  삭제 예정 계정은 모두 0이다.
- 두 계정 모두 email identity와 encrypted password가 있지만 Kakao identity와 검증된
  Kakao subject는 0이다. raw metadata의 `kakao_id` 힌트만 있으므로 자동 백필 근거로
  사용할 수 없다.
- `confirm_kakao_user_by_email(text)`와 `confirm_my_email()`의 `PUBLIC`/`anon`/
  `authenticated` 실행권이 모두 열려 있음을 확인했다.
- 상세 교차검토 결과는
  `docs/reviews/2026-08-04-kakao-oidc-inventory-review-result.md`를 정본으로 한다.

### KAO-0.5 staging 콘솔·권한 계약

- Kakao Login에서 OpenID Connect와 승인된 동의항목을 활성화한다.
- Android package/release key hash, iOS bundle/scheme, Supabase Kakao provider와 redirect URL을
  staging에서 검증한다.
- `OAuthToken.idToken`이 실제로 존재하고 Supabase staging session이 생성되는지 확인한다.
- production Kakao OIDC provider는 KAO-1 계정 연결과 서버측 생성 차단이 검증되기 전까지
  비활성 상태를 유지한다. 앱 화면에서만 미연결 사용자를 막는 것은 승인 게이트가 아니다.
- GoTrue의 동일 이메일 자동 identity linking 동작과 Before-User-Created auth hook 또는 동등한
  서버측 미연결 subject 거부 수단을 staging에서 검증한다.
- `confirm_kakao_user_by_email(text)`의 `PUBLIC`/`anon` 실행권 회수 migration을 작성하되,
  구버전 신규 가입이 깨지는 범위를 staging에서 먼저 측정한다. 운영 적용은 별도 승인이다.

### KAO-1 서버측 계정 연결·인증수단 무효화

- 승인된 서버측 migration/관리 도구로만 identity를 연결한다.
- 기존 로그인 세션의 `auth.uid()`와 같은 흐름에서 받은 실제 Kakao OIDC token을 서버가 검증해
  Kakao subject와 기존 계정 소유권을 결속한다.
- `raw_user_meta_data.kakao_id`, 이메일, pseudo email만으로 identity를 연결하지 않는다.
- UUID/FK 보존, 중복 거부, dry-run, batch 제한, 감사 결과, rollback mapping을 포함한다.
- **각 계정의 연결 성공과 복구 가능성을 확인한 뒤에만** 기존 파생 비밀번호를 회전하거나
  email/password identity를 제거한다. 연결 실패 pseudo-email 계정은 인증수단을 유지하고
  수동 지원 대상으로 분리한다.
- 실제 개인정보 목록을 로컬 파일·Git·AI 검토 번들에 넣지 않는다.

### KAO-2 앱 전환

- KAO-1로 연결이 검증된 계정과 안전한 신규 가입에만 OIDC 경로를 연다.
- 미연결·충돌 계정은 일반 회원가입이나 신규 UUID 생성으로 떨어뜨리지 않고 지원 경로를 표시한다.
- production provider 또는 서버측 auth hook에서 미연결 subject를 먼저 거부한다. 앱의 사전
  분기만으로 새 `auth.users` 생성을 막았다고 간주하지 않는다.
- `OAuthToken`을 보존하고 `signInWithIdToken`에 ID token과 access token을 전달한다.
- 이메일이 있는 자기 세션에 한해 기존 `_confirmEmailOnServerIfNeeded`/
  `confirm_my_email()`을 재사용한다.
- 파생 비밀번호 생성, legacy password retry, 임의 확인 RPC 호출을 제거한다.
- 오류 원문·토큰·이메일을 release 로그나 사용자 메시지에 노출하지 않는다.
- KAO-1보다 KAO-2를 먼저 출시하거나, 미연결 subject에 OIDC 계정 자동 생성을 허용하지 않는다.

### KAO-3 구버전 차단·위험 RPC 제거

- 새 앱 배포와 강제 업데이트, 기존 계정 이전 완료를 확인한다.
- 승인된 migration에서 `REVOKE EXECUTE` 후
  `DROP FUNCTION confirm_kakao_user_by_email(text)`를 수행한다.
- `confirm_my_email()`도 `PUBLIC`/`anon` 권한을 명시적으로 회수하고 authenticated만 허용한다.
- `supabase/petspace_setup.sql` 정본과 설명 문구에서도 위험 RPC를 제거한다.
- 운영 적용은 사람이 수행한다.

## 6. 테스트

- KakaoTalk 설치/미설치, 계정 로그인, 사용자 취소, 네트워크 실패
- 신규/기존/pseudo email/실제 email/이메일 미제공/탈퇴 대기/연결 충돌
- 연결 전 subject가 새 UUID를 만들지 않고 지원 경로로 중단되는지
- 앱 재시작과 token refresh, 로그아웃 후 session 제거
- ID token 누락·변조·잘못된 audience·만료 token 거부
- 기존 UUID의 반려동물·게시물·댓글·팔로우·채팅·분석 기록 보존
- 이전 완료 계정에서 기존 파생 email/password 인증 실패
- 위험 RPC를 `PUBLIC`/`anon`이 호출할 수 없는지
- 구버전 차단 또는 지원 문구

## 7. 완료 게이트

- 읽기 전용 운영 집계와 staging OIDC 계약 확인
- 계정 연결 dry-run에서 UUID/FK 보존, 충돌 거부, rollback 검증
- 코드·템플릿·정본 SQL 전체에서 `kakaoPasswordSalt`, 파생 비밀번호,
  `confirm_kakao_user_by_email` 참조 0건
- 이전된 계정의 기존 파생 인증수단 무효화 검증
- `confirm_my_email()`은 자기 세션에만 작동하고 `PUBLIC`/`anon` 실행권이 없음
- Codex·Claude 독립 리뷰 blocker/high 0
- staging 실계정 E2E 통과
- 운영 migration, provider/콘솔, Edge, 배포는 별도 사람 승인

## 8. 현재 허용 범위

- 허용: 로컬 migration/Edge/앱 코드와 테스트 작성, 피처 플래그 기본값 off, staging 검증안,
  rollback 문서, SELECT-only 재집계 쿼리
- 미허용: 운영 migration, 운영 계정/identity 변경, Edge 배포, production provider 활성화,
  앱 배포, 기존 email/password 인증수단 무효화
- 다음 단계: 위험 RPC 권한 회수·세션 결합형 Kakao subject 연결·미연결 subject 차단의 정확한
  구현 manifest를 확정하고 staging 전용으로 구현·검증한다.
