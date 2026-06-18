// supabase/functions/request-account-deletion/index.ts
// 계정 soft delete: users.deleted_at 기록 + 전 기기 세션 무효화
// 호출: POST /functions/v1/request-account-deletion (사용자 JWT 필요)
// 참고: Apple token revoke는 앱이 Apple 토큰을 저장하지 않아 미구현 — iOS 트랙 인계

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!jwt) {
      return new Response(JSON.stringify({ error: "인증 토큰이 없습니다." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "유효하지 않은 사용자입니다." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1) soft delete 기록 (이미 탈퇴 상태면 no-op)
    const { error: updateError } = await admin
      .from("users")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", user.id)
      .is("deleted_at", null);
    if (updateError) throw updateError;

    // 2) 전 기기 세션 무효화 (복구는 재로그인으로만 가능)
    await admin.auth.admin.signOut(jwt, "global");

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
