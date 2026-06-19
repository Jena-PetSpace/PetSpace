# USER FLOW — 펫페이스

> 현재 코드(`win-android-release`) 라우팅 기준 · 기준 2026-06-18
> 근거: `app_router.dart`(64 라우트) / `main_navigation.dart`(5탭) / 70 page
> 용도: 클로드 디자인 입력 + UI 비교 기준

---

## 1. 전역 진입 / 인증 가드

GoRouter `redirect`가 `AuthBloc.state`로 분기:
```
앱 실행 → /splash
  AuthInitial   → /splash 유지
  AuthLoading   → 로딩
  미인증        → /onboarding/login
  Kakao 콜백    → /onboarding/login (재처리)
  인증됨        → /home
```
`refreshListenable: AuthBloc.stream` — 상태 변화 시 자동 리다이렉트.

---

## 2. 온보딩 / 인증

```
/onboarding → /onboarding/slides → /onboarding/login
   ├─ 이메일 → /onboarding/email-verification
   └─ 카카오 → /onboarding/kakao-consent → (/oauth)
→ /onboarding/terms (상세: terms-detail)
→ /onboarding/profile
→ /onboarding/pet-registration   (펫 여권 필드 포함)
→ /onboarding/tutorial
→ /onboarding/complete → /home

[비번 재설정] /auth/password-reset/request → verify → new-password → login
```
미구현: Sign in with Apple.

---

## 3. 메인 탭 (ShellRoute, 네비바 유지)

| 탭 | 라우트 | 아이콘 | 화면 |
|---|---|---|---|
| 홈 | `/home` | cottage | HomePage (⚠️ 매거진 리디자인 중) |
| 건강관리 | `/health` | monitor_heart | HealthMainPage |
| AI분석 | `/emotion` | psychology | (중앙 FAB 강조) |
| 피드 | `/feed` | photo_library | FeedHubPage |
| MY | `/my` | pets | MyPage |

---

## 4. 홈 플로우 (현재 과도기)

```
/home
  [신규 시안] 핫이슈 카드 · 매거진 섹션 · 카테고리 콘텐츠
  [레거시·임시 하단] MBTI → /mbti → /mbti/result
                    운세 → /fortune
                    퀴즈 → /quiz/play → /quiz/result
                    퀘스트(HomeQuestCard, user_quests 의존)
  병원 → /hospital
  뉴스 → /news
  펫 여권 → /pets, /pet/public/:petId
  AI분석 → /emotion
```
> 시안과 레거시 카드가 공존 → 클로드 디자인으로 정리할 1순위.

---

## 5. AI 감정분석 (핵심)

```
/emotion → 이미지 선택 + analysis-guide
  → /emotion/loading (풀스크린, rootNavigator)
  → 결과: /emotion/result-direct  또는  result/:analysisId (loader)
  → 결과 화면(리디자인 v2, contextNote)
       ├─ 공유 → /share/emotion/:analysisId
       ├─ 히스토리 → /history, /ai-history-page
       ├─ 타임라인 → /emotion-timeline
       └─ 주간 리포트 → /emotion/weekly-report
```

---

## 6. 건강관리

```
/health (HealthMainPage)
  ├─ 건강 기록 추가 (5종: 접종·검진·체중·투약·수술)
  ├─ 필터 칩 / 다가오는 알림
  ├─ 피부질환 AI 진단 → health/loading → /health/result
  ├─ 체중·감정 트렌드 차트
  ├─ PDF 건강 요약서 (온디바이스)
  └─ /health/alert-settings
  [빈 상태] 펫 미등록 / 기록 없음 / 에러 분기
```

---

## 7. 피드 / 커뮤니티

```
/feed (FeedHubPage)
  사진 피드(FeedBloc) ↔ Q&A(CommunityCubit) 분리
  ├─ 작성 → /create-post | create-community-post
  ├─ 상세 → /post/:postId → comments
  ├─ 탐색 → /explore   검색 → /search
  ├─ 해시태그 → /hashtag/:tag   위치 → /location → location-posts
  ├─ 채널 → /channels   알림 → /notifications
  └─ 프로필 → /user-profile/:id → followers/:uid, following/:uid
  [안전] 신고 2종 → 차단 → 실시간 필터 / 방 숨김
```

---

## 8. 채팅

```
/chat → /chat/new (생성)
      → /chat/:roomId (실시간) → /chat/:roomId/settings (신고·차단·나가기)
```

---

## 9. MY 탭

```
/my (통계)
  ├─ /my/posts · /my/saved · /my/edit-profile
  ├─ /pets → pet-detail · /pet/public/:petId
  ├─ /reward
  └─ /settings/{my, notification, privacy, help}
  부속: community-guidelines · privacy-policy
```

---

## 10. 화면 인벤토리 (클로드 디자인 비교 체크리스트)

> "현재 → 개선안" 비교 표의 행. 우선순위는 제안값(사용 빈도·첫인상·핵심 가치).
>
> **수 체계 주의 (축이 다름)**: `app_router.dart`의 GoRoute 선언 = **64개**(이 중 redirect-only 2개: `/oauth`→login, `/emotion/history`→ai-history → 실제 페이지 빌드 **62개**). 아래 화면 인벤토리 = **66행**(화면 단위). 라우트 없는 화면 9개는 라우트칸 `-` 표시: terms-detail·analysis-guide·health-loading·emotion-trend·create-community-post·feed·comments·my-emotion-history·pet-detail. **64 ≠ 66은 정상**(라우트 축 vs 화면 축).

| # | 도메인 | 화면 | 라우트 | 우선순위 |
|---|---|---|---|---|
| 1 | onboarding | splash | /splash | - |
| 2 | onboarding | onboarding | /onboarding | 중 |
| 3 | onboarding | slides | /onboarding/slides | 중 |
| 4 | onboarding | login | /onboarding/login | 상 |
| 5 | onboarding | email-verification | /onboarding/email-verification | 중 |
| 6 | onboarding | kakao-consent | /onboarding/kakao-consent | 하 |
| 7 | onboarding | terms | /onboarding/terms | 하 |
| 8 | onboarding | profile-setup | /onboarding/profile | 중 |
| 9 | onboarding | pet-registration | /onboarding/pet-registration | 상 |
| 10 | onboarding | tutorial | /onboarding/tutorial | 중 |
| 11 | onboarding | complete | /onboarding/complete | 중 |
| 12 | auth | password-reset (3) | /auth/password-reset/* | 하 |
| 13 | auth | terms-detail | - | 하 |
| 14 | home | home | /home | **최상** |
| 15 | home | hospital-search | /hospital | 중 |
| 16 | health | health-main | /health | 상 |
| 17 | health | health-result | /health/result | 상 |
| 18 | health | alert-settings | /health/alert-settings | 하 |
| 19 | emotion | emotion-analysis | /emotion | 상 |
| 20 | emotion | analysis-guide | - | 중 |
| 21 | emotion | emotion-loading | /emotion/loading | 중 |
| 22 | emotion | emotion-result | result/:id | 상 |
| 23 | emotion | health-loading/result | - | 중 |
| 24 | emotion | weekly-report | /emotion/weekly-report | 중 |
| 25 | emotion | emotion-timeline | /emotion-timeline | 중 |
| 26 | emotion | emotion-trend | - | 중 |
| 27 | emotion | ai-history | /ai-history-page | 중 |
| 28 | feed_hub | feed-hub | /feed | 상 |
| 29 | feed_hub | create-community-post | - | 중 |
| 30 | social | feed | - | 상 |
| 31 | social | post-detail | /post/:postId | 상 |
| 32 | social | comments | - | 중 |
| 33 | social | create-post | /create-post | 중 |
| 34 | social | explore | /explore | 중 |
| 35 | social | search | /search | 중 |
| 36 | social | hashtag | /hashtag/:tag | 하 |
| 37 | social | location-picker/posts | /location | 중 |
| 38 | social | profile | /user-profile/:id | 상 |
| 39 | social | followers/following | /followers/:uid | 하 |
| 40 | social | notifications | /notifications | 중 |
| 41 | social | channel-subscription | /channels | 하 |
| 42 | chat | chat-rooms | /chat | 상 |
| 43 | chat | create-chat | /chat/new | 중 |
| 44 | chat | chat-detail | /chat/:roomId | 상 |
| 45 | chat | chat-room-settings | /chat/:roomId/settings | 하 |
| 46 | my | my | /my | 상 |
| 47 | my | my-posts | /my/posts | 중 |
| 48 | my | my-saved-posts | /my/saved | 중 |
| 49 | my | my-emotion-history | - | 중 |
| 50 | my | my-settings | /settings/my | 하 |
| 51 | my | reward-store | /reward | 중 |
| 52 | profile | profile-edit | /my/edit-profile | 중 |
| 53 | profile | notification-settings | /settings/notification | 하 |
| 54 | profile | privacy-settings | /settings/privacy | 하 |
| 55 | profile | help | /settings/help | 하 |
| 56 | profile | privacy-policy | /privacy | 하 |
| 57 | profile | community-guidelines | /community-guidelines | 하 |
| 58 | pets | pet-management | /pets | 중 |
| 59 | pets | pet-detail | - | 중 |
| 60 | pets | public-pet | /pet/public/:petId | 중 |
| 61 | mbti | mbti-test | /mbti | 중 |
| 62 | mbti | mbti-result | /mbti/result | 중 |
| 63 | fortune | fortune-detail | /fortune | 중 |
| 64 | quiz | quiz-play | /quiz/play | 중 |
| 65 | quiz | quiz-result | /quiz/result | 중 |
| 66 | news | news-list | /news | 중 |
