# Kakao OIDC 운영 집계 교차검토 결과

> 판정일: 2026-08-04
> 검토자: Codex, Claude Opus 5
> 판정: `changes_required`
> 데이터 범위: 식별정보를 제외한 운영 DB 숫자·불리언 집계

## 합의된 사실

- 기존 Kakao 후보는 2계정이며 둘 다 실제 이메일, email identity, encrypted password를 보유한다.
- 두 계정 모두 Kakao identity와 서버 검증된 Kakao subject가 없다.
- UUID/profile 불일치, 교차 이메일 충돌, 고아 계정, subject 중복, 삭제 예정 계정은 없다.
- `public.users.email`은 `NOT NULL`이다.
- `confirm_kakao_user_by_email(text)`와 `confirm_my_email()`은 현재 `PUBLIC`/`anon`/
  `authenticated`에서 모두 실행 가능하다.

## Blocker / High

1. **Blocker — 이메일 인자 기반 계정 연결 RPC 권한 과다**
   - `confirm_kakao_user_by_email(text)`는 비인증 호출 표면이 있고 이메일 문자열을 소유권 근거로
     사용할 수 있어 폐기 대상이다.
   - 운영 적용 전 migration에서 `PUBLIC`, `anon`, `authenticated` 실행권을 회수하고 함수를
     제거한다.
   - 대체 흐름은 이메일 인자를 받지 않고 기존 세션의 `auth.uid()`와 서버가 검증한 Kakao ID
     token subject만 사용한다.
2. **Blocker — 자기 이메일 확인 RPC 권한 과다**
   - `confirm_my_email()`은 `PUBLIC`/`anon` 실행권을 회수하고 `authenticated`만 허용한다.
   - 함수는 `auth.uid() IS NULL`을 거부하고 해당 UUID의 행만 변경해야 한다.
3. **Blocker — OIDC 선활성화 시 신규 UUID 분기**
   - 검증된 Kakao subject가 0개이므로 provider를 먼저 켜면 기존 2계정 모두 새 UUID로 분기할
     위험이 있다.
   - 미연결 subject의 신규 사용자 생성을 서버에서 deny-by-default로 차단하고 staging에서
     신규 UUID 0건을 증명하기 전 production provider를 활성화하지 않는다.
4. **Blocker — metadata 기반 백필 금지**
   - `raw_user_meta_data.kakao_id`는 소유권 증거가 아니다.
   - 기존 활성 세션의 `auth.uid()`와 같은 흐름에서 서버가 서명·issuer·audience·만료·nonce를
     검증한 Kakao ID token만 연결 근거로 사용한다.
5. **High — 이메일 없는 신규 가입과 스키마 충돌**
   - 이메일 비의존 신규 가입을 지원하려면 `public.users.email` nullable 및
     `WHERE email IS NOT NULL` 부분 unique index가 필요하다.
   - 이 스키마 변경은 staging에서 먼저 검증하고 운영 적용은 별도 승인한다.
6. **High — rollback 증적 부재**
   - identity 연결 성공·실패·rollback에서 `auth.users.id`와 모든 FK가 불변임을 staging에서
     증명하기 전 기존 email identity나 encrypted password를 삭제·무효화하지 않는다.

## 합의된 다음 순서

1. staging 복제 환경과 UUID/FK/identity/email 제약 기준선 준비
2. 위험 RPC 권한 회수·폐기 migration 작성 및 staging 검증
3. Kakao ID token 서버 검증 모듈과 세션 결합형 연결 엔드포인트 로컬 구현
4. 미연결 subject 신규 UUID 생성 차단 게이트 로컬 구현
5. 연결 성공·실패·rollback, UUID/FK 불변, 미연결 subject 신규 UUID 0건 staging 검증
6. 이메일 미제공 신규 가입과 nullable email 계약 staging 검증
7. Codex·Claude 2차 독립 리뷰에서 blocker/high 0 확인
8. 이후에만 운영 migration, Edge 배포, provider 활성화, 앱 피처 플래그 활성화를 별도 승인

## 현재 허용·금지 경계

- 현재 허용: 로컬 migration/Edge/앱 코드와 테스트 작성, 피처 플래그 기본값 off, staging 검증안,
  rollback 문서, SELECT-only 재집계 쿼리
- 계속 금지: 운영 DB migration, Edge 배포, production Kakao provider 활성화, 앱 배포,
  기존 email/password 인증수단 무효화
- 영구 금지: metadata 기반 identity 백필
