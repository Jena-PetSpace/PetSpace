// 30일 경과 탈퇴 계정 영구 삭제 배치.
// Storage → 잔존 콘텐츠 스냅샷 → auth.users → public.users 순서로 정리한다.
// 부분 실패한 계정은 다음 실행에서 안전하게 재시도하며 사용자 ID나 원문
// 오류는 응답·로그에 남기지 않는다.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.111.0";

const GRACE_DAYS = 30;
const LOCATION_AUDIT_RETENTION_MONTHS = 6;
const STORAGE_FOLDERS = ["profiles", "pets", "posts", "emotion_analysis", "chat"];
const PAGE_SIZE = 100;

class PurgeError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "request_failed", code: "METHOD_NOT_ALLOWED" });
  }

  const purgeSecret = requireEnvironment("PURGE_SHARED_SECRET");
  if (req.headers.get("x-purge-secret") !== purgeSecret) {
    return jsonResponse(401, { error: "request_failed", code: "UNAUTHORIZED" });
  }

  const admin = createClient(
    requireEnvironment("SUPABASE_URL"),
    requireEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  try {
    await purgeExpiredLocationAudit(admin, new Date());
  } catch {
    return jsonResponse(503, {
      error: "request_failed",
      code: "LOCATION_AUDIT_EXPIRY_FAILED",
    });
  }

  const cutoff = new Date(Date.now() - GRACE_DAYS * 24 * 60 * 60 * 1000).toISOString();
  let afterId: string | null = null;
  let purged = 0;
  let failed = 0;
  const failureCodes: Record<string, number> = {};

  while (true) {
    let query = admin
      .from("users")
      .select("id")
      .not("deleted_at", "is", null)
      .lt("deleted_at", cutoff)
      .order("id", { ascending: true })
      .limit(PAGE_SIZE);
    if (afterId != null) {
      query = query.gt("id", afterId);
    }

    const { data: targets, error } = await query;
    if (error) {
      return jsonResponse(503, {
        error: "request_failed",
        code: "TARGET_LOOKUP_FAILED",
      });
    }
    if (!targets || targets.length === 0) break;

    for (const { id } of targets) {
      afterId = id;
      try {
        const storage = admin.storage.from("images");
        for (const folder of STORAGE_FOLDERS) {
          await removeFolder(storage, `${folder}/${id}`);
        }

        await removeResidualSnapshots(admin, id);
        await deleteAuthUserIfPresent(admin, id);

        const { error: profileDeleteError } = await admin
          .from("users")
          .delete()
          .eq("id", id);
        if (profileDeleteError) {
          throw new PurgeError("PROFILE_DELETE_FAILED");
        }

        const { data: remainingProfile, error: verifyError } = await admin
          .from("users")
          .select("id")
          .eq("id", id)
          .maybeSingle();
        if (verifyError || remainingProfile != null) {
          throw new PurgeError("PROFILE_DELETE_UNVERIFIED");
        }
        purged += 1;
      } catch (error) {
        failed += 1;
        const code = error instanceof PurgeError
          ? error.code
          : "ACCOUNT_PURGE_FAILED";
        failureCodes[code] = (failureCodes[code] ?? 0) + 1;
      }
    }
  }

  return jsonResponse(failed === 0 ? 200 : 503, {
    ok: failed === 0,
    purged,
    failed,
    failureCodes,
  });
});

async function purgeExpiredLocationAudit(
  admin: SupabaseClient,
  now: Date,
): Promise<void> {
  const cutoff = subtractUtcMonths(
    now,
    LOCATION_AUDIT_RETENTION_MONTHS,
  ).toISOString();
  const { error } = await admin
    .from("location_access_log")
    .delete()
    .lt("used_at", cutoff);
  if (error) throw new PurgeError("LOCATION_AUDIT_EXPIRY_FAILED");
}

function subtractUtcMonths(date: Date, months: number): Date {
  const targetMonthIndex = date.getUTCMonth() - months;
  const targetYear = date.getUTCFullYear() + Math.floor(targetMonthIndex / 12);
  const targetMonth = ((targetMonthIndex % 12) + 12) % 12;
  const lastTargetDay = new Date(
    Date.UTC(targetYear, targetMonth + 1, 0),
  ).getUTCDate();
  return new Date(Date.UTC(
    targetYear,
    targetMonth,
    Math.min(date.getUTCDate(), lastTargetDay),
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds(),
    date.getUTCMilliseconds(),
  ));
}

async function removeFolder(
  storage: ReturnType<ReturnType<typeof createClient>["storage"]["from"]>,
  path: string,
): Promise<void> {
  const items: Array<{ id: string | null; name: string }> = [];
  let offset = 0;
  while (true) {
    const { data, error } = await storage.list(path, {
      limit: PAGE_SIZE,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new PurgeError("STORAGE_LIST_FAILED");
    if (!data || data.length === 0) break;
    items.push(...data);
    if (data.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }
  if (items.length === 0) return;

  const files = items.filter((i) => i.id !== null).map((i) => `${path}/${i.name}`);
  for (let start = 0; start < files.length; start += PAGE_SIZE) {
    const { error } = await storage.remove(
      files.slice(start, start + PAGE_SIZE),
    );
    if (error) throw new PurgeError("STORAGE_DELETE_FAILED");
  }

  const folders = items.filter((i) => i.id === null);
  for (const f of folders) {
    await removeFolder(storage, `${path}/${f.name}`);
  }
}

async function removeResidualSnapshots(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  // sender_id가 ON DELETE SET NULL인 알림에는 title/body/data가 남는다.
  // 발신자의 계정 삭제 후에도 내용을 역추적할 수 없도록 행 전체를 삭제한다.
  const { error: notificationDeleteError } = await admin
    .from("notifications")
    .delete()
    .eq("sender_id", userId);
  if (notificationDeleteError) {
    throw new PurgeError("NOTIFICATION_CONTENT_DELETE_FAILED");
  }

  // chat_messages는 public.users 삭제 시 cascade되지만 chat_rooms의 마지막
  // 메시지 스냅샷은 SET NULL FK와 별개다. 작성자 정보와 함께 내용을 비운다.
  const { error: chatPreviewClearError } = await admin
    .from("chat_rooms")
    .update({
      last_message: null,
      last_message_at: null,
      last_message_sender_id: null,
    })
    .eq("last_message_sender_id", userId);
  if (chatPreviewClearError) {
    throw new PurgeError("CHAT_PREVIEW_CLEAR_FAILED");
  }
}

async function deleteAuthUserIfPresent(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data, error: lookupError } = await admin.auth.admin.getUserById(
    userId,
  );
  if (lookupError) {
    if (
      lookupError.status === 404 ||
      lookupError.code === "user_not_found"
    ) {
      return;
    }
    throw new PurgeError("AUTH_USER_LOOKUP_FAILED");
  }
  if (!data.user) return;

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) throw new PurgeError("AUTH_USER_DELETE_FAILED");
}

function requireEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new PurgeError("SERVICE_NOT_CONFIGURED");
  return value;
}

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
