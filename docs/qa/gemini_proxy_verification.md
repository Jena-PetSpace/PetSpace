# gemini-proxy 검증 가이드

Gemini API 키 보호(앱 바이너리 키 제거 + Edge Function 프록시화) 작업의 **코드·배포 검증 절차**.
실기기 분석 동작(감정/건강)은 다른 검증 항목과 묶어서 진행한다.

- 대상 커밋: `apikey-STEP1`(8ca475b) · `apikey-STEP2`(bb90147) · `apikey-STEP2b`(0b682e2)
- 프로젝트 ref: `juukbctqzlrxfnivhgqe`
- 프록시 엔드포인트: `https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/gemini-proxy`

---

## 사전: 사용자 수동 배포 (검증 전 필수)

1. Supabase Secrets 등록: `supabase secrets set GEMINI_API_KEY=<Google AI Studio 키>`
2. 배포: `supabase functions deploy gemini-proxy` — **`--no-verify-jwt` 절대 금지**(JWT 검증 유지)
3. (검증 통과 후) 기존 노출 가능성 있던 Gemini 키 폐기·신규 발급 권장

---

## 1. 앱 APK에 Gemini 키 문자열 미검출

릴리스 APK를 디컴파일하지 않고 문자열만 훑어 `AIza`로 시작하는 Gemini 키가 없는지 확인.

```bash
# 1) 코드 레벨(이미 통과): 앱 소스에 Gemini 평문 키 0건
rg -n "AIzaSy" pjh/lib/        # firebaseApiKey 1건만 나와야 정상(Gemini 키는 0건)
rg -n "generativelanguage" pjh/lib/   # 0건(엔드포인트도 앱에서 제거됨)

# 2) 빌드 산출물 레벨: APK 내 문자열에서 Gemini 키 패턴 미검출
cd pjh && flutter build apk --release --split-per-abi
# Android SDK build-tools의 aapt 또는 unzip 후 strings 검사
unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | strings | grep -c "AIzaSyAVqHgz"   # → 0 기대(기존 노출 키)
```

> 참고: Firebase 키(`AIzaSyBSfhh...`)는 Firebase SDK가 google-services.json/플랫폼 설정에서 사용하는 별개 키로 본 작업 범위 밖. Gemini 키만 검증 대상.

**합격 기준:** APK strings에서 기존 Gemini 키 문자열 0건. 코드 레벨 `generativelanguage` 0건.

---

## 2. Edge Function 로그로 정상 프록시 호출 확인

앱에서 로그인 후 감정/건강 분석 1회 실행 → Supabase 대시보드 Functions > gemini-proxy > Logs 확인.

- 정상: 200 응답 로그, JWT 검증 통과(사용자 식별), Gemini로 패스스루 후 응답 반환.
- 본문 변형 없이 전달됐는지: 분석 결과 화면이 기존과 동일하게 렌더링되면 `_parseResponse` 무변경 + 패스스루 정상.

**합격 기준:** 앱 분석 1회 → gemini-proxy 로그에 200 + 분석 결과 화면 정상 표시.

---

## 3. JWT 없는 직접 호출 → 401

프록시가 미인증 호출을 차단하는지 curl로 확인.

```bash
# 토큰 없이 호출 → 401
curl -i -X POST \
  "https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/gemini-proxy" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"ping"}]}]}'
# 기대: HTTP/2 401  {"error":"인증 토큰이 없습니다."}

# 잘못된 토큰 → 401
curl -i -X POST \
  "https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/gemini-proxy" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid.jwt.token" \
  -d '{"contents":[{"parts":[{"text":"ping"}]}]}'
# 기대: HTTP/2 401  {"error":"유효하지 않은 사용자입니다."}
```

**합격 기준:** 토큰 없음/무효 모두 401. (서버에 키가 있어도 미인증은 Gemini까지 도달 못 함)

---

## 3.1 레거시 analyze-emotion 폐기 확인

운영 function은 삭제하는 방식을 권고한다. 삭제 대신 정본 tombstone을 배포했다면
**`--no-verify-jwt` 없이** 배포하고 다음 응답을 확인한다.

```bash
# 토큰 없음 → 401
curl -i -X POST \
  "https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/analyze-emotion" \
  -H "Content-Type: application/json" \
  -d '{}'

# 유효한 QA 계정 access token → 410 + LEGACY_ENDPOINT_RETIRED
# 실제 토큰은 문서·로그·Git에 남기지 않는다.
curl -i -X POST \
  "https://juukbctqzlrxfnivhgqe.supabase.co/functions/v1/analyze-emotion" \
  -H "Authorization: Bearer <QA_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"ignored":true}'
```

호출 전후 QA 계정의 `emotion_history` 행과 `images/emotions/**` 객체 수가 같아야 한다.
운영 function을 삭제했다면 410 대신 gateway 404를 합격으로 본다.

---

## 4. 앱 분석 동작 회귀 (실기기 — 묶음 검증)

> 실기기 검증은 다른 항목과 함께 모아서 진행. 아래는 체크 항목만.

- [ ] 로그인 상태에서 감정 분석(단일/다중 이미지 5장) → 결과 화면 정상(점수·부위별·팁)
- [ ] 건강 분석 → 결과 화면 정상
- [ ] 일기 생성(generateText 경로) → 정상
- [ ] **비로그인 상태**에서 분석 시도 → "로그인이 필요합니다." 처리(사전 가드 + `_callApi` 세션 가드)
- [ ] 다중 이미지 5장(최대) base64 페이로드가 프록시 한도 내 정상 처리(코드 판단: 1024² JPEG q85 × 5 ≈ ~3MB, 한도 내)

---

## 무변경 보장 (회귀 없음 근거)

- `_parseResponse`·`_extractJson`·`_buildPrompt`·`_buildRequest`·`_buildTextRequest`·`EmotionScoresModel` **무변경**(diff 0). 프록시가 Gemini 응답을 상태코드·body 그대로 패스스루하므로 파싱부는 기존과 동일하게 동작.
- 변경은 `_callApi`의 URL·인증부 + 진입 가드의 세션 체크 전환뿐.

## 후속 TODO (범위 밖, 별도 추적)
- 레거시 `analyze-emotion` 운영 폐기는 `RELEASE_DEPLOY_VERIFY_CHECKLIST.md` PHASE 1의
  수동 게이트에서 완료한다. 로컬 tombstone만으로 운영 폐기를 대신하지 않는다.
- gemini-proxy v2: 사용자당 영구 rate limit(현재 인메모리 best-effort).
- secrets.dart의 `firebaseApiKey` 등 다른 평문 키 처리 방향 결정.
