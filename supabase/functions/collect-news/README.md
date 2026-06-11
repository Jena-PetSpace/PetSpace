# collect-news — 펫 뉴스 RSS 수집 Edge Function

매일 09:00 KST 외부 RSS를 수집해 `news_articles`에 `status='pending'`으로 적재한다.
운영자가 대시보드에서 `published` 토글 → 앱은 발행분만 노출(원문 링크아웃).

## 저작권 원칙
- **제목·링크·발행일·출처만** 저장. 본문/요약(`description`)/썸네일 **미저장**.
- 기사 읽기는 앱에서 원문 링크아웃.

## 동작
1. `news_sources`에서 `is_active=true` 소스 조회.
2. 각 소스 RSS fetch → `<item>` 파싱(title/link/pubDate/source).
3. 관련도 필터: 제목에 펫 키워드 포함 **AND** 차단 키워드 미포함.
4. `link` UNIQUE + `upsert(onConflict:'link', ignoreDuplicates:true)`로 중복 무시.
5. 소스별 try/catch — 한 소스 실패가 전체를 막지 않음. 응답에 `inserted`·`report`.

## 파서 (작업0 검증 반영)
- **데일리벳**(WordPress): pubDate = RFC-822 → `new Date()` 직접 파싱.
- **뉴스펫/한국반려동물신문**(한국 CMS): pubDate = `YYYY-MM-DD HH:MM:SS`(TZ 없음) → **KST(+09:00)로 간주**.
- **구글뉴스**: 출처 = `<source url="…">매체명</source>` 태그 우선(없으면 제목 끝 `- 매체명` 분리). link는 구글 리다이렉트 URL(링크아웃 정상, 원문 직링크는 2차).

## 배포
```bash
# 게이트웨이 JWT 검증 없이 배포(서버 전용 함수 — 내부에서 service-role로 동작).
# 새 API 키 체계(sb_secret_/sb_publishable_) 프로젝트는 레거시 JWT가 없어 --no-verify-jwt 권장.
supabase functions deploy collect-news --no-verify-jwt
```
함수 환경변수(시크릿)는 Supabase가 자동 주입:
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (RLS 우회 — **앱/깃 커밋 절대 금지**).

### 공개 URL 보호 (no-verify-jwt 보완)
`--no-verify-jwt`면 URL을 아는 누구나 호출 가능 → **공유 시크릿 가드**로 차단:
- 함수 시크릿 `COLLECT_NEWS_SECRET`을 임의 문자열로 설정.
- 설정돼 있으면 요청 헤더 `x-collect-secret`이 일치할 때만 실행(불일치 403).
- 미설정 시 가드 비활성(최초 검증 편의). 검증 후 반드시 설정 권장:
```bash
supabase secrets set COLLECT_NEWS_SECRET=<임의-긴-문자열>
```
- cron의 net.http_post 헤더에 같은 값을 넣는다(아래 cron SQL 참조).
- 이 시크릿도 **코드·깃 커밋 금지**(함수 시크릿·cron 헤더에만).

## 수동 1회 실행(검증)
대시보드 > Edge Functions > collect-news > Invoke, 또는:
```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/collect-news" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
  -H "Content-Type: application/json"
```
응답의 `inserted`·`report` 확인 → Table Editor에서 `news_articles` pending 적재 확인.

## cron 등록 (검증 후)
Supabase 대시보드 > Database > Extensions에서 `pg_cron`, `pg_net` 활성화 후 SQL Editor:
```sql
-- 매일 00:00 UTC(=09:00 KST). cron은 UTC 기준임에 주의.
-- --no-verify-jwt로 배포했으므로 Authorization 불필요.
-- 대신 COLLECT_NEWS_SECRET을 설정했다면 x-collect-secret 헤더로 같은 값을 전달.
select cron.schedule(
  'collect-news-daily',
  '0 0 * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/collect-news',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-collect-secret','<COLLECT_NEWS_SECRET>'
    )
  );
  $$
);
```
해제: `select cron.unschedule('collect-news-daily');`

## 운영(검수)
Table Editor에서 pending 행 확인 → 적합하면 `status='published'`,
부적합(펫 무관·자극적·광고성)이면 `'rejected'`, `reviewed_at=now()`.
