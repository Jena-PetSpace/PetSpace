# Kakao OIDC 운영 집계 독립 리뷰 요청

> 목적: Google Play 출시 전 Kakao 인증 전환의 계정 보존·권한 안전성을 검토한다.
> 범위: 읽기 전용 집계 결과와 로컬 정본 문서·코드 검토만 허용한다.
> 제외: 운영 DB 변경, Edge 배포, Supabase/Kakao 콘솔 변경, 앱 구현·배포.

## 검토 대상

- `docs/work-orders/2026-08-03-kakao-oidc-auth-migration.md`
- `docs/qa/2026-08-04-kakao-oidc-preflight-inventory.sql`
- `pjh/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `supabase/petspace_setup.sql`

## 2026-08-04 운영 집계 결과

아래 값은 식별자·이메일·Kakao subject를 포함하지 않는 숫자·불리언 집계다.

| 항목 | 값 |
|---|---:|
| Kakao 후보 계정 / `public.users.provider = kakao` | 2 / 2 |
| 실제 이메일 / 확인 완료 | 2 / 2 |
| pseudo email / NULL auth email | 0 / 0 |
| email identity / encrypted password 보유 | 2 / 2 |
| Kakao identity 보유 / 미보유 | 0 / 2 |
| 검증된 Kakao subject 미보유 | 2 |
| 비검증 metadata `kakao_id` 힌트 보유 | 2 |
| metadata와 검증 subject 모두 없는 계정 | 0 |
| 같은 UUID의 auth/profile 이메일 불일치 | 0 |
| 다른 UUID와 이메일 충돌 | 0 |
| public profile 누락 / auth user 누락 | 0 / 0 |
| 검증 subject 중복 그룹 / metadata 힌트 중복 그룹 | 0 / 0 |
| 삭제 예정 / 복수 검증 subject 계정 | 0 / 0 |
| `public.users.email` NOT NULL | true |
| `confirm_kakao_user_by_email(text)` 존재 | true |
| 위 함수 PUBLIC / anon / authenticated 실행 가능 | true / true / true |
| `confirm_my_email()` 존재 | true |
| 위 함수 PUBLIC / anon / authenticated 실행 가능 | true / true / true |

## 목표 계약

- 기존 2개 계정의 `auth.users.id`와 모든 FK를 보존한다.
- Native Kakao ID token과 Supabase OIDC를 사용한다.
- 신규 Kakao 가입은 이메일 수집·저장에 의존하지 않는다.
- `raw_user_meta_data.kakao_id`는 소유권 증거로 신뢰하지 않는다.
- 기존 사용자의 활성 세션과 서버가 검증한 Kakao token을 함께 사용해 계정을 연결한다.
- 계정 연결 성공과 복구 가능성을 확인하기 전 기존 email/password 인증수단을 무효화하지 않는다.
- 미연결 Kakao subject가 새 UUID로 가입되는 경로를 서버에서 차단한다.
- 운영 migration, Edge 배포, provider 활성화, 앱 배포는 별도 승인 전 금지한다.

## 요청 판정

다음 JSON 객체 하나로 응답한다.

```json
{
  "decision": "accept|changes_required",
  "blocker_high": [
    {
      "severity": "blocker|high",
      "finding": "실제 위험",
      "required_change": "필수 변경"
    }
  ],
  "agreed_next_sequence": ["다음 단계"],
  "implementation_scope_now": ["현재 안전하게 가능한 범위"],
  "production_changes_still_gated": ["별도 승인이 필요한 운영 변경"],
  "reason": "판정 근거"
}
```

표현 선호나 중복 문서화만으로 `changes_required`를 내리지 않는다. 계정 손실·탈취, UUID 분기, 로그인 중단, 과도한 함수 권한을 blocker/high 기준으로 사용한다.
