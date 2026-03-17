# PetSpace 개발 진행 로그

> 마지막 업데이트: 2026-03-17  
> 담당: Jena 팀 / Claude Code 협업  
> 브랜치: `main` | 커밋: `c080c2f`

---

## 개발 우선순위 (4 Phase)

docs 3회 정독 + 코드베이스 전수 분석을 통해 수립한 로드맵.

| Phase | 목표 | 예상 공수 | 상태 |
|-------|------|----------|------|
| **Phase 1** | 출시 준비 — 앱 실행 가능 상태 완성 | ~7h | ✅ **완료** |
| **Phase 2** | 데모 핵심 — 감정분석→피드 공유 + 캘린더 뷰 | ~9h | 🔲 대기 |
| **Phase 3** | 기능 완성 — 북마크·알림·Realtime·멀티이미지 | ~14h | 🔲 대기 |
| **Phase 4** | 코드 품질 — 리팩토링·테스트·CI/CD | ~18h | 🔲 대기 |

---

## Phase 1 완료 상세 (2026-03-17)

커밋 `c080c2f` — 9 files changed, 260 insertions(+), 54 deletions(-)

### 1-1. 탭 순서 수정 ✅

**파일**: `pjh/lib/main_navigation.dart`

PRD 기준 5탭 순서로 정렬.

| 인덱스 | 이전 | 이후 |
|--------|------|------|
| 0 | 홈 | 홈 |
| 1 | 피드 | **건강관리** |
| 2 | AI분석 (FAB) | AI분석 (FAB) |
| 3 | 건강관리 | **피드** |
| 4 | MY | MY |

- 건강관리 아이콘: `medical_services` → `favorite` (Heart)
- `_updateCurrentIndex()` 라우트-인덱스 매핑 동기화

---

### 1-2. Health UseCase 레이어 신규 생성 ✅

**디렉토리**: `pjh/lib/features/health/domain/usecases/`

기존에 UseCase 레이어 자체가 없었음. Clean Architecture 원칙에 따라 5개 생성.

| 파일 | 파라미터 클래스 | 반환 |
|------|---------------|------|
| `get_health_records.dart` | `GetHealthRecordsParams(petId, type?, limit)` | `List<HealthRecord>` |
| `add_health_record.dart` | `AddHealthRecordParams(record)` | `HealthRecord` |
| `update_health_record.dart` | `UpdateHealthRecordParams(record)` | `HealthRecord` |
| `delete_health_record.dart` | `DeleteHealthRecordParams(recordId)` | `void` |
| `get_upcoming_records.dart` | `GetUpcomingRecordsParams(userId, daysAhead)` | `List<HealthRecord>` |

모두 `UseCase<T, Params>` 인터페이스 구현. `Equatable` 파라미터 클래스 포함.

---

### 1-3. HealthBloc UseCase 기반 리팩토링 ✅

**파일**: `pjh/lib/features/health/presentation/bloc/health_bloc.dart`

| 항목 | 이전 | 이후 |
|------|------|------|
| 의존성 | `HealthRepository` 1개 | UseCase 5개 + Repository |
| `_onLoadHealthRecords` | `healthRepository.getHealthRecords()` 직접 호출 | `getHealthRecords(GetHealthRecordsParams(...))` |
| `_onAddHealthRecord` | `healthRepository.addHealthRecord()` | `addHealthRecord(AddHealthRecordParams(...))` |
| `_onUpdateHealthRecord` | repository 직접, 에러 시 emit 누락 있었음 | UseCase + else 분기 완성 |
| `_onDeleteHealthRecord` | 낙관적 삭제 유지 | 동일 패턴 유지, UseCase로 위임 |

---

### 1-4. injection_container 업데이트 ✅

**파일**: `pjh/lib/config/injection_container.dart`

```dart
// 추가된 imports
import '../features/health/domain/usecases/get_health_records.dart';
import '../features/health/domain/usecases/add_health_record.dart';
import '../features/health/domain/usecases/update_health_record.dart';
import '../features/health/domain/usecases/delete_health_record.dart';
import '../features/health/domain/usecases/get_upcoming_records.dart';

// _initHealth() 내 추가 등록
sl.registerLazySingleton(() => GetHealthRecords(sl()));
sl.registerLazySingleton(() => AddHealthRecord(sl()));
sl.registerLazySingleton(() => UpdateHealthRecord(sl()));
sl.registerLazySingleton(() => DeleteHealthRecord(sl()));
sl.registerLazySingleton(() => GetUpcomingRecords(sl()));

// HealthBloc — 5개 UseCase 주입
sl.registerFactory(() => HealthBloc(
  healthRepository: sl(),
  getHealthRecords: sl(),
  addHealthRecord: sl(),
  updateHealthRecord: sl(),
  deleteHealthRecord: sl(),
  getUpcomingRecords: sl(),
));
```

---

### 1-5. MY 프로필 헤더 실데이터 바인딩 ✅

**파일**: `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`

| 항목 | 이전 | 이후 |
|------|------|------|
| 위젯 타입 | `StatelessWidget` | `StatefulWidget` |
| 통계 데이터 | 하드코딩 `'0'` | `ProfileService.getProfileStats()` 실데이터 |
| 렌더링 | 고정값 | `FutureBuilder<Map<String, dynamic>>` |

`ProfileService.getProfileStats()`는 이미 구현되어 있었음:
- `posts` — `posts` 테이블 `user_id` 카운트
- `followers` — `follows.following_id` 카운트
- `following` — `follows.follower_id` 카운트

---

### 1-6. 확인된 기존 구현 (추가 작업 불필요)

- `health_main_page.dart`: `FloatingActionButton` + `_showAddRecordSheet()` 이미 완성
  - 기록 타입 선택(ChoiceChip) / 제목·메모 입력 / 날짜 피커 / 다음 예정일 피커 / 저장
- `HealthRecord` entity: `daysUntilNext`, `isOverdue` 헬퍼 이미 있음

---

## Phase 2 작업 예정

### 2-1. 감정분석 결과 → 피드 공유 연동

**파일**: `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`

- 공유 버튼 → `CreatePost` UseCase 호출
- `emotion_analysis` JSONB 필드에 감정 분석 결과 포함
- 성공 후 피드 탭(`/feed`)으로 이동

**관련 파일**:
- `features/social/domain/usecases/create_post.dart` (기존)
- `features/social/data/models/post_model.dart` (기존)

### 2-2. 감정 히스토리 캘린더 뷰

**파일**: `pjh/lib/features/emotion/presentation/pages/emotion_history_page.dart`

- `table_calendar` 패키지 추가 필요 (`pubspec.yaml`)
- 날짜별 감정 아이콘 EventMarker
- 날짜 선택 시 해당 날 분석 목록 표시

---

## Phase 3 작업 예정

| 항목 | 핵심 파일 | 비고 |
|------|----------|------|
| 북마크 시스템 | `saved_posts` 테이블 + UseCase 신규 | MY 페이지 '저장한 글' 연동 |
| 알림 네비게이션 | `notification_service.dart` 활용 | GoRouter push 연결 |
| Realtime 배선 | `realtime_service.dart` 활용 | FeedBloc/CommentBloc 구독 |
| 멀티 이미지 뷰어 | `photo_view` 패키지 | 포스트 상세 핀치줌 갤러리 |

---

## Phase 4 작업 예정

| 항목 | 대상 파일 | 예상 공수 |
|------|----------|----------|
| emotion_result_page 분리 | `emotion_result_page.dart` (2,161줄) | 8h |
| BLoC 테스트 | AuthBloc, EmotionAnalysisBloc | 6h |
| CI/CD | `.github/workflows/` 신규 | 4h |

---

## 알려진 잔여 이슈

| 이슈 | 파일 | 우선순위 |
|------|------|---------|
| `MY 페이지 저장한 글` onTap 빈 함수 | `my_menu_list.dart` | Phase 3에서 처리 |
| `emotion_result_page` 2,161줄 거대 파일 | `emotion_result_page.dart` | Phase 4 |
| Realtime 구독 미연결 | `realtime_service.dart` | Phase 3 |
| `posts` 테이블 `user_id` 컬럼 확인 필요 | Supabase DB | Phase 2 공유 연동 시 검증 |

---

## 기술 스택 요약

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x / Dart 3.x |
| 상태관리 | BLoC + GetIt |
| 아키텍처 | Clean Architecture (data/domain/presentation) |
| 백엔드 | Supabase (Auth, PostgreSQL, Storage, Realtime) |
| AI | Google Gemini API |
| 브랜드 컬러 | Deep Blue `#1E3A5F` ↔ Coral Red `#FF6F61` |
