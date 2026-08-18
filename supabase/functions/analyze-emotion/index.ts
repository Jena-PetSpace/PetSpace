// Retired legacy endpoint.
//
// All PetSpace AI analysis now uses the authenticated gemini-proxy function.
// Keep this authenticated tombstone in source until an operator either deploys
// it with JWT verification enabled or deletes the deployed legacy function.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

function jsonResponse(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const jwt = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";

  if (!jwt) {
    return jsonResponse(401, {
      error: "인증 토큰이 필요합니다.",
      code: "AUTH_REQUIRED",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(500, {
      error: "요청을 처리하지 못했습니다.",
      code: "SERVER_CONFIGURATION_ERROR",
    });
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const { data, error } = await supabase.auth.getUser(jwt);
  if (error || !data.user) {
    return jsonResponse(401, {
      error: "유효하지 않은 인증 토큰입니다.",
      code: "AUTH_INVALID",
    });
  }

  return jsonResponse(410, {
    error: "이 엔드포인트는 폐기되었습니다. 분석은 gemini-proxy를 사용합니다.",
    code: "LEGACY_ENDPOINT_RETIRED",
  });
});
