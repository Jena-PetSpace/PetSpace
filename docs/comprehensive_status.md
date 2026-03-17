# PetSpace 종합 현황 문서

> 기준일: 2026-03-17 | 최신 커밋: `7ee3d6d`

---

## 1. 이번 커밋 기능 개발 완료 내역

### FCM 푸시 알림 발송

| 파일 | 내용 |
|------|------|
| `supabase/functions/send-notification/index.ts` | Edge Function 신규 — notifications 테이블 저장 + FCM HTTP v1 전송 + 만료 토큰 자동 삭제 |
| `core/services/push_notification_service.dart` | Dart 클라이언트 — like/comment/follow/emotion 타입별 헬퍼 |
| `social/presentation/bloc/feed_bloc.dart` | 좋아요 성공 시 게시글 작성자에게 자동 알림 발송 |

**Edge Function 환경 변수** (Supabase Dashboard → Settings → Edge Functions Secrets):
```
FCM_SERVER_KEY      = Firebase Service Account JSON 문자열
FIREBASE_PROJECT_ID = project-5e5638c5-de70-498d-8f2
```

### 커뮤니티 탭 실데이터 연결

- `feed_hub_page.dart` 더미 데이터 → `community_posts` 테이블 실시간 쿼리
- 카테고리 필터 6개 (전체/건강Q&A/사료추천/자유Q&A/정보공유/자유)
- 새로고침 + 빈 목록 안내 UI

### 팔로잉 피드 분리

- `FeedPage(followingOnly: true)` → 팔로우한 사람 게시글만 표시
- `LoadFeedRequested`, `GetFeedParams`, `SocialRepository.getFeed` 전 계층 전파

### 유저 차단 기능

- `SocialRepository`: `blockUser/unblockUser/isBlocked` 추가
- `SocialRepositoryImpl`: `user_blocks` 테이블 CRUD
- `PostCard`: 차단 시 SnackBar + 즉시 취소(unblock) 버튼

---

## 2. 10년차 관점 — 코드 부족 / 추가 기능 우선순위

### 🔴 P1 — 앱 안정성 직결

| 항목 | 문제 | 해결 방향 |
|------|------|----------|
| **댓글 작성 시 알림 미발송** | `CommentBloc`에 `PushNotificationService` 연결 안 됨 | `_onCreateComment` 성공 시 `sendCommentNotification` 호출 |
| **팔로우 시 알림 미발송** | `ProfileBloc` follow 성공 처리에 알림 없음 | `_onFollowUser` 성공 시 `sendFollowNotification` 호출 |
| **FCM Secret 미설정** | Edge Function에 `FCM_SERVER_KEY` 없으면 푸시 전송 안 됨 | Supabase Dashboard에서 Secret 등록 필요 |
| **차단한 사용자 피드 필터링 미구현** | 차단해도 피드에 여전히 게시글 보임 | `getFeed` 쿼리에 `user_blocks` 조인 추가 |
| **커뮤니티 포스트 작성 UI 없음** | 읽기만 가능, 글 쓰기 불가 | `community_posts` INSERT 화면 구현 |

### 🟡 P2 — UX 완성도

| 항목 | 설명 |
|------|------|
| **감정 분석 히스토리 공유 버튼** | 히스토리 목록에서 바로 피드 공유 진입 없음 |
| **게시글 상세 페이지 (`/post/:postId`)** | 알림 탭에서 이동하지만 상세 페이지 구현 상태 미확인 |
| **댓글 목록 실시간 업데이트** | Realtime 구독은 있지만 `CommentBloc` 미연결 |
| **프로필 편집 후 피드 캐시 갱신** | 닉네임/사진 변경 후 기존 포스트 카드에 구 정보 잔류 |
| **검색 기능 UI** | `SearchBloc`/`SearchPage` 있지만 홈/피드 탭에서 진입 경로 없음 |

### 🟢 P3 — 품질 / 최적화

| 항목 | 설명 |
|------|------|
| **테스트 커버리지 강화** | `FeedBloc`, `CommentBloc`, `ProfileBloc` 테스트 없음 |
| **이미지 캐시 만료 전략** | `cached_network_image` 크기/만료 미설정 → 디스크 과점유 |
| **접근성 (a11y)** | `Semantics` 위젯 미적용 — 스크린 리더 미지원 |
| **다크모드 완성** | `AppTheme.darkTheme` 정의됐지만 일부 하드코딩 색상 미대응 |

---

## 3. Play Store 출시 체크리스트

### 정현이 직접 해야 함 (코드 외)

| # | 작업 | 예상 시간 |
|---|------|----------|
| ☐ | **Supabase SQL 실행** — `petspace_setup.sql` 전체 또는 신규 테이블만 | 5분 |
| ☐ | **Supabase Edge Function Secret 등록** — `FCM_SERVER_KEY`, `FIREBASE_PROJECT_ID` | 5분 |
| ☐ | **AndroidManifest 수정** — `POST_NOTIFICATIONS` 권한 + FCM 서비스 등록 | 10분 |
| ☐ | **릴리즈 서명 키 생성** — `keytool` 명령 실행 → `key.properties` 작성 (`android/key.properties.example` 참고) | 15분 |
| ☐ | **Google Play Console 계정** — [play.google.com/console](https://play.google.com/console) 가입 ($25) | 1일 (심사) |

### 빌드 & 제출

```bash
# 릴리즈 AAB 빌드 (key.properties 세팅 후)
cd pjh
flutter build appbundle --release

# 빌드 결과물 위치
# pjh/build/app/outputs/bundle/release/app-release.aab
```

### Play Store 제출 필수 자료

| 자료 | 규격 | 비고 |
|------|------|------|
| 앱 아이콘 | 512×512 PNG, 투명 배경 없음 | `assets/icons/app_icon.png` 확인 |
| 스크린샷 | 최소 2장, 권장 8장 (폰 기준) | 주요 화면 캡처 |
| 피처 그래픽 | 1024×500 JPG/PNG | 스토어 상단 배너 |
| 앱 설명 (짧음) | 80자 이내 | |
| 앱 설명 (전체) | 4000자 이내 | |
| 개인정보처리방침 URL | 공개 URL | 필수 |
| 콘텐츠 등급 설문 | Play Console 내 | 완료 시 등급 자동 부여 |

### AndroidManifest에 추가해야 할 코드

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<!-- Android 13+ 푸시 알림 권한 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- <application> 태그 안에 추가 -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>
```

---

## 전체 커밋 히스토리

| 커밋 | 내용 |
|------|------|
| `7ee3d6d` | FCM 알림/커뮤니티 탭/팔로잉 피드/유저 차단 |
| `5958093` | 우선순위 문서 |
| `831a721` | Firebase 초기화 + Play Store 배포 준비 |
| `8188f17` | 기술 부채 전체 처리 |
| `e558fa8` | 코드 리뷰 개선 |
| `bb2477f` | CI/CD |
| `a91d859` | Supabase SQL 수정 |
| `434c13e` | Phase 4 코드 품질 |
| `02fadb4` | Phase 3 기능 완성 |
| `7c1186a` | Phase 2 데모 핵심 |
| `c080c2f` | Phase 1 출시 준비 |
