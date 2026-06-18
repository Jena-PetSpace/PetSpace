# PRD — 펫페이스 (Pet Space)

> 현재 코드(`win-android-release`) 기준 현행 PRD · 기준 2026-06-18 (Sprint 2 완료)
> 초기 기획문서(`PetSpace+document*.md`)를 대체. 초기본은 `archive/planning/`로 이관.

---

## 1. 문서 개요

초기 PRD는 "인증·감정분석·소셜·고도화" 4단계였으나, 실제 앱은 **15개 도메인·70개 화면·64개 라우트**로 확장되었다. 본 문서는 구현된 앱을 있는 그대로 기술하여 클로드 디자인(Claude Design) UI 개선의 입력 자료로 쓴다.

> **도메인 카운트 정의**: 원격 레포 `features/` 기준 **구현 도메인 15개**(auth·chat·emotion·feed_hub·fortune·health·home·mbti·my·news·onboarding·pets·profile·quiz·social). `diary`는 원격 미추적 빈 폴더(로컬 잔재)라 카운트 제외. CLAUDE.md가 12개로 적은 것은 부가기능(fortune·mbti·news·quiz) 누락이므로 별도 수정 필요.

**초기 기획 대비 변경**

| 구분 | 초기 기획 | 현재 코드 |
|---|---|---|
| 기능 도메인 | 4단계 | 15개 도메인 |
| 화면 수 | STEP 중심(미정의) | 70개 page |
| 하단 탭 | 미확정 | 5탭 고정 |
| 신규 기능 | 없음 | MBTI·운세·O/X 퀴즈·펫 뉴스·리워드·퀘스트·펫 여권 |
| 홈 화면 | 카드 그리드 | **매거진/핫이슈형으로 리디자인 진행 중**(아래 4.2) |

---

## 2. 프로젝트 개요

### 2.1 정의
WHO 헬스케어 3요소(정신·신체·사회)를 통합한 **반려동물 건강 통합 분석 및 조기 진단 AI 솔루션**.

### 2.2 가치 제안
- **정신**: 다중 스케일 딥러닝 감정 분류 (특허 출원 10-2025-0199307)
- **신체**: XAI 기반 피부질환 진단 + 건강 기록·트렌드 (특허 출원 10-2025-0199356)
- **사회**: 반려인 커뮤니티(피드·Q&A·채팅)
- **차별점**: 3요소 통합 진단(경쟁사는 단일 영역)

### 2.3 기술 스택
Flutter + Clean Architecture + BLoC + GetIt + GoRouter / Supabase(PostgreSQL·Auth·Storage·Realtime) / Firebase FCM / Google Gemini API(프록시) / Kakao Maps / 온디바이스 TFLite

> 시장 규모·특허·수상이력 등 공식 수치는 IR 원본 기준 인용. 본 문서에서 추정하지 않음.

---

## 3. 사용자 페르소나

| 페르소나 | 특징 | 핵심 니즈 | 주 사용 기능 |
|---|---|---|---|
| 초보 반려인 | 반려 1년 미만, 불안 | 이상행동·건강 빠른 확인 | AI분석·건강관리·Q&A |
| 베테랑 반려인 | 다견/다묘, 기록 습관 | 추이 관리·정보 공유 | 건강 트렌드·피드·채팅 |
| 정보 탐색형 | 관찰·입양 검토 | 가벼운 재미·정보 | MBTI·운세·퀴즈·뉴스 |

---

## 4. 기능 명세 (도메인별)

### 4.1 온보딩 / 인증 (onboarding 9 + auth 6)
- 진입 `/splash` → 인증 상태 분기(GoRouter redirect)
- 흐름: `/onboarding` → `slides` → `login` → `email-verification` 또는 `kakao-consent`(`/oauth` 콜백) → `terms` → `profile` → `pet-registration` → `tutorial` → `complete` → `/home`
- 부가: 비밀번호 재설정 3단계, 약관 상세
- 보안: Kakao 패스워드 SHA-256 해싱
- **미구현**: Sign in with Apple (iOS 출시 P0)

### 4.2 홈 (home/social·탭1) — ⚠️ 리디자인 진행 중
- 라우트 `/home`
- **현재 상태**: 코드 주석상 홈은 **매거진/핫이슈형 시안으로 전환 중**. 상단에 핫이슈 카드·매거진 섹션·카테고리 콘텐츠가 신규 배치되고, 기존 카드(MBTI·운세·퀴즈·퀘스트)는 "시안엔 없던 기존 카드 — 위치 확인용으로 스크롤 하단 임시 배치" 상태.
- → **클로드 디자인 1순위 후보**: 시안과 레거시 카드가 공존하는 과도기라 정리 필요.
- 부속: 병원 검색 `/hospital`(Kakao Maps)

### 4.3 건강관리 (health 2 + emotion 일부)
- 라우트 `/health`, `/health/result`, `/health/alert-settings`
- 건강 기록 **5종**: `vaccination`(접종)·`checkup`(검진)·`weight`(체중)·`medication`(투약)·`surgery`(수술). 상태 4종: `scheduled`·`completed`·`overdue`·`cancelled`
- 기능: 피부질환 AI 진단(XAI Grad-CAM), 필터 칩, 다가오는 알림(upcoming alerts), 체중·감정 트렌드 차트, **PDF 건강 요약서**(온디바이스, Pretendard 임베드)
- 빈 상태 분기: 펫 미등록 / 기록 없음 / 에러 별도 처리

### 4.4 AI 감정분석 (emotion 11·탭3)
- 라우트 `/emotion`, `/emotion/loading`, `/emotion/result-direct`, `result/:analysisId`, `/emotion/weekly-report`, `/emotion-timeline`, `/history`, `/ai-history-page`, `/share/emotion/:analysisId`
- 감정 **9종**: happiness·sadness·anxiety·curiosity·calm·excitement·fear·discomfort + sleepiness(deprecated)
- 데이터: `EmotionAnalysis`(confidence·contextNote·tags·memo·FacialFeature[state/signal])
- 흐름: 이미지 → guide → loading(풀스크린) → 결과(리디자인 v2) → 공유/히스토리/타임라인/주간리포트
- 모델: Multi-scale EfficientNetB3, 평균 96.17%
- **UI 원칙**: confidence는 DB 보존·화면 비노출

### 4.5 피드 / 커뮤니티 (feed_hub 2 + social 14·탭4)
- 라우트 `/feed`(허브), `/explore`, `/search`, `/create-post`, `/post/:postId`, `/hashtag/:tag`, `/location`, `/notifications`, `/user-profile/:userId`, `/followers/:uid`, `/following/:uid`, `/channels`
- **상태 분리 설계**: 사진 피드 `FeedBloc` ↔ Q&A `CommunityCubit` 별도 운영(Q&A는 피드와 성격이 달라 흡수하지 않음)
- 안전: 신고 2종·차단·실시간 스트림 동적 필터·방 숨김
- 페이지네이션: 키셋 방식

### 4.6 채팅 (chat 4)
- 라우트 `/chat`, `/chat/new`, `/chat/:roomId`, `/chat/:roomId/settings`
- 실시간(Supabase Realtime), 배지(`chat_badge_bloc`), 신고·차단 연동

### 4.7 MY / 프로필 / 펫 (my 6 + profile 6 + pets 3·탭5)
- 라우트 `/my`(+`posts`/`saved`/`edit-profile`), `/settings/{my,notification,privacy,help}`, `/pets`, `/pet/public/:petId`, `/reward`
- 기능: 통계, 내 글·저장글, 프로필 편집, 설정 4종, 반려동물 관리·상세·공개 프로필, 리워드 상점
- **펫 여권**: `Pet`에 passportNo·surname·givenName·nameHanguel·countryCode·currentMbtiType 필드 존재

### 4.8 부가 (mbti 2 / fortune 1 / quiz 2 / news 1)
- MBTI: `/mbti` → `/mbti/result` (16유형×3종, content_version 관리, Supabase DB)
- 운세: `/fortune` (로컬·결정적)
- 퀴즈: `/quiz/play` → `/quiz/result` (O/X 270문항)
- 뉴스: `/news` (반자동 수집 Edge Function + cron, 최신순)

---

## 5. 정보 구조 (IA)

```
[하단 5탭]
 ├─ 홈 /home        (⚠️ 매거진형 리디자인 진행 중)
 ├─ 건강관리 /health
 ├─ AI분석 /emotion  (네비바 중앙 FAB 강조)
 ├─ 피드 /feed
 └─ MY /my
[탭 밖 풀스크린] 온보딩·인증·로딩·결과·채팅·상세·설정·부가기능
```

---

## 6. 성공 지표 (제안)
- 활성화: 온보딩 완료율, 펫 등록률
- 핵심 가치: AI 분석 실행/주, 건강 기록 지속률, PDF 생성 수
- 사회: 게시물·댓글·채팅 활성 사용자
- 리텐션: D1/D7/D30, 탭별 재방문

---

## 7. 출시 리스크 (디자인과 별개 트랙)
- Gemini proxy Edge Function 배포·키 재발급
- iOS: `meong_nyang_diary` 잔존 정리, Sign in with Apple, APNs 업로드, App Store Connect 등록, TestFlight
- Android: `usesCleartextTraffic` 보안, `user_blocks` 테이블
- 인프라: `user_points`·`user_quests`·`user_badges`·`pet_follows` 테이블, Storage RLS, FCM Edge Function
- 퀘스트 카드(`HomeQuestCard`)는 현재 **로컬 SharedPreferences(`quest_{id}_{today}`) + MbtiRepository 기반**으로 동작 — `user_quests` 테이블 미연동. (검증: home_quest_card.dart:110,135-179)
- `features/diary/`는 **원격 레포 미추적(빈 폴더), 로컬 작업트리에만 남은 잔재** → 로컬 `rmdir`로 정리(커밋 불필요)
