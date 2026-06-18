# PetSpace 작업지시서 — P0~P3 전체

> **작성일:** 2026-05-07  
> **기준 브랜치:** win-android-release  
> **진행 원칙:** 한 번에 하나씩, 완료 확인 후 다음 진행

---

## 진행 상태 대시보드

| ID | 우선순위 | 작업명 | 담당 | 상태 |
|----|---------|--------|------|------|
| P0-A | P0 | secrets.dart → dart-define 환경변수 이전 | Claude | ⬜ 대기 |
| P0-B | P0 | MeongNyangDiaryApp 클래스명 PetSpaceApp으로 변경 | Claude | ⬜ 대기 |
| P0-C | P0 | petspace.app/privacy 개인정보처리방침 페이지 생성 | 직접 | ⬜ 대기 |
| P0-D | P0 | petspace.app/terms 이용약관 페이지 생성 | 직접 | ⬜ 대기 |
| P0-E | P0 | Play Console Data Safety 폼 작성 가이드 | 직접 | ⬜ 대기 |
| P0-F | P0 | App Store Privacy Nutrition Label 작성 가이드 | 직접 | ⬜ 대기 |
| P0-G | P0 | Closed Testing 12명 모집 가이드 문서화 | 직접 | ⬜ 대기 |
| P0-H | P0 | 심사관용 테스트 계정 + 샘플 콘텐츠 준비 | 직접 | ⬜ 대기 |
| P0-I | P0 | PremiumGateWidget 실제 결제 플로우 확인 및 정리 | Claude | ⬜ 대기 |
| P0-J | P0 | Supabase RLS 전 테이블 활성화 체크리스트 | 직접 | ⬜ 대기 |
| P1-A | P1 | 온보딩 펫 등록 "나중에" 선택지 추가 | Claude | ⬜ 대기 |
| P1-B | P1 | AI 감정분석 결과 화면 — 케어 액션 추천 카드 추가 | Claude | ⬜ 대기 |
| P1-C | P1 | AI 감정분석 결과 화면 — Lottie 감성 애니메이션 추가 | Claude | ⬜ 대기 |
| P1-D | P1 | my_page.dart limit:100 → LazyLoadList 무한스크롤 전환 | Claude | ⬜ 대기 |
| P1-E | P1 | gemini_ai_service.dart 임시 처리 정리 | Claude | ⬜ 대기 |
| P1-F | P1 | NetworkErrorBanner hardcoded 색상 → 테마 토큰 교체 | Claude | ⬜ 대기 |
| P2-A | P2 | injection_container.dart feature별 모듈 분리 | Claude | ⬜ 대기 |
| P2-B | P2 | social_remote_data_source.dart 도메인별 분리 | Claude | ⬜ 대기 |
| P2-C | P2 | 접근성 Semantics + semanticLabel 전체 적용 | Claude | ⬜ 대기 |
| P2-D | P2 | 다크모드 hardcoded Color 전수 조사 + 테마 토큰 교체 | Claude | ⬜ 대기 |
| P2-E | P2 | hospital_search_page.dart 로직/UI 분리 | Claude | ⬜ 대기 |
| P2-F | P2 | post_card.dart 997줄 서브 위젯 분리 | Claude | ⬜ 대기 |
| P2-G | P2 | 알림 배치 처리 (좋아요 묶음 알림) | Claude | ⬜ 대기 |
| P2-H | P2 | 홈 화면 정보 밀도 재설계 | Claude | ⬜ 대기 |
| P3-A | P3 | 반려동물 성장 앨범 (월별 자동 콜라주) | Claude | ⬜ 대기 |
| P3-B | P3 | AI 분석 → 오늘의 케어 루틴 추천 고도화 | Claude | ⬜ 대기 |
| P3-C | P3 | 반려동물 생일/입양일 기념 알림 | Claude | ⬜ 대기 |
| P3-D | P3 | 유사 반려동물 사용자 추천 (품종 기반) | Claude | ⬜ 대기 |

---

## P0 — 출시 전 필수 (심사 통과 차단 항목)

---

### P0-A: secrets.dart → dart-define 환경변수 이전

**우선순위:** 🔴 Critical  
**예상 시간:** 2시간  
**담당:** Claude  
**영향 파일:**
- `lib/config/secrets.dart` (삭제)
- `lib/config/api_config.dart` (수정)
- `.env.json` (신규 생성, .gitignore에 추가)
- `android/app/build.gradle.kts` (수정)
- `.github/workflows/ci.yml` (수정)

**현재 문제:**  
`lib/config/secrets.dart`에 아래 민감 정보가 평문으로 저장됨:
- Gemini API Key (라인 11)
- Supabase URL + Anon Key (라인 15-16)
- Kakao App Key, JS Key, REST API Key (라인 27, 30, 34)
- Google Client IDs (라인 23-26)
- Firebase API Key, App ID 등 (라인 37-41)

**작업 단계:**

1. `.env.json` 파일 생성 (git root 레벨, `.gitignore`에 이미 등록 확인)
2. `secrets.dart`의 모든 값을 `.env.json`으로 이전
3. `lib/config/secrets.dart`를 `--dart-define` 읽기 방식으로 교체
4. `android/app/build.gradle.kts`에 `dart-define` 전달 설정 추가
5. `.github/workflows/ci.yml` GitHub Secrets 기반 빌드 수정
6. `flutter analyze` 통과 확인
7. `flutter build apk --debug` 빌드 테스트

**완료 기준:**
- `secrets.dart`에 실제 키값 없음 (String.fromEnvironment만 남음)
- `.env.json`이 `.gitignore`에 포함됨
- `flutter analyze` 0 errors

---

### P0-B: MeongNyangDiaryApp 클래스명 변경

**우선순위:** 🔴 Critical  
**예상 시간:** 30분  
**담당:** Claude  
**영향 파일:**
- `lib/main.dart` (라인 169, 174, 176, 263)

**현재 문제:**  
`lib/main.dart:169`에 `MeongNyangDiaryApp`이라는 구 브랜드명 클래스가 남아있음.  
Phase 1에서 `app_config.dart`의 URL/문자열은 교체했으나 클래스명 자체는 미수정.

**작업 단계:**

1. `main.dart`에서 `MeongNyangDiaryApp` → `PetSpaceApp` 전체 치환
2. `_MeongNyangDiaryAppState` → `_PetSpaceAppState` 전체 치환
3. `flutter analyze` 통과 확인

**완료 기준:**
- `MeongNyangDiary` 문자열이 전체 코드베이스에서 0건

---

### P0-C: 개인정보처리방침 페이지 생성

**우선순위:** 🔴 Critical  
**예상 시간:** 2-3시간  
**담당:** 직접 (Claude 보조 — 한국어 초안 작성)  
**URL:** `https://petspace.app/privacy`

**현재 문제:**  
`app_config.dart:74`에 `privacyPolicyUrl = 'https://petspace.app/privacy'`가 등록되어 있으나 실제 페이지가 없음. 양대 마켓 심사에서 필수 확인 항목. 페이지 미존재 시 반려 확정.

**포함해야 할 내용:**

```
1. 수집하는 개인정보 항목
   - 이름, 이메일, 사용자 ID
   - 사진 (AI 감정분석용)
   - 위치 정보 (병원 검색용)
   - 기기 ID (FCM 알림용)
   - 앱 사용 이력

2. 개인정보 수집 목적
3. 개인정보 보유 및 이용 기간
4. 개인정보 제3자 제공
5. 개인정보 처리 위탁
6. 사용자 권리 (열람, 수정, 삭제)
7. 개인정보 파기 절차
8. 14세 미만 아동 개인정보 수집 금지
9. 개인정보 보호 담당자 연락처 (support@petspace.app)
10. 시행일자
```

**구현 방법 선택지:**
- A. Notion 페이지 → 공개 링크 → `privacyPolicyUrl` 업데이트 (빠름, 권장)
- B. GitHub Pages Markdown (별도 repo 필요)
- C. `petspace.app` 도메인에 정적 HTML 업로드

**Claude 제공 사항:** 한국어 개인정보처리방침 초안 텍스트 작성

---

### P0-D: 이용약관 페이지 생성

**우선순위:** 🔴 Critical  
**예상 시간:** 2-3시간  
**담당:** 직접 (Claude 보조)  
**URL:** `https://petspace.app/terms`

**포함해야 할 내용:**

```
1. 서비스 이용약관 동의
2. 서비스 이용 자격 (14세 이상)
3. 계정 관리 책임
4. 금지 행위 (타인 비방, 불법 콘텐츠 등)
5. 콘텐츠 소유권 및 라이선스
6. UGC (사용자 생성 콘텐츠) 정책
7. 서비스 변경 및 종료
8. 면책 조항
9. 분쟁 해결 (대한민국 법률 적용)
10. 연락처
```

---

### P0-E: Play Console Data Safety 폼 작성

**우선순위:** 🔴 Critical  
**예상 시간:** 1시간  
**담당:** 직접  
**위치:** Play Console → 앱 콘텐츠 → 데이터 보안

**입력 항목 전체:**

```
[개인 정보]
✅ 이름 — 수집함 — 앱 기능 (계정 관리) — 암호화 전송 — 삭제 가능
✅ 이메일 주소 — 수집함 — 앱 기능 (계정 관리) — 암호화 전송 — 삭제 가능
✅ 사용자 ID — 수집함 — 앱 기능 — 암호화 전송

[사진 및 동영상]
✅ 사진 — 수집함 — 앱 기능 (AI 감정분석) — 암호화 전송 — 삭제 가능

[위치 정보]
✅ 대략적인 위치 — 수집함 — 앱 기능 (병원 검색)
✅ 정확한 위치 — 수집함 — 앱 기능 (병원 검색)

[앱 활동]
✅ 앱 상호작용 — 수집함 — 분석
✅ 기타 사용자 생성 콘텐츠 — 수집함 — 앱 기능

[기기 또는 기타 ID]
✅ 기기 또는 기타 ID — 수집함 — 앱 기능 (푸시 알림)

[보안 방침]
✅ 전송 중 데이터 암호화 (TLS/HTTPS)
✅ 사용자가 데이터 삭제 요청 가능
```

**권한 사용 사유 등록 (Play Console → 앱 콘텐츠 → 권한):**

```
ACCESS_FINE_LOCATION:
"주변 동물병원과 펫 용품 매장을 검색하기 위해 사용됩니다. 
사용자 위치 기반으로 가까운 시설을 우선 표시합니다."

CAMERA:
"반려동물 사진 촬영을 통해 AI 감정 분석을 수행합니다.
촬영된 사진은 사용자 동의 하에만 서버로 전송됩니다."

POST_NOTIFICATIONS:
"좋아요, 댓글, 팔로우 등 소셜 활동 알림과
예방접종, 검진 D-day 등 건강 관리 알림 전송에 사용됩니다."

READ_MEDIA_IMAGES:
"갤러리에서 반려동물 사진을 선택하여
AI 감정 분석을 진행하기 위해 사용됩니다."
```

---

### P0-F: App Store Privacy Nutrition Label 작성

**우선순위:** 🔴 Critical  
**예상 시간:** 1시간  
**담당:** 직접  
**위치:** App Store Connect → 앱 개인정보 보호

**입력 항목:**

```
[사용자와 연결된 데이터]
- 연락처 정보: 이메일 주소 (계정 관리)
- 식별자: 사용자 ID (앱 기능), 기기 ID (앱 기능)
- 사진 또는 비디오: 사진 (앱 기능 — AI 분석)
- 위치: 정확한 위치 (앱 기능 — 병원 검색)
- 사용자 콘텐츠: 기타 사용자 콘텐츠 (앱 기능)

[사용자와 연결되지 않은 데이터]
- 사용 데이터: 앱 상호작용 (분석)
- 진단: 충돌 데이터 (앱 기능 — Crashlytics)
```

---

### P0-G: Closed Testing 12명 모집 가이드

**우선순위:** 🔴 Critical  
**예상 시간:** 30분 설정 + 2주 운영  
**담당:** 직접

**STEP 1: Play Console 테스트 트랙 설정**
```
Play Console → 테스트 → 비공개 테스트
→ 새 트랙: "베타 테스터"
→ AAB 업로드
→ 출시
```

**STEP 2: 테스터 등록 (12명 필수)**
```
방법 A — 이메일 직접 등록:
Play Console → 테스터 탭 → 이메일 목록에 12개 Google 계정 이메일 추가

방법 B — Google 그룹:
groups.google.com에서 petspace-beta 그룹 생성
→ 12명 초대
→ Play Console에 그룹 이메일 등록
```

**STEP 3: 모집 메시지 (카카오톡용)**
```
안녕하세요! 
펫스페이스(PetSpace) 베타 테스터를 모집합니다 🐾

[모집 인원] Android 사용자 12명
[기간] 2주 (설치 후 자유롭게 사용)
[보상] 정식 출시 시 첫 100명 "베타 테스터" 뱃지 + 리워드 포인트 10,000P

[신청 방법]
구글 계정 이메일을 이 메시지에 댓글로 남겨주세요!
(Play Store 설치에 사용하는 Gmail 주소)

[할 일]
- 앱 자유롭게 사용 (하루 5분 이상)
- 버그/불편한 점 있으면 알려주기

감사합니다 🙏
```

**완료 기준:**
- 14일 경과 + 테스터 12명 이상 설치 확인 (Play Console Statistics에서 확인)

---

### P0-H: 심사관용 테스트 계정 준비

**우선순위:** 🔴 Critical  
**예상 시간:** 1시간  
**담당:** 직접

**생성할 계정:**
```
이메일: review@petspace.app (또는 기존 Gmail)
비밀번호: [안전한 비밀번호 설정]
```

**샘플 콘텐츠 입력 (심사관 계정으로 로그인 후):**
```
1. 반려동물 1마리 이상 등록 (이름/사진/품종)
2. 피드 게시글 3개 이상 작성 (사진 포함)
3. AI 감정분석 1회 이상 실행
4. 다른 테스트 계정의 게시글에 댓글/좋아요
```

**App Review Notes 작성 (App Store Connect):**
```
테스트 계정 정보:
이메일: review@petspace.app
비밀번호: [비밀번호]

앱 기능 안내:
- 카카오 로그인은 한국 계정만 사용 가능합니다
- 반려동물 사진으로 AI 감정 분석 기능 체험 가능
- 주변 동물병원 검색은 실제 위치 권한이 필요합니다
- 테스트 피드에 샘플 콘텐츠가 등록되어 있습니다
```

---

### P0-I: PremiumGateWidget 결제 플로우 정리

**우선순위:** 🔴 Critical  
**예상 시간:** 1시간  
**담당:** Claude  
**영향 파일:**
- `lib/shared/widgets/premium_gate_widget.dart`

**현재 상태:**  
`premium_gate_widget.dart`에 "월 3,900원", "7일 무료 체험" 텍스트와 UI가 구현되어 있으나, 실제 결제 플로우(IAP) 연동 없이 바텀시트만 표시됨.

**Apple 정책:** 앱 내 유료 기능은 Apple IAP로만 결제 처리 필요.  
**현재 위험:** 결제 UI가 있지만 실제 결제 없으면 "기능 불완전" 또는 IAP 우회로 반려 가능.

**옵션 선택 필요 (확인 요망):**
- A. v1.0에서 PremiumGate 완전 제거 → 모든 기능 무료로 출시
- B. IAP 연동 구현 후 출시 (추가 1-2주 작업)

**권장: 옵션 A** — v1.0은 전체 무료, v1.1에서 구독 모델 도입

---

### P0-J: Supabase RLS 체크리스트

**우선순위:** 🔴 Critical  
**예상 시간:** 1시간  
**담당:** 직접  
**위치:** Supabase Dashboard → Table Editor → 각 테이블 → RLS

**확인할 테이블 목록:**

```
✅/❌ users          — RLS 활성화 여부 + 정책 확인
✅/❌ pets           — 본인 pet만 수정 가능한지
✅/❌ emotion_analyses — 본인 분석만 조회/수정 가능한지
✅/❌ social_posts   — 공개 글 조회 O, 수정은 본인만
✅/❌ post_likes     — 본인 좋아요만 추가/삭제
✅/❌ post_comments  — 공개 조회 O, 수정은 본인만
✅/❌ user_blocks    — 본인 차단 목록만 조회/수정
✅/❌ user_devices   — 본인 기기만 조회/수정 (FCM 토큰)
✅/❌ notifications  — 수신자만 조회 가능
✅/❌ chat_rooms     — 참여자만 조회/수정
✅/❌ chat_messages  — 참여자만 조회/수정
✅/❌ health_records — 본인 건강 기록만
```

**필수 정책 패턴:**
```sql
-- users 테이블 예시
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"  
ON users FOR UPDATE
USING (auth.uid() = id);
```

---

## P1 — 출시 전 권장 (이탈률/반려 위험)

---

### P1-A: 온보딩 펫 등록 "나중에" 선택지 추가

**우선순위:** ⚠️ High  
**예상 시간:** 2시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `lib/features/onboarding/presentation/bloc/onboarding_bloc.dart`
- `lib/core/navigation/app_router.dart`

**현재 문제:**  
`onboarding_pet_registration_page.dart:822`에 `_skip()` 메서드가 이미 존재하나, UI에서 사용자가 찾기 어렵거나 CTA가 약함. 펫 등록 없이는 앱 핵심 기능 체험 불가 구조.

**작업 단계:**

1. AppBar에 "건너뛰기" 텍스트 버튼 추가 (우상단)
2. 하단 버튼 아래 "지금은 건너뛸게요" 텍스트 링크 추가
3. 건너뛰기 시 메인 홈으로 이동 (`_skip()` 로직 확인 및 연결)
4. 홈 화면에 "반려동물을 등록하면 AI 감정분석을 이용할 수 있어요" 배너 조건부 표시 (petList 비어있을 때)

**완료 기준:**
- 펫 등록 없이 홈 화면 진입 가능
- 홈에서 AI 분석 버튼 탭 시 펫 등록 유도 UI 표시

---

### P1-B: AI 감정분석 결과 — 케어 액션 추천 카드 추가

**우선순위:** ⚠️ High  
**예상 시간:** 3시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/emotion/presentation/pages/emotion_result_page.dart`
- `lib/features/emotion/domain/entities/emotion_analysis.dart`

**현재 문제:**  
감정분석 결과가 수치(행복 85%)만 표시됨. "그래서 뭘 해야 하지?"에 답이 없어 재방문 이유가 없음.

**구현할 케어 추천 카드:**

```dart
// 감정별 케어 추천 맵
const Map<String, CareRecommendation> _careMap = {
  'happiness': CareRecommendation(
    emoji: '🎾',
    title: '지금 신나 있어요!',
    actions: ['함께 산책하기', '장난감으로 놀아주기', '간식 주기'],
  ),
  'anxiety': CareRecommendation(
    emoji: '🤗',
    title: '조금 불안해하고 있어요',
    actions: ['조용한 공간 제공하기', '부드럽게 쓰다듬기', '좋아하는 담요 주기'],
  ),
  'sadness': CareRecommendation(
    emoji: '💙',
    title: '오늘 기운이 없어 보여요',
    actions: ['곁에 앉아주기', '평소보다 많이 놀아주기', '수의사 상담 고려'],
  ),
  // ... 8개 감정 전부
};
```

**카드 위치:** HeroCard 바로 아래 (현재 RecommendCard 위치 확인 후 통합 또는 별도)

**완료 기준:**
- 8개 감정 모두 케어 추천 텍스트 표시
- "오늘의 케어 기록하기" 버튼 → 건강 기록 화면으로 이동

---

### P1-C: AI 감정분석 결과 — Lottie 감성 애니메이션 추가

**우선순위:** ⚠️ High  
**예상 시간:** 2시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/emotion/presentation/pages/emotion_result_page.dart`
- `assets/lottie/` (파일 추가 필요)
- `pubspec.yaml` (assets 등록 확인)

**현재 상태:**  
`assets/lottie/`에 `splash.json`만 존재. `lottie: ^3.1.2` 패키지 설치됨.

**구현 방법:**
- lottiefiles.com에서 감정별 무료 애니메이션 다운로드 필요 (직접)
- 또는 감정 색상 기반 단순 파티클 애니메이션 코드로 구현 (Claude)

**Claude 구현 방식 (lottie 파일 없이):**
```dart
// 결과 진입 시 감정 색상 기반 confetti/pulse 애니메이션
// AnimatedContainer + TweenAnimationBuilder 활용
// 긍정 감정: 상승하는 원형 파티클
// 부정 감정: 부드러운 물결 애니메이션
```

**완료 기준:**
- 결과 화면 진입 시 1.5초 입장 애니메이션 재생
- 감정 카테고리(긍정/중립/부정)에 따라 다른 색상 애니메이션

---

### P1-D: my_page.dart limit:100 → LazyLoadList 무한스크롤

**우선순위:** ⚠️ High  
**예상 시간:** 1.5시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/my/presentation/pages/my_page.dart`
- `lib/features/social/data/repositories/social_repository_impl.dart` (페이지네이션 파라미터 확인)

**현재 문제:**  
`my_page.dart:66`에서 `getUserPostsFiltered(authorId: userId, limit: 100)` 로 한번에 100개 로드. 활성 사용자는 데이터 잘림, 초기 로드 느림, 메모리 낭비.

**작업 단계:**

1. `getUserPostsFiltered`가 `offset` 파라미터를 지원하는지 확인
2. `_buildGrid()` → `LazyGridView<Map<String, dynamic>>` 위젯으로 교체
3. `onLoadInitial`: 첫 15개 로드
4. `onLoadMore`: offset 기반 다음 15개 로드
5. 저장된 게시글 탭도 동일하게 적용

**완료 기준:**
- 초기 로드 15개, 스크롤 하단 도달 시 추가 로드
- 빈 상태 위젯 표시 정상 작동

---

### P1-E: gemini_ai_service.dart 임시 처리 정리

**우선순위:** ⚠️ High  
**예상 시간:** 1시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/emotion/data/services/gemini_ai_service.dart` (라인 469-499)
- `lib/features/emotion/domain/entities/emotion_analysis.dart`

**현재 문제:**  
`isSleepy` 값이 `EmotionScoresModel`에 직접 포함되지 않고 `_lastIsSleepy`에 캐시됨. 멀티스레드 환경이나 연속 분석 시 이전 결과의 `isSleepy`가 반환될 위험.

**작업 단계:**

1. `EmotionScores` 엔티티에 `isSleepy` 필드 정상 포함 여부 확인
2. `_lastIsSleepy` 캐시 방식 → 반환값에 직접 포함 방식으로 수정
3. 호출부(bloc)에서 캐시 getter 사용하는 코드 수정

**완료 기준:**
- `gemini_ai_service.dart`에 `임시` 주석 0건
- `flutter analyze` 통과

---

### P1-F: NetworkErrorBanner hardcoded 색상 → 테마 토큰 교체

**우선순위:** ⚠️ Medium  
**예상 시간:** 30분  
**담당:** Claude  
**영향 파일:**
- `lib/shared/widgets/network_error_widget.dart` (라인 20-25)

**현재 문제:**  
`NetworkErrorBanner`의 배경색이 `Color(0xFFFFF0F0)` (밝은 핑크빨강)으로 하드코딩됨.  
다크모드에서 배경이 어두운데 이 배너만 밝은 색으로 남음.

**변경 사항:**
```dart
// Before
color: const Color(0xFFFFF0F0)

// After  
color: Theme.of(context).colorScheme.errorContainer
// 또는
color: AppTheme.errorColor.withOpacity(0.12)
```

---

## P2 — 출시 후 v1.0.x (품질 개선)

---

### P2-A: injection_container.dart feature별 모듈 분리

**우선순위:** 🔧 Medium  
**예상 시간:** 4시간  
**담당:** Claude  
**영향 파일:**
- `lib/config/injection_container.dart` (16,000+ LOC → 분리)
- `lib/config/modules/` (신규 폴더)

**작업 단계:**

1. 현재 `injection_container.dart` 전체 분석
2. Feature별 모듈 파일 생성:
   - `modules/auth_module.dart`
   - `modules/emotion_module.dart`
   - `modules/social_module.dart`
   - `modules/health_module.dart`
   - `modules/chat_module.dart`
   - `modules/pets_module.dart`
   - `modules/core_module.dart`
3. 각 모듈에 해당 feature의 DI 등록 이전
4. `injection_container.dart`는 모듈 호출만 남김
5. `flutter analyze` + 빌드 테스트

---

### P2-B: social_remote_data_source.dart 분리

**우선순위:** 🔧 Medium  
**예상 시간:** 6시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/social/data/datasources/social_remote_data_source.dart` (2,099 LOC)

**분리 대상:**
- `post_data_source.dart` — 게시물 CRUD
- `comment_data_source.dart` — 댓글 CRUD
- `feed_data_source.dart` — 피드 조회/필터
- `follow_data_source.dart` — 팔로우/팔로워
- `like_data_source.dart` — 좋아요
- `search_data_source.dart` — 검색
- `notification_data_source.dart` — 알림

---

### P2-C: 접근성 Semantics 전체 적용

**우선순위:** 🔧 Medium  
**예상 시간:** 8시간  
**담당:** Claude

**작업 내용:**
- 모든 아이콘 버튼에 `semanticLabel` 추가
- 이미지에 `excludeFromSemantics` 또는 설명 텍스트
- 핵심 액션 버튼에 `Semantics` 래핑
- `textScaleFactor` 처리 (최대 1.5 제한 + 레이아웃 보호)

---

### P2-D: 다크모드 hardcoded Color 전수 조사 및 교체

**우선순위:** 🔧 Medium  
**예상 시간:** 4시간  
**담당:** Claude

**조사 패턴:**
```bash
grep -rn "Color(0xFF" lib/ --include="*.dart" | grep -v "AppTheme\|app_theme"
```

모든 하드코딩 색상을 `Theme.of(context).colorScheme.*` 또는 `AppTheme.*` 토큰으로 교체.

---

### P2-E: hospital_search_page.dart 로직/UI 분리

**우선순위:** 🔧 Low  
**예상 시간:** 3시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/home/presentation/pages/hospital_search_page.dart` (1,492 LOC)

**분리 대상:**
- `HospitalSearchBloc` — 검색 상태 관리
- `HospitalSearchPage` — UI만 담당
- `HospitalMapWidget` — 지도 위젯 분리

---

### P2-F: post_card.dart 서브 위젯 분리

**우선순위:** 🔧 Low  
**예상 시간:** 3시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/social/presentation/widgets/post_card.dart` (997 LOC)

**분리 대상:**
- `PostCardHeader` — 프로필 + 시간 + 메뉴
- `PostCardMedia` — 이미지/동영상 뷰어
- `PostCardActions` — 좋아요/댓글/공유/북마크
- `PostCardEmotionBadge` — 감정분석 뱃지

---

### P2-G: 알림 배치 처리

**우선순위:** 🔧 Low  
**예상 시간:** 3시간  
**담당:** Claude

**문제:** 좋아요 30개가 각각 별도 알림으로 오면 사용자가 알림 OFF → 유령 앱화

**구현:**
```
개별 발생 → Supabase Function에서 5분 윈도우로 배치
→ "OOO님 외 29명이 좋아요를 눌렀습니다"
```

---

### P2-H: 홈 화면 정보 밀도 재설계

**우선순위:** 🔧 Low  
**예상 시간:** 4시간  
**담당:** Claude  
**영향 파일:**
- `lib/features/social/presentation/pages/home_page.dart`
- `lib/features/home/presentation/widgets/` (홈 위젯들)

**현재:** HomeDashboardHeader + HomeQuickActions + HomeQuestCard + CategoryFilter + 콘텐츠 = 5개 섹션 동시 노출

**개선:** 
- 홈 = 반려동물 감정 현황 요약 + 피드 프리뷰
- QuickActions → FAB 또는 바텀시트로 이동
- QuestCard → 알림 배지로 이동

---

## P3 — v1.1.0 성장 기능

---

### P3-A: 반려동물 성장 앨범

**우선순위:** 🎯 Growth  
**예상 시간:** 1주  
**담당:** Claude

**기능:**
- 월별 감정분석 사진 자동 콜라주 (Grid 4x4)
- "이번 달 [이름]이의 표정 모음 📸"
- 공유 버튼 → 인스타그램/카카오스토리

---

### P3-B: AI 오늘의 케어 루틴 추천 고도화

**우선순위:** 🎯 Growth  
**예상 시간:** 3일  
**담당:** Claude

**기능:**
- 최근 7일 감정 트렌드 분석 → 맞춤 케어 루틴
- 아침/저녁 케어 체크리스트
- 완료 시 리워드 포인트 적립

---

### P3-C: 반려동물 생일/입양일 기념 알림

**우선순위:** 🎯 Growth  
**예상 시간:** 1일  
**담당:** Claude

**기능:**
- 등록된 생년월일 기반 D-7, D-1, D-day 알림
- 입양일 기념 알림
- 기념 카드 자동 생성 + 공유

---

### P3-D: 유사 반려동물 사용자 추천

**우선순위:** 🎯 Growth  
**예상 시간:** 3일  
**담당:** Claude

**기능:**
- 같은 품종 반려동물 보호자 추천
- "골든리트리버 키우는 사람들" 피드 필터
- 팔로우 추천 카드 홈 노출

---

## 작업 시 공통 원칙

1. **각 작업 전:** "P0-X 작업을 시작합니다. 변경 내용은 [요약]입니다. 진행할까요?" 확인
2. **파일 수정 후:** `flutter analyze` 반드시 실행
3. **commit 단위:** 작업 1개 = commit 1개
4. **직접 담당 작업:** Claude가 코드를 작성하지 않음. 가이드만 제공
5. **블로커 발생 시:** 즉시 보고 + 대안 제시
