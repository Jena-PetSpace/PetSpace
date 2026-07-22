# FUNCTIONAL SPEC — 펫페이스

> 도메인별 상태관리·데이터·인터랙션 명세. 2026-07-23 UI/UX 신뢰도 개선 W0~W6 로컬 구현 기준.
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

대부분의 목록·상세 화면은 다음 상태를 가진다. 최초 실패와 기존 콘텐츠를 보존하는 refresh/load-more 실패를 구분한다.
- **Loading**: `shimmer_loading`(스켈레톤)
- **Loaded**: 콘텐츠
- **Empty**: `empty_state_widget` (예: 펫 미등록 / 기록 없음 / 글 없음)
- **Error**: 안전한 사용자 문구 + 영역별 재시도. 서버 원문·예외·식별자는 UI와 로그에 노출하지 않음
- **Rate-limited**: `rate_limit_countdown` (AI 분석 등 요청 제한)

---

## 4. 도메인별 인터랙션 요약

### 감정분석
이미지 선택(단일) → 가이드 → 풀스크린 로딩 → 결과(감정 9종 시각화 + FacialFeature 근거 + contextNote) → 공유/저장/히스토리

### 건강관리
대표 반려동물 → 다음 케어 → 최근 기록 → 5종 full task editor(추가/편집/삭제) → 필터 → 트렌드 → PDF 요약. 자동 예정일 알림은 운영 연결 전 `준비 중`, 5초 기기 테스트와 분리한다.

### 피드/커뮤니티
`피드`(사진 중심) ↔ `커뮤니티`(주제 중심) → 키셋 페이지네이션 → 사진 최대 10장 또는 제목/본문 작성 → 댓글/답글/좋아요/저장 → 신고·K1 차단 → 실패 복구. 스토리와 동영상 업로드는 제공하지 않는다.

### 채팅
방 목록(최초/새로고침 오류 분리) → 1명 선택 시 1:1, 2명 이상 선택 시 그룹 생성 → 텍스트/사진 최대 10장 → 동일 요청 재전송 → 신고·K1 차단 → 관리자 편집/멤버 읽기 전용 → 서버 성공 후 나가기. 저장 계약이 없는 멤버 강제 퇴장과 방별 알림 switch는 노출하지 않는다.

---

## 5. 공용 UI 계약

1. 디자인 토큰(color/typography/spacing)은 `AppTheme`과 `DESIGN_BASELINE.md`를 따른다.
2. 하단 내비게이션은 홈·건강·AI 분석·피드·MY의 다섯 루트에서만 보이며 모두 같은 크기와 위계다.
3. 작성·편집·상세·설정·채팅 task 화면에는 하단 탭이나 중앙 FAB를 표시하지 않는다.
4. 카드·설정 row·category chip·loading/empty/error 상태는 공용 컴포넌트를 우선한다.
5. 최소 터치 영역 44pt, 320×568과 글자 200%, light/dark mode를 회귀 기준으로 둔다.
6. 공개 AI 결과는 confidence 백분율이나 진단 확정 표현을 사용하지 않는다.
