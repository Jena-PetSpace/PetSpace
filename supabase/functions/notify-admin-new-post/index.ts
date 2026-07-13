// supabase/functions/notify-admin-new-post/index.ts
// posts INSERT Database Webhook → 운영자 계정에 "새 글" 푸시 (첫 반응 SOP 지원)
//
// 승인 근거: 피드P0 구간7 승인지시서 (2026-07-09)
//   D1: 운영자 식별 = ADMIN_USER_IDS 시크릿 (콤마 구분 UUID 목록)
//   D2: 대상 = post_type IN ('photo','community') AND author_id ∉ ADMIN_USER_IDS
//       (emotion 자동 생성 글 제외)
//   D3: 변환 계층 = 본 함수. webhook payload를 send-notification 계약으로
//       변환해 운영자별 호출(로직 재사용 — 양쪽 함수 로그로 추적 용이)
//   G4: verify_jwt 유지 배포. Webhook 등록 시 HTTP Headers에
//       Authorization: Bearer <service_role> 첨부 필수.
//
// 배포 타이밍: 함수 배포는 지금, Webhook 등록·E2E 검증은 pg_net 활성화
// 이후(배포 직전 체크리스트와 동일 타이밍). docs/qa/feed_v2_verification.md §7.
//
// 운영 절차: '펫페이스 지기' 등 운영 계정 신규 생성 시 해당 UUID를
// ADMIN_USER_IDS 시크릿에 추가할 것 (SOP 계정 생성 절차에 명기).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: string; // INSERT | UPDATE | DELETE
  table: string;
  schema: string;
  record: Record<string, unknown> | null;
  old_record: Record<string, unknown> | null;
}

const NOTIFIABLE_POST_TYPES = ["photo", "community"];

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const adminIds = (Deno.env.get("ADMIN_USER_IDS") ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    if (adminIds.length === 0) {
      console.warn("ADMIN_USER_IDS 시크릿이 비어 있어 알림을 건너뜁니다.");
      return json({ success: true, skipped: "ADMIN_USER_IDS 미설정" });
    }

    const payload: WebhookPayload = await req.json();
    if (payload.type !== "INSERT" || payload.table !== "posts" || !payload.record) {
      return json({ success: true, skipped: "posts INSERT 아님" });
    }

    const record = payload.record;
    const postId = record.id as string | undefined;
    const authorId = record.author_id as string | undefined;
    const postType = (record.post_type as string | undefined) ?? "";
    if (!postId || !authorId) {
      return json({ success: true, skipped: "record 필수 필드 누락" });
    }

    // D2 필터
    if (!NOTIFIABLE_POST_TYPES.includes(postType)) {
      return json({ success: true, skipped: `post_type=${postType} 제외` });
    }
    if (adminIds.includes(authorId)) {
      return json({ success: true, skipped: "운영자 본인 글" });
    }
    // 지시서 필터 외 안전장치: 비공개 글은 타인 노출 대상이 아니므로 제외.
    if (record.is_private === true) {
      return json({ success: true, skipped: "비공개 글" });
    }

    // 작성자명 조회 (알림 문구용)
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: author } = await supabase
      .from("users")
      .select("display_name")
      .eq("id", authorId)
      .maybeSingle();
    const authorName =
      (author?.display_name as string | undefined)?.trim() || "이웃 집사";
    const typeLabel = postType === "photo" ? "사진" : "커뮤니티";

    // 운영자별 send-notification 호출 (notifications 저장 + FCM + 토큰 정리 재사용)
    let notified = 0;
    const failures: string[] = [];
    await Promise.all(
      adminIds.map(async (adminId) => {
        try {
          const res = await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              userId: adminId,
              senderId: authorId,
              senderName: authorName,
              type: "adminNewPost", // 기존 6종과 구분되는 전용 값
              title: "새 글이 올라왔어요",
              body: `${authorName}님의 ${typeLabel} 글 — 첫 반응을 부탁해요`,
              postId,
            }),
          });
          if (res.ok) {
            notified++;
          } else {
            failures.push(`${adminId}: HTTP ${res.status}`);
            console.error("send-notification 실패:", adminId, await res.text());
          }
        } catch (e) {
          failures.push(`${adminId}: ${e instanceof Error ? e.message : String(e)}`);
          console.error("send-notification 호출 오류:", adminId, e);
        }
      })
    );

    console.log(
      `새 글 알림: post=${postId} type=${postType} → 운영자 ${notified}/${adminIds.length}명 발송`
    );
    return json({
      success: true,
      notified,
      total: adminIds.length,
      ...(failures.length > 0 ? { failures } : {}),
    });
  } catch (e) {
    console.error("notify-admin-new-post 오류:", e);
    return json(
      { error: e instanceof Error ? e.message : String(e) },
      500
    );
  }
});
