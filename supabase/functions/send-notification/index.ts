// supabase/functions/send-notification/index.ts
// 알림 이벤트(좋아요/댓글/팔로우 등) 발생 시 FCM으로 푸시 전송
// 호출 방식: POST /functions/v1/send-notification
// Body: { userId, type, title, body, data? }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotificationRequest {
  userId: string;           // 수신자 user_id
  senderId?: string;        // 발신자 user_id
  senderName?: string;      // 발신자 이름
  type: string;             // like | comment | follow | mention | emotionAnalysis | postShare
  title: string;
  body: string;
  postId?: string;
  data?: Record<string, string>;
}

interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data?: Record<string, string>;
  android?: { priority: string };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const payload: NotificationRequest = await req.json();
    const { userId, senderId, senderName, type, title, body, postId, data } = payload;

    if (!userId || !type || !title || !body) {
      return new Response(
        JSON.stringify({ error: "userId, type, title, body는 필수입니다." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. notifications 테이블에 저장
    const { error: notifError } = await supabase
      .from("notifications")
      .insert({
        user_id: userId,
        sender_id: senderId ?? null,
        type,
        title,
        body,
        data: {
          type,
          post_id: postId ?? "",
          sender_id: senderId ?? "",
          sender_name: senderName ?? "",
          ...data,
        },
        read: false,
      });

    if (notifError) {
      console.error("notifications 저장 실패:", notifError);
    }

    // 2. 수신자의 FCM 토큰 조회
    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("fcm_token, platform")
      .eq("user_id", userId);

    if (deviceError || !devices || devices.length === 0) {
      // 디바이스 없어도 알림 저장은 완료됐으므로 성공 반환
      return new Response(
        JSON.stringify({ success: true, pushed: 0, saved: !notifError }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Firebase Admin API로 FCM 전송
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
    if (!fcmServerKey) {
      console.warn("FCM_SERVER_KEY가 설정되지 않았습니다.");
      return new Response(
        JSON.stringify({ success: true, pushed: 0, saved: true, warn: "FCM_SERVER_KEY 미설정" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const notificationData: Record<string, string> = {
      type,
      post_id: postId ?? "",
      sender_id: senderId ?? "",
      sender_name: senderName ?? "",
      ...data,
    };

    let successCount = 0;
    const failedTokens: string[] = [];

    // 토큰별 FCM 전송 (병렬)
    await Promise.all(
      devices.map(async (device: { fcm_token: string; platform: string }) => {
        const message: FcmMessage = {
          token: device.fcm_token,
          notification: { title, body },
          data: notificationData,
          android: { priority: "high" },
        };

        const res = await fetch(
          "https://fcm.googleapis.com/v1/projects/" +
            Deno.env.get("FIREBASE_PROJECT_ID") +
            "/messages:send",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${await getAccessToken(fcmServerKey)}`,
            },
            body: JSON.stringify({ message }),
          }
        );

        if (res.ok) {
          successCount++;
        } else {
          const err = await res.json();
          console.error("FCM 전송 실패:", device.fcm_token, err);
          // 만료된 토큰 수집
          if (err?.error?.status === "NOT_FOUND" || err?.error?.status === "UNREGISTERED") {
            failedTokens.push(device.fcm_token);
          }
        }
      })
    );

    // 4. 만료된 토큰 정리
    if (failedTokens.length > 0) {
      await supabase
        .from("user_devices")
        .delete()
        .in("fcm_token", failedTokens);
      console.log(`만료 토큰 ${failedTokens.length}개 삭제`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        pushed: successCount,
        total: devices.length,
        saved: !notifError,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("send-notification 오류:", e);
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// FCM HTTP v1 API용 Service Account 기반 Access Token 발급
// FCM_SERVER_KEY에는 Service Account JSON 문자열을 저장
async function getAccessToken(serviceAccountJson: string): Promise<string> {
  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    const now = Math.floor(Date.now() / 1000);

    const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claim = btoa(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      })
    );

    const signingInput = `${header}.${claim}`;
    const privateKey = serviceAccount.private_key;

    // RSA-SHA256 서명
    const keyData = privateKey
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\n/g, "");

    const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      new TextEncoder().encode(signingInput)
    );

    const jwt = `${signingInput}.${btoa(
      String.fromCharCode(...new Uint8Array(signature))
    )}`;

    // OAuth2 토큰 교환
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });

    const tokenData = await tokenRes.json();
    return tokenData.access_token;
  } catch (e) {
    console.error("Access Token 발급 실패:", e);
    throw e;
  }
}
