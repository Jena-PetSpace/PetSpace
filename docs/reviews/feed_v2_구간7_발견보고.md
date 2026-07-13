# 구간 7 (새 글 이웃집 알림) — 착수 전 미니 발견보고

- 작성일: 2026-07-09
- 조건: 작업지시서 v1 구간 7 — "send-notification 시그니처 적합성 확인 후 웹 승인 받고 진행"
- 상태: **구현 미착수.** 아래 확인 결과와 결정 요청 3건.

## 1. send-notification 시그니처 실측

[send-notification/index.ts:15-24](supabase/functions/send-notification/index.ts#L15-L24):

```ts
interface NotificationRequest {
  userId: string;      // 수신자 user_id (단일)
  senderId?: string; senderName?: string;
  type: string;        // like | comment | follow | mention | emotionAnalysis | postShare
  title: string; body: string;
  postId?: string; data?: Record<string, string>;
}
```

동작: notifications 테이블 저장([:55-71](supabase/functions/send-notification/index.ts#L55-L71)) → 수신자 user_devices의 FCM 토큰 전체에 v1 API 전송([:78-147](supabase/functions/send-notification/index.ts#L78-L147)) → 만료 토큰 정리. **수신자 1명 기준의 범용 함수로, 재사용 적합.**

## 2. 확정 스펙과의 갭 (변환 계층 필수)

| # | 갭 | 실측 근거 | 판정 |
|---|---|---|---|
| G1 | **Webhook payload ≠ 함수 계약.** Supabase Database Webhook은 `{type:"INSERT", table, record, old_record, schema}`를 보낸다. send-notification은 `{userId, type, title, body}`를 기대 → **직접 연결 불가** | index.ts:44-52 (400 반환) | 변환 계층 1개 필요 |
| G2 | **운영자 식별자 부재.** users 테이블에 admin 플래그·role 컬럼 없음 (petspace_setup.sql의 role은 chat_participants 전용 — [:267](supabase/petspace_setup.sql#L267)). 운영자는 seed에서 display_name='관리자'로만 식별([:2878-2880](supabase/petspace_setup.sql#L2878-L2880)) — 앱의 isAdmin도 authorName=='관리자' 문자열 비교([community_post.dart](pjh/lib/features/feed_hub/domain/entities/community_post.dart) isAdmin) | display_name 변경 시 파손 | 결정 필요 (아래 D1) |
| G3 | **자기 글 알림 루프.** 운영자 본인이 글을 쓰면 운영자에게 알림이 간다 → webhook/변환 계층에서 `record.author_id == 운영자` skip 조건 필요. 또한 post_type 필터(emotion 분석 자동 글 제외 여부) 결정 필요 | posts.post_type = photo/community/emotion | 결정 필요 (아래 D2) |
| G4 | **JWT.** send-notification은 verify_jwt 기본 배포 → Webhook 호출 시 Authorization 헤더(service_role) 첨부 필요. Dashboard Webhook 설정의 HTTP Headers로 가능 | gemini-proxy 선례: --no-verify-jwt 금지 원칙 | 절차 항목 |

## 3. 구현 옵션 (웹 결정 요청)

- **D1. 운영자 식별**: ① Edge Function 시크릿에 운영자 UUID 고정(`ADMIN_USER_IDS`) — 단순·안전, 운영 계정 추가 시 시크릿 갱신 (권장) / ② `users.is_admin BOOLEAN` 컬럼 신설 + display_name 관례 폐기 — 깔끔하나 마이그레이션·RLS 검토 추가
- **D2. 알림 대상 글**: post_type IN ('photo','community')만, author_id ∉ 운영자 (권장) / emotion 자동 생성 글 포함 여부
- **D3. 변환 계층 형태**: ① 신규 경량 Edge Function `notify-admin-new-post` (webhook 수신 → 필터 → 운영자별 send-notification 호출 or 로직 인라인) — 로그·수정 용이 (권장) / ② pg_net 트리거로 DB에서 직접 POST — 함수 하나 덜 쓰나 디버깅 어려움

## 4. 승인 시 예상 작업 (참고, 미착수)

1. `supabase/functions/notify-admin-new-post/index.ts` 신규 (~80줄, send-notification 계약으로 변환)
2. 대시보드: posts INSERT Webhook 등록(HTTP Headers에 service_role) + `ADMIN_USER_IDS` 시크릿
3. 검증: 테스트 계정 글 작성 → 운영자 기기 푸시 + notifications 행 확인 / 운영자 글 작성 → 미발송 확인
