# 코드 리뷰 개선 완료

> 완료일: 2026-03-17  
> 커밋: (review-fix 커밋 SHA)  
> 변경 파일: 16개 (수정 10 / 삭제 6)

---

## 개선 요약

10년차 관점 코드 리뷰 결과 도출된 16개 문제 중 우선순위대로 전부 처리.

---

## 🚨 크래시·누수 수정

### Fix 1 — EmotionAnalysisBloc `registerFactory` → `registerLazySingleton`

**파일**: `config/injection_container.dart`

`registerFactory`는 `sl()` 호출마다 새 인스턴스를 반환. 전역 `MultiBlocProvider`와 함께 쓸 때 화면마다 다른 인스턴스가 주입돼 상태 불일치 발생. `registerLazySingleton`으로 변경해 앱 전체에서 단일 인스턴스 공유.

### Fix 2 — FeedBloc StreamSubscription 누수 해결

**파일**: `social/presentation/bloc/feed_bloc.dart`

```dart
// Before: subscription 반환값 버림 → cancel 불가
_realtimeService.likeStream.listen((data) { add(...); });

// After: 필드에 저장 + close() override
StreamSubscription<Map<String, dynamic>>? _likeSub;
StreamSubscription<Map<String, dynamic>>? _commentSub;

void subscribeRealtime(String userId) {
  _likeSub?.cancel(); // 중복 구독 방지
  _likeSub = _realtimeService.likeStream.listen(...);
  _commentSub = _realtimeService.commentStream.listen(...);
}

@override
Future<void> close() {
  _likeSub?.cancel();
  _commentSub?.cancel();
  return super.close();
}
```

### Fix 3 — `home/home_page.dart` 데드코드 확인

라우터(`app_router.dart`)는 `social/presentation/pages/home_page.dart`를 사용 중. `home/presentation/pages/home_page.dart`는 완전 미참조 데드코드 → 삭제.

---

## ⚠️ 구조적 개선

### Fix 4 — ImageUploadService `auth: null` 파라미터 제거

**파일**: `core/services/image_upload_service.dart`, `config/injection_container.dart`

```dart
// Before: 불필요한 auth 파라미터 (내부에서 _supabase.auth로 직접 접근)
ImageUploadService({ required storage, required auth }) : _supabase = storage;

// After: 깔끔하게 제거
ImageUploadService({ required SupabaseClient storage }) : _supabase = storage;
```

### Fix 5 — 피드 무한스크롤 기존 구현 확인

`feed_page.dart`에 `ScrollController` + `LoadMorePostsRequested` 트리거가 완전히 구현돼 있음. 추가 작업 불필요.

### Fix 6 — 피드 공유 시 로컬 이미지 → Storage 업로드 플로우

**파일**: `emotion/presentation/pages/emotion_result_page.dart`

```dart
// Before: imageUrl 비어있으면 이미지 없이 게시
imageUrls: widget.analysis.imageUrl.isNotEmpty ? [widget.analysis.imageUrl] : [],

// After: 로컬 파일 → Storage 업로드 → URL 사용
Future<void> _postToFeed(...) async {
  String? finalImageUrl;
  if (widget.analysis.imageUrl.isNotEmpty) {
    finalImageUrl = widget.analysis.imageUrl;       // Supabase URL 있으면 그대로
  } else if (widget.imagePaths.isNotEmpty) {
    final result = await sl<ImageUploadService>()
        .uploadPostImage(File(widget.imagePaths.first)); // 없으면 업로드
    finalImageUrl = result['url'];
  }
  // 업로드 실패해도 이미지 없이 게시 계속 진행
}
```

---

## 🔒 보안·코드 품질

### Fix 7 — `debugPrint` → `dart:developer log` 전환

**파일**: `profile_edit_page.dart`, `profile_image_picker.dart`, `image_picker_widget.dart`

프로덕션 빌드에서도 출력되는 `debugPrint` 6개를 `dart:developer`의 `log()`로 교체. 민감 정보(이미지 URL) 노출 방지.

---

## 📋 추가 기능 구현

### Fix 8 — FCM Push 알림 → 인앱 딥링크 라우팅

**파일**: `core/services/fcm_service.dart`, `core/navigation/app_router.dart`, `main.dart`

#### FCMService 딥링크 로직

```dart
void _routeFromData(Map<String, dynamic> data) {
  final type = data['type'];
  switch (type) {
    case 'like': case 'comment': case 'mention':
      router.push('/post/${data['post_id']}');
    case 'follow':
      router.push('/user-profile/${data['sender_id']}');
    case 'emotion_analysis':
      router.push('/emotion/history');
    default:
      router.push('/notifications?userId=...');
  }
}

void setupInteractedMessage() {
  // 앱 종료 상태에서 알림 탭
  _firebaseMessaging.getInitialMessage().then((msg) {
    if (msg != null) _routeFromData(msg.data);
  });
  // 백그라운드 → 포그라운드 전환
  FirebaseMessaging.onMessageOpenedApp.listen(_routeFromData);
}
```

#### AppRouter — navigatorKey FCMService 주입

```dart
static GoRouter createRouter(AuthBloc authBloc) {
  final router = GoRouter(...);
  // FCMService에 navigatorKey 주입 → 딥링크 라우팅 활성화
  di.sl<FCMService>().navigatorKey = router.routerDelegate.navigatorKey;
  return router;
}
```

#### main.dart — FCMService 초기화

```dart
try {
  await di.sl<FCMService>().initialize();
} catch (e) {
  // Firebase 미설정 시 무시
}
```

---

## 🗑️ 데드코드 삭제

| 삭제 파일 | 이유 |
|----------|------|
| `home/presentation/pages/home_page.dart` | 라우터가 `social/home_page.dart` 사용, 미참조 |
| `home/presentation/bloc/home_bloc.dart` | 외부 참조 없음 |
| `home/presentation/bloc/home_event.dart` | 외부 참조 없음 |
| `home/presentation/bloc/home_state.dart` | 외부 참조 없음 |
| `social/domain/entities/social_post.dart` | `Post` entity로 통일, 미참조 |
| `social/domain/entities/user.dart` (social) | `auth/domain/entities/user.dart`로 통일, 미참조 |

---

## 잔여 기술 부채 (우선순위 낮음)

| 항목 | 내용 | 권장 시점 |
|------|------|----------|
| 하드코딩 색상 195개 | `AppTheme` 토큰으로 마이그레이션 | 디자인 시스템 확정 후 |
| `social_remote_data_source.dart` 1,311줄 | 4개 DataSource로 분리 | 팀 규모 확장 시 |
| 에러 메시지 한국어 하드코딩 | 에러 코드 기반 중앙 관리 | 다국어 지원 시 |
| 테스트 커버리지 0.7% | UseCase / Widget 테스트 보강 | 출시 이후 지속 개선 |
| profile_page 이중 구현 | social vs profile feature 통합 | 리팩토링 스프린트 |
