# 잔여 기술 부채 처리 완료

> 완료일: 2026-03-17  
> 커밋: (tech-debt 커밋 SHA)  
> 변경 파일: 23개 (신규 7 / 수정 16)

---

## 처리 항목 요약

| # | 항목 | 결과 |
|---|------|------|
| 1 | 하드코딩 색상 → AppTheme 토큰 | ✅ 토큰 8개 추가 + 17곳 자동 교체 |
| 2 | `social_remote_data_source.dart` 1312줄 분리 | ✅ 92줄 + part 5개 |
| 3 | 에러 메시지 중앙 관리 | ✅ 14개 상수 추가 + Repository 연결 |
| 4 | 테스트 커버리지 보강 | ✅ Health UseCase 9케이스 + 북마크 UseCase 8케이스 추가 |
| 5 | `profile_page` 이중 구현 통합 | ✅ 래퍼 패턴으로 단일 UI 공유 |

---

## 1. AppTheme 시맨틱 토큰

**파일**: `shared/themes/app_theme.dart`

```dart
// 새로 추가된 토큰
static const Color successColor = Color(0xFF4CAF50); // 성공·완료
static const Color errorColor   = Color(0xFFE53935); // 에러·삭제
static const Color warningColor = Color(0xFFFF9800); // 경고
static const Color infoColor    = Color(0xFF0077B6); // 정보 (= accentColor)

static const Color dividerColor     = Color(0xFFE0E0E0);
static const Color disabledColor    = Color(0xFFBDBDBD);
static const Color hintColor        = Color(0xFF9E9E9E);
static const Color subtleBackground = Color(0xFFF5F5F5);
```

`Color(0xFF4CAF50)` → `AppTheme.successColor` 9개 파일 17곳 자동 교체.  
`Colors.white`, `Colors.black`은 의도적 사용이므로 유지.

---

## 2. social_remote_data_source.dart 분리

**before**: 1312줄 단일 파일 (80개 메서드, God Object)  
**after**: 92줄 메인 + part 5개

| 파일 | 담당 | 줄 수 |
|------|------|------|
| `social_remote_data_source.dart` | 인터페이스 + part 선언 | 92줄 |
| `_user.dart` | createUser, getUser, updateUser, deleteUser, searchUsers | 176줄 |
| `_post.dart` | createPost, getPost, getFeedPosts, likePost 등 | 296줄 |
| `_comment.dart` | createComment, getComment, likeComment 등 | 201줄 |
| `_follow.dart` | followUser, unfollowUser, getFollowers 등 | 161줄 |
| `_notification.dart` | getUserNotifications, createNotification, searchPosts 등 | 394줄 |

`part` / `part of` 패턴 사용 → `SocialRemoteDataSourceImpl` 상태 공유 유지.

---

## 3. 에러 메시지 중앙 관리

**파일**: `core/error/error_messages.dart`

추가된 상수:

```dart
// 소셜 (신규)
static const String feedLoadFailed        = '피드를 불러오지 못했습니다.';
static const String savePostFailed        = '게시물 저장에 실패했습니다.';
static const String unsavePostFailed      = '저장 취소에 실패했습니다.';
static const String savedPostsLoadFailed  = '저장한 글을 불러오지 못했습니다.';

// 건강 관리 (신규)
static const String healthRecordLoadFailed   = '건강 기록을 불러오지 못했습니다.';
static const String healthRecordCreateFailed = '건강 기록 저장에 실패했습니다.';
static const String healthRecordUpdateFailed = '건강 기록 수정에 실패했습니다.';
static const String healthRecordDeleteFailed = '건강 기록 삭제에 실패했습니다.';

// 채팅 (신규)
static const String chatRoomCreateFailed = '채팅방 생성에 실패했습니다.';
static const String messageSendFailed    = '메시지 전송에 실패했습니다.';
static const String chatLoadFailed       = '채팅 내역을 불러오지 못했습니다.';
```

`SocialRepositoryImpl`, `HealthRepositoryImpl` → `ErrorMessages.networkError` 상수 참조 전환.

---

## 4. 테스트 커버리지 보강

| 파일 | 케이스 수 | 내용 |
|------|---------|------|
| `health_usecases_test.dart` | 9 | GetHealthRecords(3), AddHealthRecord(2), UpdateHealthRecord(1), DeleteHealthRecord(2), GetUpcomingRecords(2) |
| `bookmark_usecases_test.dart` | 8 | SavePost(2), UnsavePost(2), GetSavedPosts(4) |

CI 파이프라인 테스트 목록에도 추가 (`ci.yml`).

**누적 테스트 현황**: 4개 파일, 총 40개 케이스

| 파일 | 케이스 |
|------|------|
| `auth_bloc_test.dart` | 11 |
| `emotion_analysis_bloc_test.dart` | 11 |
| `health_usecases_test.dart` | 9 |
| `bookmark_usecases_test.dart` | 8 (+ 1 params) |

---

## 5. profile_page 이중 구현 통합

**before**: `profile/profile_page.dart` (자체 UI)와 `social/profile_page.dart` (완성된 UI) 별도 존재.

**after**: `profile/profile_page.dart` → `social/ProfilePage`를 감싸는 래퍼로 리팩토링.

```dart
// profile/profile_page.dart — 래퍼
class ProfilePage extends StatelessWidget {
  Widget build(BuildContext context) {
    final myId = (authState as AuthAuthenticated).user.id;
    return BlocProvider(
      create: (_) => di.sl<ProfileBloc>()..add(LoadUserProfileRequested(...)),
      child: social.ProfilePage(        // ← 동일한 UI 컴포넌트 재사용
        userId: myId,
        currentUserId: myId,
        isMyProfile: true,              // ← 설정 버튼 표시
      ),
    );
  }
}
```

`social/ProfilePage`에 `isMyProfile` 파라미터 추가 — `true`일 때 AppBar에 설정 버튼 표시.

---

## 전체 개발 완료 현황

| Phase | 내용 | 커밋 |
|-------|------|------|
| Phase 1 | 출시 준비 | `c080c2f` |
| Phase 2 | 데모 핵심 | `7c1186a` |
| Phase 3 | 기능 완성 | `02fadb4` |
| Phase 4 | 코드 품질 | `434c13e` |
| SQL 수정 | Supabase 스키마 | `a91d859` |
| CI | GitHub Actions | `bb2477f` |
| 리뷰 개선 | 크래시/누수/딥링크 | `e558fa8` |
| 기술 부채 | 색상/분리/테스트/통합 | (현재) |
