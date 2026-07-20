import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PushRequest {
  notification_id: string;
}

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  is_sent: boolean;
}

interface UserDevice {
  fcm_token: string;
  platform: string;
}

interface FcmResult {
  success: boolean;
  invalidToken: boolean;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function stringData(
  notification: NotificationRow,
): Record<string, string> {
  const result: Record<string, string> = {
    notification_id: notification.id,
    type: notification.type,
  };
  for (const [key, value] of Object.entries(notification.data ?? {})) {
    if (value != null) {
      result[key] = typeof value === "string" ? value : JSON.stringify(value);
    }
  }
  return result;
}

async function getAccessToken(serviceAccountKey: string): Promise<string> {
  const serviceAccount = JSON.parse(serviceAccountKey);
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: object) =>
    btoa(JSON.stringify(value))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");
  const signingInput = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${arrayBufferToBase64Url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`OAuth token exchange failed: ${response.status}`);
  }
  const body = await response.json();
  if (typeof body.access_token !== "string") {
    throw new Error("OAuth response did not include an access token");
  }
  return body.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0)).buffer;
}

function arrayBufferToBase64Url(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function isInvalidTokenError(error: unknown): boolean {
  const serialized = JSON.stringify(error);
  return serialized.includes("UNREGISTERED") ||
    serialized.includes("registration-token-not-registered");
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  device: UserDevice,
  notification: NotificationRow,
): Promise<FcmResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.fcm_token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: stringData(notification),
          android: { priority: "HIGH" },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    },
  );

  if (response.ok) {
    return { success: true, invalidToken: false };
  }
  const error = await response.json().catch(() => ({
    status: response.status,
  }));
  console.error("FCM delivery failed", { status: response.status });
  return {
    success: false,
    invalidToken: isInvalidTokenError(error),
  };
}

serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method Not Allowed" }, 405);
  }

  try {
    const payload: PushRequest = await req.json();
    if (!payload.notification_id) {
      return json({ error: "notification_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const serviceAccountKey =
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY") ?? "";
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
    if (
      !supabaseUrl ||
      !serviceRoleKey ||
      !serviceAccountKey ||
      !projectId
    ) {
      return json({ error: "Push service is not configured" }, 500);
    }
    if (
      req.headers.get("authorization") !== `Bearer ${serviceRoleKey}`
    ) {
      return json({ error: "Forbidden" }, 403);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data, error: notificationError } = await supabase
      .from("notifications")
      .select("id, user_id, type, title, body, data, is_sent")
      .eq("id", payload.notification_id)
      .maybeSingle();
    if (notificationError) {
      console.error("Notification lookup failed", {
        code: notificationError.code,
      });
      return json({ error: "Notification lookup failed" }, 500);
    }
    if (!data) {
      return json({ error: "Notification not found" }, 404);
    }

    const notification = data as NotificationRow;
    if (notification.is_sent) {
      return json({ success: true, skipped: "already_sent" });
    }

    const { data: preferences, error: preferenceError } = await supabase
      .from("notification_preferences")
      .select("enabled_push")
      .eq("user_id", notification.user_id)
      .maybeSingle();
    if (preferenceError) {
      console.error("Push preference lookup failed", {
        code: preferenceError.code,
      });
      return json({ error: "Push preference unavailable" }, 503);
    }
    if (preferences?.enabled_push !== true) {
      return json({ success: true, skipped: "push_disabled" });
    }

    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("fcm_token, platform")
      .eq("user_id", notification.user_id)
      .eq("is_active", true);
    if (deviceError) {
      console.error("Active device lookup failed", {
        code: deviceError.code,
      });
      return json({ error: "Active device lookup failed" }, 500);
    }
    if (!devices || devices.length === 0) {
      return json({ success: true, sent: 0, skipped: "no_active_device" });
    }

    const accessToken = await getAccessToken(serviceAccountKey);
    const results = await Promise.all(
      (devices as UserDevice[]).map(async (device) => ({
        device,
        result: await sendFcmMessage(
          projectId,
          accessToken,
          device,
          notification,
        ),
      })),
    );

    const invalidTokens = results
      .filter(({ result }) => result.invalidToken)
      .map(({ device }) => device.fcm_token);
    if (invalidTokens.length > 0) {
      const { error: deactivateError } = await supabase
        .from("user_devices")
        .update({ is_active: false })
        .in("fcm_token", invalidTokens);
      if (deactivateError) {
        console.error("Invalid device deactivation failed", {
          code: deactivateError.code,
        });
      }
    }

    const sent = results.filter(({ result }) => result.success).length;
    const failed = results.length - sent;
    if (sent > 0) {
      const { error: updateError } = await supabase
        .from("notifications")
        .update({
          is_sent: true,
          sent_at: new Date().toISOString(),
        })
        .eq("id", notification.id)
        .eq("is_sent", false);
      if (updateError) {
        console.error("Notification delivery state update failed", {
          code: updateError.code,
        });
        return json({ error: "Delivery state update failed" }, 500);
      }
    }

    return json({ success: true, sent, failed });
  } catch (error) {
    console.error("send-push-notification failed", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return json({ error: "Push request failed" }, 500);
  }
});
