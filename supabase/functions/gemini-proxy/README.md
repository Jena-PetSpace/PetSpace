# gemini-proxy

Gemini API 키를 앱 바이너리에서 제거하기 위한 패스스루 프록시 Edge Function.
앱(`GeminiAIService._callApi`)이 직접 `generativelanguage.googleapis.com`를 호출하지 않고
이 함수를 경유한다. 키는 Supabase Secrets에만 보관된다.

## 동작
1. `Authorization: Bearer <accessToken>`의 JWT를 검증(미인증 → 401).
2. v1 최소 rate limit(사용자당 분당 20회, 인스턴스 메모리 기반 best-effort).
3. 앱이 보낸 본문(`{contents, generationConfig, safetySettings}`)을 **변형 없이** 그대로
   `gemini-2.5-flash:generateContent`로 전달(모델·엔드포인트 서버 고정).
4. Gemini 응답을 상태코드·body 그대로 반환(패스스루) → 앱의 `_parseResponse` 무변경.

## ⚠️ 사용자 수동 작업 (배포 — 앱 출시 전 필수)

1. **Secrets 등록** — Supabase 대시보드 또는 CLI:
   ```bash
   supabase secrets set GEMINI_API_KEY=<Google AI Studio 키>
   ```
   (`SUPABASE_URL`·`SUPABASE_SERVICE_ROLE_KEY`는 Edge Function 런타임에 기본 주입됨)

2. **배포 — `--no-verify-jwt` 절대 사용 금지** (JWT 검증 유지):
   ```bash
   supabase functions deploy gemini-proxy
   ```

3. **(배포·앱 전환 검증 후) 기존 노출 가능성 있는 키 회전**:
   Google AI Studio에서 앱 바이너리에 박혀 있던 기존 Gemini 키를 폐기하고 신규 발급 권장.

4. 프로젝트 ref: `juukbctqzlrxfnivhgqe`
   엔드포인트: `https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/gemini-proxy`

## TODO (v2)
- 사용자당 영구 rate limit(`user_id` + 분 단위 테이블 또는 Postgres). 현재는 인스턴스 메모리라
  콜드스타트/멀티인스턴스에서 리셋됨.
