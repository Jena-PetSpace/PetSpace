# P3 품질/최적화 완료

> 기준일: 2026-03-17 | 커밋: `9414d2e`

---

## 완료 항목

### 다크모드 완성

**파일**: `shared/themes/app_theme.dart`

기존 4줄짜리 미완성 → 170줄 완전한 다크 테마로 확장.

| 컴포넌트 | 다크 색상 |
|---------|----------|
| 배경 (Scaffold) | `#121212` |
| 표면 (Surface, AppBar) | `#1E1E1E` |
| 카드 | `#252525` |
| 기본 텍스트 | `#E0E0E0` |
| 보조 텍스트 | `#9E9E9E` |
| 구분선 | `#2E2E2E` |
| 힌트 | `#757575` |

lightTheme과 동일한 컴포넌트 커버리지:
AppBar / Card / BottomNavigationBar / TabBar / ElevatedButton / TextButton /
OutlinedButton / FAB / InputDecoration / Divider / Chip / Icon / Text /
SnackBar / Dialog / ListTile / Switch

---

### 접근성 (Semantics)

**스크린 리더(TalkBack/VoiceOver) 지원을 위한 Semantics 위젯 적용**

| 파일 | 적용 위젯 | Semantics 레이블 |
|------|----------|----------------|
| `post_card.dart` | 작성자 프로필 이미지 | `{작성자명} 프로필 사진` |
| `post_card.dart` | 좋아요 버튼 | `좋아요` / `좋아요 취소` (상태 반영) |
| `post_card.dart` | 댓글 버튼 | `댓글 {N}개 보기` |
| `main_navigation.dart` | 하단 탭 5개 | 탭 이름 + selected 상태 |
| `emotion_analysis_page.dart` | 분석 시작 버튼 | 사진 수에 따른 동적 레이블 + enabled 상태 |
| `health_main_page.dart` | 건강기록 추가 FAB | `건강 기록 추가` |

---

### 이미지 캐시 크기 제한

**파일**: `main.dart`

```dart
PaintingBinding.instance.imageCache.maximumSize = 200;         // 최대 200개 이미지
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
```

기존 Flutter 기본값(1000개 / 무제한)에서 명시적 제한으로 변경.

---

### FeedBloc 단위 테스트 12케이스

**파일**: `test/features/social/presentation/bloc/feed_bloc_test.dart`

| 그룹 | 케이스 |
|------|------|
| 초기 상태 | FeedInitial 확인 |
| LoadFeedRequested | 성공/실패/빈결과 |
| LikePostRequested | 낙관적 업데이트 성공 / 실패 시 롤백 |
| SavePostRequested | 성공 / 실패 |
| RefreshFeedRequested | 성공 |

---

## 누적 테스트 현황

| 파일 | 케이스 |
|------|------|
| `auth_bloc_test.dart` | 11 |
| `emotion_analysis_bloc_test.dart` | 11 |
| `health_usecases_test.dart` | 9 |
| `bookmark_usecases_test.dart` | 8 |
| `feed_bloc_test.dart` | 12 |
| **합계** | **51케이스** |

CI 파이프라인에서 모든 테스트 자동 실행 (`flutter test --reporter=expanded`)

---

## 전체 P1~P3 완료 요약

| 우선순위 | 항목 수 | 상태 |
|---------|--------|------|
| P1 — 앱 안정성 | 4개 | ✅ |
| P2 — UX 완성 | 6개 | ✅ |
| P3 — 품질/최적화 | 4개 | ✅ |
| **합계** | **14개** | **✅ 전체 완료** |

---

## 이제 남은 것

### 정현이 직접 해야 하는 것만 남음

| # | 작업 |
|---|------|
| 1 | Supabase SQL 실행 (`petspace_setup.sql`) |
| 2 | Supabase Edge Function Secret: `FCM_SERVER_KEY`, `FIREBASE_PROJECT_ID` |
| 3 | `AndroidManifest.xml` — `POST_NOTIFICATIONS` 권한 + FCM 서비스 등록 |
| 4 | 릴리즈 서명 키 생성 → `android/key.properties` 작성 |
| 5 | Google Play Console 계정 생성 ($25) |
| 6 | `flutter build appbundle --release` |
| 7 | Play Store 제출 (스크린샷 / 설명 / 개인정보처리방침) |

위 작업 완료 후 Play Store 출시 가능합니다.
