# FUNCTIONAL SPEC — 펫페이스

> 도메인별 상태관리·데이터·인터랙션 명세. 클로드 디자인이 컴포넌트·상태 단위로 이해하도록 분해.
> 근거: BLoC/Cubit 17개 · domain/entities

---

## 1. 상태관리 맵 (18 BLoC/Cubit)

> 기능 BLoC/Cubit 17개 + 전역 `ThemeCubit`(shared/themes) = **18개**.

| 도메인 | 상태 객체 | 비고 |
|---|---|---|
| (전역) | ThemeCubit | 테마 전환 (shared/themes/theme_cubit.dart) |
| auth | AuthBloc | 전역 인증, 라우터 가드의 소스 |
| onboarding | OnboardingBloc | 가입 단계 진행 |
| emotion | EmotionAnalysisBloc | 분석 실행·결과·히스토리 |
| health | HealthBloc | 기록 CRUD·필터·알림 (Loaded/Empty/Error 분기) |
| pets | PetBloc | 반려동물 CRUD·여권 |
| chat | ChatRoomsBloc · ChatDetailBloc · ChatBadgeBloc | 목록·상세·미읽음 배지 |
| feed_hub | CommunityCubit | Q&A 전용 (FeedBloc과 분리) |
| social | FeedBloc · ProfileBloc · SocialBloc · BookmarkBloc · CommentBloc · SearchBloc · NotificationsBloc · NotificationBadgeBloc | 사진 피드·프로필·검색·댓글·북마크·알림 |
| mbti | MbtiTestBloc | 검사 진행·결과 |
| news | NewsBloc | 기사 목록 |

> **핵심 설계 의도**: 사진 피드(`FeedBloc`)와 Q&A(`CommunityCubit`)는 성격이 달라 통합하지 않음. UI에서도 두 모드를 명확히 구분해야 함.

---

## 2. 핵심 데이터 모델

### 2.1 Pet
```
id, userId, name, type(dog|cat), breed?, birthDate?, gender(male|female)?,
avatarUrl?, description?, createdAt, updatedAt,
currentMbtiType?, currentMbtiUpdatedAt?,
passportNo?, passportSurname?, passportGivenName?, nameHanguel?, countryCode?
```
- 펫 여권: 영문 성/이름 + 한글명 + 국가코드 → 여권 카드 UI 연동

### 2.2 EmotionAnalysis
```
id, userId, petId?, petName?, imageUrl, localImagePath,
emotions(EmotionScores), confidence, analyzedAt, memo?, tags[],
isSleepy, contextNote?
EmotionScores: happiness·sadness·anxiety·curiosity·calm·excitement·fear·discomfort·sleepiness(deprecated)
FacialFeature: state(예 "귀가 뒤로 눕혀짐") · signal(예 "불안")
```
- confidence: 데이터 보존·UI 비노출
- contextNote: 결과 화면 v2의 맥락 설명 파이프라인

### 2.3 HealthRecord
```
id, petId, userId, recordType, title, description?, recordDate, nextDate?,
status, data(Map), createdAt, updatedAt
recordType: vaccination·checkup·weight·medication·surgery
status: scheduled·completed·overdue·cancelled
```
- `data(Map)`: 타입별 가변 필드(체중값·약명 등) 수용
- `nextDate` + `overdue` → 다가오는 알림·지연 표시

### 2.4 기타
- Community/Post/Comment/Follow/Notification (social)
- ChatRoom/ChatMessage/ChatParticipant (chat)
- PetMbtiResult/MbtiContent(content_version), DailyFortune/FortuneContent, QuizSet/QuizContent/QuizResultSnapshot, NewsArticle, Breed

---

## 3. 화면 상태 패턴 (공통)

대부분의 목록·상세 화면은 다음 상태를 가짐 — 클로드 디자인에서 각 상태별 화면을 모두 준비해야 함:
- **Loading**: `shimmer_loading`(스켈레톤)
- **Loaded**: 콘텐츠
- **Empty**: `empty_state_widget` (예: 펫 미등록 / 기록 없음 / 글 없음)
- **Error**: `error_dialog` / `network_error_widget` / `error_snackbar`
- **Rate-limited**: `rate_limit_countdown` (AI 분석 등 요청 제한)

---

## 4. 도메인별 인터랙션 요약

### 감정분석
이미지 선택(단일) → 가이드 → 풀스크린 로딩 → 결과(감정 9종 시각화 + FacialFeature 근거 + contextNote) → 공유/저장/히스토리

### 건강관리
기록 추가(5종 타입별 입력 폼) → 필터 칩으로 조회 → 다가오는 알림 → 트렌드 차트 → PDF 요약 생성

### 피드/커뮤니티
모드 전환(사진 ↔ Q&A) → 키셋 페이지네이션 → 작성/댓글/북마크 → 신고·차단 → 실시간 반영

### 채팅
방 목록(미읽음 배지) → 입장(실시간) → 메시지 → 설정(신고·차단·나가기)

---

## 5. 컴포넌트 우선 등록 목록 (클로드 디자인)
1. 디자인 토큰 (color/typography/spacing) — `DESIGN_BASELINE.md` 기준
2. 하단 네비 + 중앙 FAB
3. 카드 계열 (홈 매거진·핫이슈·기능 카드)
4. 상태 위젯 5종 (loading/loaded/empty/error/rate-limit)
5. 이미지 선택·뷰어·업로드 진행
6. 결과 화면 토큰 (감정·건강 result)
