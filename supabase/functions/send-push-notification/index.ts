// supabase/functions/send-push-notification/index.ts
// Cron이 주기적으로 호출 — notifications 테이블의 미발송 레코드를 FCM으로 배치 발송.
//
// 호출 방식: POST /functions/v1/send-push-notification
//   - Supabase Dashboard > Database > Cron Jobs 에서 30초마다 호출 설정
//   - 또는 수동 트리거: supabase functions invoke send-push-notification
//
// 배치 크기: 50건
// 미발송 기준: is_sent = false AND read = false

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const BATCH_SIZE = 50;

interface Notification {
  id: string;
  user_id: string;
  sender_id: string | null;
  type: string;
  title: string;
  body: string;
  post_id: string | null;
  comment_id: string | null;
  data: Record<string, unknown> | null;
}

interface UserDevice {
  user_id: string;
  fcm_token: string;
  platform: string;
}

interface NotificationPreferences {
  user_id: string;
  enabled_push: boolean;
  enabled_like: boolean;
  enabled_comment: boolean;
  enabled_follow: boolean;
  enabled_mention: boolean;
  enabled_system: boolean;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // 1. 미발송 알림 batch 조회 (오래된 순)
    const { data: notifications, error: fetchError } = await supabase
      .from("notifications")
      .select("id, user_id, sender_id, type, title, body, post_id, comment_id, data")
      .eq("is_sent", false)
      .order("created_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (fetchError) {
      console.error("notifications fetch error:", fetchError);
      return json({ error: fetchError.message }, 500);
    }

    const list = (notifications ?? []) as Notification[];
    if (list.length === 0) {
      return json({ sent: 0, message: "no pending notifications" });
    }

    // 2. 수신자별 FCM 토큰 일괄 조회
    const userIds = [...new Set(list.map((n) => n.user_id))];
    const { data: devices } = await supabase
      .from("user_devices")
      .select("user_id, fcm_token, platform")
      .in("user_id", userIds);

    const tokensByUser: Record<string, UserDevice[]> = {};
    for (const d of (devices ?? []) as UserDevice[]) {
      if (!tokensByUser[d.user_id]) tokensByUser[d.user_id] = [];
      tokensByUser[d.user_id].push(d);
    }

    // 3. 수신자별 알림 설정 조회
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .in("user_id", userIds);

    const prefsByUser: Record<string, NotificationPreferences> = {};
    for (const p of (prefs ?? []) as NotificationPreferences[]) {
      prefsByUser[p.user_id] = p;
    }

    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
    if (!fcmServerKey) {
      return json({ error: "FCM_SERVER_KEY not configured" }, 500);
    }

    let sentCount = 0;
    let skippedCount = 0;
    const sentIds: string[] = [];

    for (const n of list) {
      // 설정 확인 (없으면 기본값 true로 간주)
      const pref = prefsByUser[n.user_id];
      if (pref && !pref.enabled_push) {
        skippedCount++;
        sentIds.push(n.id); // is_sent=true로 처리해 재시도 방지
        continue;
      }
      if (pref && !isTypeEnabled(n.type, pref)) {
        skippedCount++;
        sentIds.push(n.id);
        continue;
      }

      const userTokens = tokensByUser[n.user_id] ?? [];
      if (userTokens.length === 0) {
        // 기기 없음 — is_sent 처리해서 재시도 중단
        sentIds.push(n.id);
        continue;
      }

      // FCM 발송 (복수 기기 지원)
      for (const device of userTokens) {
        try {
          const ok = await sendFcm(device.fcm_token, n, fcmServerKey);
          if (ok) sentCount++;
        } catch (e) {
          console.error(`FCM send fail user=${n.user_id} token=${device.fcm_token.slice(0, 8)}...`, e);
        }
      }
      sentIds.push(n.id);
    }

    // 4. 처리된 알림 is_sent 일괄 업데이트
    if (sentIds.length > 0) {
      await supabase
        .from("notifications")
        .update({ is_sent: true, sent_at: new Date().toISOString() })
        .in("id", sentIds);
    }

    return json({
      processed: list.length,
      sent: sentCount,
      skipped: skippedCount,
    });
  } catch (e) {
    console.error("handler exception:", e);
    return json({ error: String(e) }, 500);
  }
});

function isTypeEnabled(type: string, pref: NotificationPreferences): boolean {
  switch (type) {
    case "like":
      return pref.enabled_like;
    case "comment":
      return pref.enabled_comment;
    case "follow":
      return pref.enabled_follow;
    case "mention":
      return pref.enabled_mention;
    case "system":
      return pref.enabled_system;
    default:
      return true; // 알 수 없는 타입은 기본 허용
  }
}

async function sendFcm(
  token: string,
  notification: Notification,
  serverKey: string,
): Promise<boolean> {
  const payload = {
    to: token,
    notification: {
      title: notification.title,
      body: notification.body,
      sound: "default",
    },
    data: {
      type: notification.type,
      ...(notification.post_id ? { post_id: notification.post_id } : {}),
      ...(notification.comment_id ? { comment_id: notification.comment_id } : {}),
      ...(notification.sender_id ? { sender_id: notification.sender_id } : {}),
      notification_id: notification.id,
    },
    android: { priority: "high" },
  };

  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    console.error("FCM error:", response.status, text);
    return false;
  }
  return true;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
