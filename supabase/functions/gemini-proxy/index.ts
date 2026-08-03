// supabase/functions/gemini-proxy/index.ts
// Gemini API 키 보호 프록시: 앱 요청을 검증·정규화한 뒤 서버 보관 키로 Gemini에 전달한다.
// 키는 앱 바이너리에 노출되지 않는다.
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
const MAX_REQUEST_BYTES = 12 * 1024 * 1024;
const MAX_TEXT_CHARS = 12_000;
const MAX_OUTPUT_TOKENS = 4_096;
const MAX_IMAGE_PARTS = 5;
const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
]);
const SAFETY_SETTINGS = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
];
const _hits = new Map<string, { count: number; windowStart: number }>();

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeRequest(value: unknown): Record<string, unknown> | null {
  if (!isRecord(value)) return null;
  const allowedRootKeys = new Set(["contents", "generationConfig", "safetySettings"]);
  if (Object.keys(value).some((key) => !allowedRootKeys.has(key))) return null;

  const contents = value.contents;
  if (!Array.isArray(contents) || contents.length !== 1 || !isRecord(contents[0])) {
    return null;
  }
  if (Object.keys(contents[0]).some((key) => key !== "parts")) return null;
  const parts = contents[0].parts;
  if (
    !Array.isArray(parts) ||
    parts.length < 1 ||
    parts.length > MAX_IMAGE_PARTS + 1
  ) return null;

  let textParts = 0;
  let imageParts = 0;
  const normalizedParts: Record<string, unknown>[] = [];
  for (const part of parts) {
    if (!isRecord(part)) return null;
    const keys = Object.keys(part);
    if (keys.length === 1 && typeof part.text === "string") {
      if (part.text.length < 1 || part.text.length > MAX_TEXT_CHARS) return null;
      textParts += 1;
      normalizedParts.push({ text: part.text });
      continue;
    }
    if (keys.length === 1 && isRecord(part.inline_data)) {
      const inline = part.inline_data;
      if (
        Object.keys(inline).some((key) => key !== "mime_type" && key !== "data") ||
        typeof inline.mime_type !== "string" ||
        !ALLOWED_MIME_TYPES.has(inline.mime_type) ||
        typeof inline.data !== "string" ||
        inline.data.length === 0
      ) {
        return null;
      }
      imageParts += 1;
      normalizedParts.push({
        inline_data: { mime_type: inline.mime_type, data: inline.data },
      });
      continue;
    }
    return null;
  }
  if (textParts !== 1 || imageParts > MAX_IMAGE_PARTS) return null;

  const rawConfig = value.generationConfig;
  if (rawConfig !== undefined && !isRecord(rawConfig)) return null;
  const config = rawConfig as Record<string, unknown> | undefined;
  const allowedConfigKeys = new Set([
    "temperature",
    "topK",
    "topP",
    "maxOutputTokens",
    "responseMimeType",
  ]);
  if (config && Object.keys(config).some((key) => !allowedConfigKeys.has(key))) {
    return null;
  }
  const boundedNumber = (
    candidate: unknown,
    fallback: number,
    min: number,
    max: number,
  ): number | null => {
    if (candidate === undefined) return fallback;
    return typeof candidate === "number" && Number.isFinite(candidate) &&
        candidate >= min && candidate <= max
      ? candidate
      : null;
  };
  const temperature = boundedNumber(config?.temperature, 0.4, 0, 1);
  const topK = boundedNumber(config?.topK, 32, 1, 64);
  const topP = boundedNumber(config?.topP, 1, 0, 1);
  const maxOutputTokens = boundedNumber(
    config?.maxOutputTokens,
    MAX_OUTPUT_TOKENS,
    1,
    MAX_OUTPUT_TOKENS,
  );
  if ([temperature, topK, topP, maxOutputTokens].some((item) => item === null)) {
    return null;
  }
  const responseMimeType = config?.responseMimeType;
  if (
    responseMimeType !== undefined &&
    responseMimeType !== "application/json" &&
    responseMimeType !== "text/plain"
  ) {
    return null;
  }

  return {
    contents: [{ parts: normalizedParts }],
    generationConfig: {
      temperature,
      topK,
      topP,
      maxOutputTokens,
      ...(responseMimeType === undefined ? {} : { responseMimeType }),
    },
    safetySettings: SAFETY_SETTINGS,
  };
}

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

    // 4) 과도한 요청과 임의 프록시 사용을 차단한다.
    const declaredLength = Number(req.headers.get("content-length") ?? "0");
    if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
      return json({ error: "요청 이미지 용량이 너무 큽니다." }, 413);
    }
    const body = await req.text();
    if (new TextEncoder().encode(body).byteLength > MAX_REQUEST_BYTES) {
      return json({ error: "요청 이미지 용량이 너무 큽니다." }, 413);
    }

    let parsedBody: unknown;
    try {
      parsedBody = JSON.parse(body);
    } catch {
      return json({ error: "요청 형식이 올바르지 않습니다." }, 400);
    }
    const requestBody = normalizeRequest(parsedBody);
    if (requestBody === null) {
      return json({ error: "허용되지 않거나 잘못된 분석 요청입니다." }, 400);
    }

    // 5) 서버 키로 Gemini 호출 — 모델/엔드포인트는 서버 고정
    const geminiRes = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    });

    // 6) Gemini 응답을 그대로 반환 (상태코드·body 패스스루)
    const text = await geminiRes.text();
    return new Response(text, {
      status: geminiRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch {
    return json({ error: "분석 요청을 처리하지 못했습니다." }, 500);
  }
});
