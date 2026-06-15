# 통합 배포·검증 체크리스트 (출시 전 정리 회차)

이번 세션까지 코드는 완료됐으나 **실제 동작이 미검증**인 4개 트랙을 한 번에 배포·검증한다.
**순서 의존성이 있으니 위에서부터 차례로** 진행할 것. (예: gemini-proxy 배포 전엔 분석 기능
자체가 안 돌아 분석 검증 불가.)

- 작성일: 2026-06-14 / 브랜치: win-android-release (모두 푸시 완료)
- 표기: 🟦=정현님 대시보드/콘솔 수동 작업, 📱=실기기 검증, ⛔=선행 의존성

---

## PHASE 0 — 빌드 준비
- [ ] `cd pjh && flutter pub get`
- [ ] `flutter analyze` → 0 / `flutter test` → 262 pass·14 baseline(사전 실패, Sprint5 인계) 확인
- [ ] 릴리스 빌드 가능 확인: `flutter build apk --release --split-per-abi`

---

## PHASE 1 — Gemini 프록시 배포 ⚠️ 최우선 (이게 안 되면 분석 기능 먹통 → 다른 검증 다 막힘)

🟦 **배포**
- [ ] Supabase Secrets: `supabase secrets set GEMINI_API_KEY=<Google AI Studio 신규 키>`
- [ ] `supabase functions deploy gemini-proxy`  ⛔ **`--no-verify-jwt` 절대 금지**(JWT 검증 유지)
- [ ] (배포·전환 검증 후) **기존 노출 Gemini 키 폐기·재발급** — 이미 배포된 빌드/산출물에 옛 키
      `AIzaSyAVqHgz...`가 박혀 있어 프록시화만으론 옛 키가 계속 유효. Google AI Studio에서 폐기.

📱 **검증** (docs/qa/gemini_proxy_verification.md)
- [ ] APK strings에 기존 Gemini 키 미검출: `unzip -p app-arm64-v8a-release.apk | strings | grep -c AIzaSyAVqHgz` → 0
- [ ] 로그인 후 감정 분석 1회 → 결과 화면 정상 + gemini-proxy 로그에 200
- [ ] JWT 없이 curl → 401 / 잘못된 토큰 → 401

> ⛔ **이 PHASE가 끝나야 PHASE 4의 분석 동작 검증이 가능.**

---

## PHASE 2 — 계정 soft delete 배포 (App Store 5.1.1 필수)

🟦 **배포 (순서 엄수)**
- [ ] 1) `G1_account_soft_delete.sql` 대시보드 SQL Editor 실행 (기존 delete_user_account RPC DROP 포함)
- [ ] 2) Edge Function 2종 배포:
      `supabase functions deploy request-account-deletion`
      `supabase functions deploy purge-deleted-accounts --no-verify-jwt`  ← purge만 no-verify-jwt(cron/시크릿 호출)
- [ ] 3) `PURGE_SHARED_SECRET` 시크릿 등록
- [ ] 4) pg_cron·pg_net 활성화 후 purge cron 등록

📱 **검증** (docs/qa/account_soft_delete_e2e.md 시나리오 1~5)
- [ ] S1: 탈퇴 → 재로그인 시 "계정 복구" 다이얼로그(잔여 30일) → 복구 → deleted_at IS NULL
- [ ] S2: 탈퇴자 콘텐츠 타인 시점 비노출(피드/검색/상세) — 기존 채팅방 메시지는 유지
- [ ] S3: 2기기 로그인 → 1기기 탈퇴 → 2기기 다음 호출/재시작 시 로그인 화면
- [ ] S4: deleted_at 31일 전 조작 → purge 수동 호출 → 영구 삭제(연관 데이터·Storage·chat_messages CASCADE)
- [ ] S5: (e2e 문서 잔여 시나리오)

⛔ 의존성 없음 — PHASE 1과 병행 가능하나, 탈퇴 경로가 **HomePage.dispose 빨간 화면**(PHASE 5)을 표면화시킴(debug 전용, 흐름은 정상).

---

## PHASE 3 — 채팅 신고·차단 배포 (UGC 정책 필수)

🟦 **배포**
- [ ] `chat_report.sql` 대시보드 실행 (reports에 reported_message_id 컬럼+CHECK 확장)
      ⛔ 미실행 시 **메시지 신고만 실패**, 사용자 신고·차단은 동작.

📱 **검증** (docs/qa/chat_safety_verification.md 5종)
- [ ] 사용자 신고 → reports.reported_user_id 적재 + "신고 접수" 안내
- [ ] 메시지 신고(롱프레스) → reports.reported_message_id 적재  ⛔ chat_report.sql 실행 후
- [ ] **차단 → 기존+실시간 메시지 즉시 비표시**(앱 재시작 없이). 다른 기기로 차단 후 메시지 전송 → 미표시(Apple 1.2 핵심)
- [ ] 차단 상대 1:1 방 목록 숨김
- [ ] 차단 해제(내 정보→설정→차단 목록) → 다음 로드 시 복원

⛔ 의존성 없음(PHASE 1·2와 병행 가능).

---

## PHASE 4 — 리팩토링·기능 회귀 검증 (배포 무관, 단 분석은 PHASE 1 후)

📱 **분석 입력 화면 스모크** (Sprint2 emotion_analysis_page 1,383→696줄 리팩토링 회귀)
- [ ] 탭 전환(감정↔건강) 시 4리셋(추가입력·이미지·펼침 상태) 동작
- [ ] 이미지 추가/삭제(최대 5장), 추가정보 펼침·100자 카운터
- [ ] 수동 품종: 종류 칩 선택 시 품종 리셋, 품종 자동완성 검색, '기타' 커스텀 입력
- [ ] 가이드 시트 "다시 안 보기" + 분석 시작

📱 **분석 동작** ⛔ **PHASE 1(gemini-proxy 배포) 완료 후에만 가능**
- [ ] 감정 분석 정상 결과 / 건강 분석 정상 결과 / 일기 생성(generateText)
- [ ] 비로그인 상태 분석 시도 → "로그인이 필요합니다" 처리

📱 **건강관리 개선** (health 트랙 4f377a8..45ca8e2 — docs/qa/health_pdf_verification.md)
- [ ] 감정 트렌드: 분석 기록 0/1/2+건 상태(빈 상태·단일·추이 라인) 표시
- [ ] 건강기록 5타입 전용 입력 저장 + 카드 타입별 표시(체중 "5.2kg" 등) + 기존 빈 레코드 안 깨짐
- [ ] 체중 필터 선택 시 추이 차트 + 증감 표시
- [ ] **PDF 생성·공유 시트(iOS/Android)** — pdf/printing 네이티브 의존, 한글 정상 표시, 빈 섹션 생략

---

## PHASE 6 — 피드 탭 개선 (Q&A 정주 + 사진 그리드)

🟦 **배포 (선행 필수)**
- [ ] `supabase/migrations/posts_category.sql` 대시보드 SQL Editor 실행
      (`posts.category` 컬럼 추가 + hashtags→category 멱등 백필 + 인덱스).
      ⛔ **미실행 시 Q&A 조회·작성이 컬럼 부재로 에러.** 앱 배포 시점과 맞출 것.
- [ ] (참고) 라이브 백필 영향 0건(분류 태그 보유 글 0). 컬럼 생성만으로 동작.

📱 **검증** (docs/qa/feed_improvement_verification.md)
- [ ] 0: migration 적용 후 Q&A 조회·작성 정상(미적용 시 에러 재현 확인)
- [ ] 1: Q&A 무한 스크롤(30건 경계 다음 페이지 로드·중복 없음)
- [ ] 2: 상태 보존(사진↔Q&A 토글 시 목록·스크롤 유지)
- [ ] 3: 카테고리 필터(category 컬럼 기준, 화면 건수=DB 건수) + 칩 컬러
- [ ] 4: post_type 오염 차단(사진 글이 Q&A에 비노출)
- [ ] 5: 빈 상태 CTA("첫 글 쓰기"→작성→즉시 반영)
- [ ] 6: 매거진 노출('전체' 상단 가로 슬라이더, 0건 시 미노출, 더보기→/hashtag/magazine)
- [ ] 7: 사진 그리드 토글(3열 정사각·이미지 글만·셀 탭 상세)
- [ ] 8: **리스트 뷰 무변경 회귀**(무한스크롤·새로고침·좋아요·에러·빈상태 동일)
- [ ] 9: 그리드 무한스크롤(원본 posts 기준 로드) / 사진 0건 시 "리스트로 보기"

⛔ migration 적용이 Q&A 동작 선행조건. 사진 그리드(7~9)는 DB 무관(즉시 검증 가능).

---

## PHASE 5 — 알려진 버그 (홈 트랙, 출시 차단 아님)
- [ ] **HomePage.dispose 빨간 화면**(home_page.dart:96, debug 전용 assertion). 수정안: `didChangeDependencies()`에서 `_router=GoRouter.of(context)` 캡처 → `dispose()`에서 context 조회 제거. (home_page.dart는 그간 금지 파일이라 미수정 — 홈 트랙에서 처리)

---

## 트랙별 커밋 추적 (원격 win-android-release)
| 트랙 | 커밋 범위 | 검증 문서 |
|------|-----------|-----------|
| Sprint 1 soft delete | 4af2a91..c52e0bb | account_soft_delete_e2e.md |
| Sprint 2 리팩토링 | b2c82db..5c8eb87 | (PHASE 4 스모크) |
| Gemini 프록시 | 8ca475b..f67d37c | gemini_proxy_verification.md |
| 채팅 안전장치 | c13c5f5..53d5645 | chat_safety_verification.md |
| 건강관리 개선 | 4f377a8..45ca8e2 | health_pdf_verification.md |
| 피드 탭 개선 | cac3591..74c7025 | feed_improvement_verification.md |

## 핵심 의존성 요약
1. **gemini-proxy 배포 + 키 교체 → 그 다음에 분석 동작 검증**(PHASE 1 → PHASE 4 분석).
2. soft delete: migration → Edge Function → 시크릿 → cron **순서 엄수**(PHASE 2).
3. chat_report.sql 실행 → 그 다음 메시지 신고 검증(PHASE 3).
4. 탈퇴 경로 작동 시 HomePage.dispose 빨간 화면 표면화(debug만, 무시 가능 — PHASE 5).
5. **posts_category.sql 실행 → 그 다음 Q&A 조회·작성 가능**(PHASE 6). 미실행 시 Q&A 에러.
