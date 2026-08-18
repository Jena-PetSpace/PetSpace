-- =====================================================================
-- 펫페이스 펫 뉴스 → Supabase 마이그레이션 (F1)
-- 적용: Supabase 대시보드 > SQL Editor 에서 수동 실행
-- 주의: 마스터 petspace_setup.sql 직접 변경 아님(커밋용 별도 갱신).
-- 저작권 원칙: 제목·발행일·출처·원문 링크만 저장. 본문/요약/썸네일 컬럼 없음.
-- 소스 확정(작업0 검증, 2026-06-08):
--   · 데일리벳(WordPress·품질)        is_active=true
--   · 뉴스펫(한국형 CMS)               is_active=true
--   · 구글뉴스("반려동물" 키워드·분량)  is_active=true
--   · 한국반려동물신문(약 10개월 휴면)  is_active=false (수집 제외, 부활 시 토글)
-- =====================================================================

-- 1) 수집 소스 목록 -----------------------------------------------------
create table if not exists public.news_sources (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,                 -- 매체명(출처 표시용)
  rss_url     text not null unique,          -- RSS 피드 URL
  is_active   boolean not null default true, -- 수집 on/off
  created_at  timestamptz not null default now()
);

comment on table public.news_sources is '펫 뉴스 RSS 수집 소스';

-- 2) 수집 기사 ----------------------------------------------------------
create table if not exists public.news_articles (
  id            uuid primary key default gen_random_uuid(),
  source_id     uuid references public.news_sources(id) on delete set null,
  source_name   text not null,                -- 출처(매체명) — 표시용 비정규화
  title         text not null,                -- 기사 제목
  link          text not null unique,         -- 원문 URL (중복 방지 키)
  published_at  timestamptz,                  -- 원문 발행일(파싱)
  status        text not null default 'pending'
                check (status in ('pending','published','rejected')),
  collected_at  timestamptz not null default now(),
  reviewed_at   timestamptz                   -- 검수(발행/반려) 시각
);

comment on table public.news_articles is '수집된 펫 뉴스(반자동 검수). 본문 미저장 → 링크아웃 전용';

-- 발행분 최신순 조회 최적화
create index if not exists idx_news_articles_status_pub
  on public.news_articles (status, published_at desc);

-- 3) RLS ---------------------------------------------------------------
alter table public.news_articles enable row level security;
alter table public.news_sources  enable row level security;

-- 앱: 발행된 기사만 읽기 가능
drop policy if exists "news read published" on public.news_articles;
create policy "news read published"
  on public.news_articles
  for select
  using (status = 'published');

-- INSERT/UPDATE/DELETE 정책 없음 → anon/authenticated 불가.
-- 수집(Edge Function)·검수(대시보드)는 service_role 키로 RLS 우회.
-- 소스 목록도 앱에서 읽을 필요 없음 → 정책 없음(서버 전용).

-- 4) 소스 시드 (작업0 검증 결과 반영) ----------------------------------
-- 구글뉴스 URL의 q는 URL 인코딩 필수(반려동물 = %EB%B0%98%EB%A0%A4%EB%8F%99%EB%AC%BC).
insert into public.news_sources (name, rss_url, is_active) values
  ('데일리벳',         'https://www.dailyvet.co.kr/feed',                        true),
  ('뉴스펫',           'https://www.newspet.co.kr/rss/allArticle.xml',           true),
  ('구글뉴스(반려동물)', 'https://news.google.com/rss/search?q=%EB%B0%98%EB%A0%A4%EB%8F%99%EB%AC%BC&hl=ko&gl=KR&ceid=KR:ko', true),
  ('한국반려동물신문', 'http://www.pet-news.or.kr/rss/allArticle.xml',           false)  -- 휴면, 수집 제외
on conflict (rss_url) do nothing;

-- =====================================================================
-- 참고: 수집기(Edge Function)의 insert 패턴
--   insert into public.news_articles (source_id, source_name, title, link, published_at)
--   values (...) on conflict (link) do nothing;
-- 검수: 대시보드 Table Editor에서 status pending→published(또는 rejected),
--       reviewed_at = now() 로 갱신.
-- =====================================================================
