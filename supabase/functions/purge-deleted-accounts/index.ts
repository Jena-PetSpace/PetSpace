// supabase/functions/purge-deleted-accounts/index.ts
// 30일 경과 탈퇴 계정 영구 삭제 배치 (pg_cron이 일 1회 호출)
// 가드: x-purge-secret 헤더 == PURGE_SHARED_SECRET (collect-news 공유 시크릿 패턴)
// 처리: Storage 정리 → auth.users 삭제 → public.users 삭제(CASCADE로 연관 데이터 정리)
// 주의: 탈퇴자의 chat_messages도 CASCADE로 영구 삭제됨 — 의도된 동작(30일 유예 중에만 대화 유지)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GRACE_DAYS = 30;
const STORAGE_FOLDERS = ["profiles", "pets", "posts", "emotion_analysis", "chat"];

serve(async (req) => {
  if (req.headers.get("x-purge-secret") !== Deno.env.get("PURGE_SHARED_SECRET")) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const cutoff = new Date(Date.now() - GRACE_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data: targets, error } = await admin
    .from("users")
    .select("id")
    .not("deleted_at", "is", null)
    .lt("deleted_at", cutoff);
  if (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }

  const results: { id: string; ok: boolean; error?: string }[] = [];
  for (const { id } of targets ?? []) {
    try {
      // 1) Storage 정리: 하위 폴더 포함 재귀 삭제 (실패해도 계속)
      const storage = admin.storage.from("images");
      for (const folder of STORAGE_FOLDERS) {
        await removeFolder(storage, `${folder}/${id}`).catch(() => {});
      }
      // 2) auth.users 삭제
      await admin.auth.admin.deleteUser(id);
      // 3) public.users 삭제 (FK CASCADE로 연관 데이터 정리)
      await admin.from("users").delete().eq("id", id);
      results.push({ id, ok: true });
    } catch (e) {
      results.push({ id, ok: false, error: String(e) });
    }
  }

  return new Response(JSON.stringify({ purged: results }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

// 하위 폴더 포함 재귀 삭제.
// Supabase Storage list는 1depth 반환: id !== null → 파일, id === null → 가상 폴더(prefix)
async function removeFolder(
  storage: ReturnType<ReturnType<typeof createClient>["storage"]["from"]>,
  path: string
): Promise<void> {
  const { data: items } = await storage.list(path);
  if (!items || items.length === 0) return;

  const files = items.filter((i) => i.id !== null).map((i) => `${path}/${i.name}`);
  if (files.length > 0) await storage.remove(files);

  const folders = items.filter((i) => i.id === null);
  for (const f of folders) {
    await removeFolder(storage, `${path}/${f.name}`);
  }
}
