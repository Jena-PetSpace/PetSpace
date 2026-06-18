// supabase/functions/gemini-proxy/index.ts
// Gemini API 키 보호 프록시: 앱이 보낸 요청 본문을 서버 보관 키로 Gemini에 그대로 전달하고
// Gemini 응답을 그대로 반환(패스스루). 키는 앱 바이너리에 노출되지 않는다.
//
// 호출: POST /functions/v1/gemini-proxy  (사용자 JWT 필요 — Authorization: Bearer <accessToken>)
// 본문: { contents, generationConfig, safetySettings }  ← 앱의 _buildRequest/_buildTextRequest 형태 그대로
// 모델: 서버에서 gemini-2.5-flash 로 고정(앱은 모델명/엔드포인트를 보내지 않는다).
//
// ⚠️ 배포 시 --no-verify-jwt 사용 금지(JWT 검증 유지). GEMINI_API_KEY는 Supabase Secrets에만.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 모델/엔드포인트 서버 고정 — 앱이 임의 모델을 호출하지 못하게 한다.
const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

// v1 최소 rate limit (사용자당 분당 호출 수). 인스턴스 메모리 기반이라 best-effort —
// 콜드스타트/멀티인스턴스에서 리셋될 수 있다. 영구 제한(user_id+분 단위 테이블)은 TODO.
const RATE_LIMIT_PER_MINUTE = 20;
const _hits = new Map<string, { count: number; windowStart: number }>();

function rateLimited(userId: string, now: number): boolean {
  const win = 60_000;
  const cur = _hits.get(userId);
  if (!cur || now - cur.windowStart >= win) {
    _hits.set(userId, { count: 1, windowStart: now });
    return false;
  }
  cur.count += 1;
  return cur.count > RATE_LIMIT_PER_MINUTE;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "POST만 허용됩니다." }, 405);
  }

  try {
    // 1) JWT 검증 (미인증 401)
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!jwt) {
      return json({ error: "인증 토큰이 없습니다." }, 401);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !user) {
      return json({ error: "유효하지 않은 사용자입니다." }, 401);
    }

    // 2) rate limit (인증 사용자 기준, best-effort)
    if (rateLimited(user.id, Date.now())) {
      return json({ error: "요청이 너무 많습니다. 잠시 후 다시 시도해주세요." }, 429);
    }

    // 3) 서버 보관 키 확인
    const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
    if (!apiKey) {
      return json({ error: "서버 구성 오류: GEMINI_API_KEY 미설정." }, 500);
    }

    // 4) 앱이 보낸 본문을 변형 없이 그대로 받는다 ({contents, generationConfig, safetySettings})
    const body = await req.text();

    // 5) 서버 키로 Gemini 호출 — 모델/엔드포인트는 서버 고정
    const geminiRes = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body, // 패스스루 (본문 변형 없음)
    });

    // 6) Gemini 응답을 그대로 반환 (상태코드·body 패스스루)
    const text = await geminiRes.text();
    return new Response(text, {
      status: geminiRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
