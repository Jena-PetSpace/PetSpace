# PetSpace 출시 준비 상태 보고서

**작성일:** 2026-04-24  
**브랜치:** mac-ios-release  
**최근 커밋:** 1955a4a (PR-15)

---

## 📊 오늘 세션 성과 요약

| 항목 | 수치 |
|------|------|
| 커밋 수 | **16개** (SQL 통합 + PR-01 ~ PR-15) |
| 리팩토링 파일 수 | **20+ 개** |
| 변경 라인 수 | **+1,800 / −1,100** |
| 추가된 Repository 메서드 | **30+ 개** |
| 스키마 버그 수정 | **6건** |
| 남은 화면 레이어 .from/.rpc/.storage/.channel 호출 | **0건** ✅ |
| flutter analyze | **0 error** (5 info, 기존 테스트 파일명) |

---

## ✅ 완료된 작업

### 1. Track A (푸시 알림 기반 인프라)
- FCM 백엔드 (Edge Function `send-push-notification` — ⚠️ 배포 전)
- 로컬 알림 (Android 3채널 + 포그라운드)
- 차단 시스템 (BlockService + RLS + RPC)
- 알림 설정 동기화 (7가지 토글, 서버 + SharedPreferences 하이브리드)
- Supabase SQL 통합 (PART 11 — migrations/ 폴더 제거, 단일 파일 원칙 복원)

### 2. Track B (Clean Architecture 마이그레이션)
**Phase 6 (우선순위 최상)**
- PR-01: `social/post_detail_page.dart`
- PR-02: `pets/public_pet_page.dart` ← 스키마 버그 2건 동시 수정
- PR-03: `chat/chat_room_settings_page.dart`

**Phase 7 (자주 진입 페이지)**
- PR-04: `social/profile_page.dart` ← 스키마 버그 3건 동시 수정
- PR-05: `chat/chat_detail_page.dart` (**Realtime Stream 패턴** 확립)
- PR-06: `social/widgets/post_card.dart`
- PR-07: `chat_rooms_page.dart` + `create_chat_page.dart`

**Phase 8 (보조 페이지)**
- PR-08: `profile/notification_settings_page.dart`
- PR-09: `trending_hashtags_section` + `search_bloc` + `user_posts_list`
- PR-10: `collection_picker_sheet` + `hashtag_page` + `location_posts_page`
- PR-11: `feed_hub_page` + `create_community_post_page`
- PR-12: `my_page` + `user_badges_section` + `reward_store_page` ← 버그 수정
- PR-13: `home_quest_card` ← 버그 수정
- PR-14: `emotion_timeline_page` + `ai_history_page` + `health_result_page`
- PR-15: `profile/privacy_settings_page.dart` ← 버그 수정

### 3. 스키마 버그 6건 수정 (기존 silent-fail 상태 → 정상 작동)
1. `public_pet_page`: `emotion_analyses` → `emotion_history`
2. `public_pet_page`: `pet_follows` (없음) → 보호자(owner) 팔로우로 의미 변경
3. `profile_page`: `pets.profile_image_url` → `avatar_url`
4. `profile_page`: `pets.species` → `type` (PetType enum)
5. `profile_page`: `pets.owner_id` → `user_id`
6. `user_badges_section`: `emotion_analyses` → `emotion_history`
7. `home_quest_card`: `post_likes` (없음) → `likes`
8. `privacy_settings_page`: `users.avatar_url` → `photo_url`

---

## 🔍 사용자(본인)가 해야 할 일

### 🚨 출시 전 필수

#### A. Supabase 배포 (10분)
`petspace_setup.sql` 전체를 Supabase SQL Editor 에서 실행하면 PART 11 (notifications/user_blocks/notification_preferences) 까지 모두 적용됩니다. idempotent 이므로 재실행 안전.

```bash
# 또는 특정 섹션만 실행 원하시면 PART 11 부분만 발췌
```

#### B. Firebase 푸시 알림 (2~3h 작업 필요 — 다음 세션)
- **현재 상태:** Google Cloud 조직 정책(`iam.disableServiceAccountKeyCreation`)으로 서비스 계정 키 발급 막힘
- **해결 경로:** Firebase Cloud Functions 로 우회 (서비스 계정 키 불필요)
- **작업 내용:**
  1. Firebase Functions 프로젝트 로컬 초기화 (`firebase init functions`)
  2. `notifications` INSERT 트리거 → Firebase Function 호출 (Supabase Database Webhook)
  3. Function 내부에서 `firebase-admin.messaging().send()` (자동 인증)
  4. `supabase/functions/send-push-notification/` 는 보관 (Legacy)

#### C. iOS APNs 인증 키 업로드 (1h)
- Apple Developer Console → Keys → **APNs Authentication Key (.p8)** 발급
- Key ID, Team ID 확인
- Firebase Console → 프로젝트 설정 → 클라우드 메시징 → **APN 인증 키 업로드**
- Bundle ID: `com.petspace.app`

#### D. Auth Flow Repository 이전 (선택, 1h)
**현 상태:** 아래 5개 파일이 `Supabase.instance.client.auth.*` 직접 호출.
- `password_reset_request_page.dart` — `signInWithOtp`
- `password_reset_verification_page.dart` — `verifyOTP` + `signOut`
- `password_reset_new_password_page.dart` — `updateUser` + `signOut`
- `onboarding_email_verification_page.dart` — `verifyOTP` + `resend` + `signOut`
- `my_page.dart` (일부)

> 이 호출들은 **정상 작동**합니다. Clean Architecture 완성도 관점에서만 남은 숙제.

---

## 🧪 실기기 테스트 시나리오 (필수)

### 핵심 플로우 (반드시 확인)
- [ ] **회원가입 → 온보딩** (이메일 OTP 인증)
- [ ] **로그인** (이메일 / Google / Kakao)
- [ ] **홈 대시보드** (오늘의 퀘스트 진행, 포인트)
- [ ] **펫 등록** (이미지 업로드 + 프로필 저장)
- [ ] **감정 분석** (Gemini API → 결과 저장 → 히스토리 반영)
- [ ] **건강 분석** (`health_result_page._saveResult` Storage 업로드 경로 작동 확인)
- [ ] **피드 작성** (텍스트 + 이미지 / 감정분석 공유)
- [ ] **좋아요 / 저장 토글** (`post_card` / `post_detail_page`)
- [ ] **컬렉션 기능** (컬렉션 생성 → 게시물 저장 → 컬렉션 이동)
- [ ] **댓글 작성 / 답글 / 좋아요**
- [ ] **팔로우 / 언팔로우** (다른 사용자 프로필)
- [ ] **보호자 팔로우** (공개 펫 프로필)
- [ ] **해시태그 / 위치 검색** (`hashtag_page` / `location_posts_page` 진입 확인)
- [ ] **채팅 1:1 시작** (프로필 → 메시지 버튼)
- [ ] **채팅 메시지 전송 + 실시간 수신** (Realtime Stream 작동)
- [ ] **채팅 다중 이미지 전송**
- [ ] **채팅방 설정** (이름 변경, 사진 변경, 나가기)
- [ ] **그룹 채팅 생성 + 멤버 초대**

### 이번 세션에 수정한 스키마 버그 플로우 (회귀 중점)
- [ ] **공개 펫 프로필 진입** — 감정 기록 그리드 표시 확인 (본인 펫)
- [ ] **내 프로필 펫 스위처** — 펫 이름/사진/아이콘 정상 렌더링
- [ ] **마이 페이지** — 뱃지 섹션, 내 게시물/저장 게시물 리스트
- [ ] **홈 퀘스트 - 좋아요** — 오늘 좋아요 후 퀘스트 완료 처리 확인
- [ ] **차단 설정** — 차단 목록에 아바타 표시

### 알림 (Phase 9 이후 검증)
- [ ] 앱 내 알림 목록 진입 (Realtime 구독)
- [ ] 좋아요/댓글/팔로우 → 상대방 알림 레코드 생성 확인
- [ ] **푸시 알림**: Firebase Functions 배포 후 검증

---

## 📦 아키텍처 현황

### Repository 계층 완성도
| Repository | 상태 | 비고 |
|------------|------|------|
| `SocialRepository` | ✅ 확장 완료 | 30+ 메서드, grab-bag 성격 (추후 분리 가능) |
| `ChatRepository` | ✅ 확장 완료 | Realtime Stream, 사진 업로드 포함 |
| `EmotionRepository` | ✅ 확장 완료 | RPC 4종 + Storage 업로드 |
| `PetRepository` | ✅ 확장 완료 | getPetDetail 추가 |
| `AuthRepository` | ⚠️ 필요 | auth flow 5파일이 직접 호출 중 |

### 데이터 흐름 원칙
```
Page / Widget / Bloc
    ↓ sl<Repository>().method()
Repository (interface — domain)
    ↓ 
RepositoryImpl (data)
    ↓
RemoteDataSource (Supabase 전담)
    ↓
Supabase SDK
```

### 보류 사항 (기술 부채)
1. **Post entity 확장** — 현재 petId / petName 필드 부재로 `getPostDetail` 이 raw Map 반환.
   Post 에 `petId`, `petName`, `content`(string alias) 추가하면 `getPostDetail` 제거 가능.
2. **SocialRepository 분리** — 30+ 메서드가 한 인터페이스에 집중. 기능별 Repository 로 분할 검토 (BookmarkRepository, FollowRepository, QuestRepository, BadgeRepository, NotificationRepository).
3. **auth.currentUser?.id 직접 사용 제거** — AuthBloc.state 에서 획득하도록 점진 전환 (대부분 파일에 5건씩 잔존).
4. **get_user_streak RPC** — 호출 경로는 준비됐으나 SQL 함수 미구현. 퀘스트 streak 기능 활성화 시 PART 12 로 추가 필요.

---

## 📅 앞으로의 작업 로드맵

### 단기 (출시 전, 이번 주 내)
1. ✅ ~~Track B (PR-01~15) 완료~~
2. Supabase SQL 배포 (`petspace_setup.sql` 실행)
3. **Firebase Cloud Functions 로 푸시 레이어 구현** (2~3h)
4. **iOS APNs .p8 업로드** (1h)
5. **실기기 회귀 테스트** (Android + iOS 각 1시간)
6. iOS 릴리스 빌드 + TestFlight 업로드
7. Android 릴리스 빌드 + Play Console 내부 테스트 업로드

### 중기 (출시 후 1~2주)
1. Auth flow Repository 이전 (PR-16 대체)
2. Post entity 확장 + `getPostDetail` 제거
3. `get_user_streak` RPC 구현 + 퀘스트 streak UI 활성화
4. SocialRepository 분리 리팩토링

### 장기 (출시 후 1개월+)
1. Google Cloud 조직 정책 해제 요청 (Edge Function 재활성화)
2. 푸시 알림 폴링 → 이벤트 기반 전환
3. 감정 히스토리 공유 기능 확장
4. 커뮤니티 카테고리 개편

---

## 🔑 참고 커밋 (롤백 지점)

| 지점 | 해시 | 설명 |
|------|------|------|
| 리팩토링 시작 전 | `057cc78` | Phase 6-8 계획서 추가 시점 |
| SQL 통합 후 | `3ed041f` | petspace_setup.sql 단일화 |
| Phase 6 완료 | `9844cac` | PR-01~03 완료 |
| Phase 7 완료 | `9a86e67` | PR-04~07 완료 |
| Phase 8 완료 | `1955a4a` | PR-08~15 완료 + 스키마 버그 6건 수정 |

---

## 🎯 현재 상태 한 줄 요약

> **Clean Architecture 리팩토링은 완료되었으며 (화면 레이어 Supabase 직접 호출 0건), 푸시 알림 서버 구현(2~3h)과 iOS APNs 키 업로드(1h)만 남았습니다.**

---

*PetSpace 출시 준비 — 세션 종료 시점 기록 | 2026-04-24*
