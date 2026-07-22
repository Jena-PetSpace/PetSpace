import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const allowedTypes = new Set([
  "like",
  "comment",
  "follow",
  "mention",
  "system",
  "admin_new_post",
  "emotion_analysis",
  "health_alert",
]);

interface NotificationRequest {
  userId: string;
  senderId?: string;
  type: string;
  title: string;
  body: string;
  postId?: string;
  commentId?: string;
  data?: Record<string, unknown>;
  eventKey: string;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method Not Allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Notification service is not configured" }, 500);
    }
    if (
      req.headers.get("authorization") !== `Bearer ${serviceRoleKey}`
    ) {
      return json({ error: "Forbidden" }, 403);
    }

    const payload: NotificationRequest = await req.json();
    const type = payload.type?.trim();
    const eventKey = payload.eventKey?.trim();
    if (
      !payload.userId ||
      !type ||
      !allowedTypes.has(type) ||
      !payload.title?.trim() ||
      !payload.body?.trim() ||
      !eventKey
    ) {
      return json({ error: "Invalid notification contract" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: notificationId, error } = await supabase.rpc(
      "create_notification",
      {
        p_user_id: payload.userId,
        p_sender_id: payload.senderId ?? null,
        p_type: type,
        p_title: payload.title.trim(),
        p_body: payload.body.trim(),
        p_post_id: payload.postId ?? null,
        p_comment_id: payload.commentId ?? null,
        p_data: payload.data ?? {},
        p_event_key: eventKey,
      },
    );

    if (error) {
      console.error("create_notification RPC failed", {
        code: error.code,
      });
      return json({ error: "Notification creation failed" }, 500);
    }

    if (notificationId == null) {
      return json({ success: true, skipped: true });
    }

    return json({
      success: true,
      skipped: false,
      notificationId,
    });
  } catch (error) {
    console.error("send-notification failed", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return json({ error: "Notification request failed" }, 500);
  }
});
