// =====================================================================
// collect-news — 펫 뉴스 RSS 반자동 수집 (Supabase Edge Function / Deno)
// 매일 09:00 KST(=00:00 UTC) pg_cron 트리거. news_articles에 status='pending' 적재.
// 저작권: 제목·링크·발행일·출처만 저장. 본문/요약(description)/썸네일 미저장.
// service_role 키로 동작(RLS 우회) → 함수 환경변수로만. 앱/깃 커밋 금지.
//
// 작업0 검증(2026-06-08) 반영:
//  · 데일리벳(WordPress): pubDate = RFC-822 (Mon, 08 Jun 2026 02:24:13 +0000)
//  · 뉴스펫/한국반려동물신문(한국 CMS): pubDate = "YYYY-MM-DD HH:MM:SS" (TZ 없음 → KST 간주)
//  · 구글뉴스: link=구글 리다이렉트 URL, 출처=<source> 태그 또는 제목 끝 "- 매체명",
//    종합 매체라 차단 키워드로 자극적·무관 기사 1차 거름(반자동 검수가 최종 방어선)
// =====================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 펫 관련도: 제목에 아래 키워드 하나라도 있어야 후보
const PET_KEYWORDS = [
  "반려", "강아지", "고양이", "반려견", "반려묘", "반려동물",
  "펫", "동물", "수의", "유기견", "유기묘", "냥", "댕댕",
];

// 차단: 헬스케어 앱 신뢰도 보호. 자극적·무관 기사 거름(구글뉴스 종합 매체 대비)
const BLOCK_KEYWORDS = [
  "학대", "도살", "사망", "안락사", "이혼", "정치", "성범죄",
  "살해", "엽기", "도박", "주가", "코인",
];

interface Source {
  id: string;
  name: string;
  rss_url: string;
}

interface ParsedItem {
  title: string;
  link: string;
  publishedAt: string | null; // ISO8601 또는 null
  source: string;             // <source> 태그 매체명(구글뉴스). 없으면 빈 문자열.
}

serve(async (req) => {
  // 공유 시크릿 가드: 게이트웨이 JWT 검증을 끄고(no-verify-jwt) 배포하므로,
  // COLLECT_NEWS_SECRET 환경변수가 설정돼 있으면 x-collect-secret 헤더와 일치할 때만 실행.
  // (cron net.http_post 헤더로 전달. 미설정 시 가드 비활성 — 최초 검증 편의.)
  const expected = Deno.env.get("COLLECT_NEWS_SECRET");
  if (expected && req.headers.get("x-collect-secret") !== expected) {
    return json({ ok: false, error: "forbidden" }, 403);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: sources, error } = await supabase
    .from("news_sources")
    .select("id, name, rss_url")
    .eq("is_active", true);

  if (error) return json({ ok: false, error: error.message }, 500);

  let inserted = 0;
  const report: Record<string, number | string> = {};

  for (const src of (sources ?? []) as Source[]) {
    try {
      const res = await fetch(src.rss_url, {
        headers: { "User-Agent": "PetSpaceBot/1.0 (+petspace news collector)" },
      });
      if (!res.ok) {
        report[src.name] = `fetch ${res.status}`;
        continue;
      }
      const xml = await res.text();
      const items = parseRss(xml);

      const rows = items
        .map((it) => {
          // 출처: <source> 태그(구글뉴스) 우선, 없으면 제목 끝 "- 매체명" 분리,
          //       둘 다 없으면 소스명(데일리벳·뉴스펫 등)
          const { title, sourceFromTitle } = splitTitleAndSource(it.title);
          const sourceName = it.source || sourceFromTitle || src.name;
          return {
            source_id: src.id,
            source_name: sourceName,
            title,
            link: it.link,
            published_at: it.publishedAt,
          };
        })
        .filter((r) => r.title && r.link)
        // 관련도: 펫 키워드 포함 + 차단 키워드 제외
        .filter((r) => PET_KEYWORDS.some((k) => r.title.includes(k)))
        .filter((r) => !BLOCK_KEYWORDS.some((k) => r.title.includes(k)));

      if (rows.length === 0) {
        report[src.name] = 0;
        continue;
      }

      // link UNIQUE → 중복 무시. count로 신규 적재분만 집계.
      const { error: insErr, count } = await supabase
        .from("news_articles")
        .upsert(rows, {
          onConflict: "link",
          ignoreDuplicates: true,
          count: "exact",
        });

      if (insErr) {
        report[src.name] = `insert error: ${insErr.message}`;
        continue;
      }
      inserted += count ?? 0;
      report[src.name] = count ?? 0;
    } catch (e) {
      // 한 소스 실패가 전체를 막지 않음
      report[src.name] = `fetch/parse error: ${String(e)}`;
    }
  }

  return json({ ok: true, inserted, report });
});

// ---------------------------------------------------------------------
// RSS 파서 (RSS 2.0 <item> 기준. 정규식 기반 — 외부 의존성 없이 3개 포맷 처리)
// ---------------------------------------------------------------------
function parseRss(xml: string): ParsedItem[] {
  const items: ParsedItem[] = [];
  const itemRe = /<item\b[^>]*>([\s\S]*?)<\/item>/gi;
  let m: RegExpExecArray | null;
  while ((m = itemRe.exec(xml)) !== null) {
    const block = m[1];
    const title = decode(stripCdata(pick(block, "title")));
    const link = decode(stripCdata(pick(block, "link")));
    const pub = pick(block, "pubDate") || pick(block, "dc:date") ||
      pick(block, "published");
    const publishedAt = parseDate(pub);
    const source = decode(stripCdata(pick(block, "source"))); // 구글뉴스 <source>
    if (!title || !link) continue;
    items.push({ title, link, publishedAt, source });
  }
  return items;
}

// 단일 태그의 첫 매치 내부 텍스트
function pick(block: string, tag: string): string {
  const re = new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i");
  const r = re.exec(block);
  return r ? r[1].trim() : "";
}

function stripCdata(s: string): string {
  const m = /^<!\[CDATA\[([\s\S]*?)\]\]>$/.exec(s.trim());
  return m ? m[1].trim() : s.trim();
}

function decode(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .trim();
}

// "기사제목 - 매체명" → 제목·출처 분리. 패턴 없으면 sourceFromTitle은 빈 문자열.
function splitTitleAndSource(
  raw: string,
): { title: string; sourceFromTitle: string } {
  const m = /^(.*\S)\s+-\s+([^-]+)$/.exec(raw);
  if (m) return { title: m[1].trim(), sourceFromTitle: m[2].trim() };
  return { title: raw.trim(), sourceFromTitle: "" };
}

// 다양한 pubDate 포맷 → ISO8601. 실패 시 null.
// · RFC-822(데일리벳): Date가 직접 파싱.
// · "YYYY-MM-DD HH:MM:SS"(한국 CMS, TZ 없음): KST(+09:00)로 간주.
function parseDate(raw: string): string | null {
  if (!raw) return null;
  const s = raw.trim();

  // TZ 표기 없는 "YYYY-MM-DD HH:MM:SS" → KST로 해석
  const cms = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/.exec(s);
  if (cms) {
    const [, y, mo, d, h, mi, se] = cms;
    const iso = `${y}-${mo}-${d}T${h}:${mi}:${se ?? "00"}+09:00`;
    const dt = new Date(iso);
    return isNaN(dt.getTime()) ? null : dt.toISOString();
  }

  const dt = new Date(s);
  return isNaN(dt.getTime()) ? null : dt.toISOString();
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
