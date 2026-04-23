# lib/features/health/presentation/pages/health_main_page.dart

**감사일:** 2026-04-23 | **LOC:** 452줄

## 📍 개요
- 라우트: `/health` | BLoC: HealthBloc, PetBloc, AuthBloc | 로그인 ✅

## 🎯 상호작용 (10개)
| # | 라인 | 요소 | 기대 | 상태 |
|---|------|------|------|------|
| 1 | 94 | FAB "+" | `_showAddRecordSheet` | ✅ |
| 2 | 124 | RefreshIndicator | `_loadHealthData` | ✅ |
| 3 | 280 | 필터 Chip × 6 | `_selectedFilter` 변경 | ✅ |
| 4 | 199-213 | Dismissible (스와이프) | `_confirmDelete` → DeleteHealthRecordEvent | ✅ |
| 5 | 216 | Card 탭 | `_showEditRecordSheet` | ✅ |
| 6 | 392 | "반려동물 등록하기" (펫 없음) | `/pets` push | ✅ |
| 7 | 424 | "다시 시도" (에러 상태) | `_loadHealthData` | ✅ |
| 8 | 440-446 | 삭제 확인 다이얼로그 | 취소/삭제 | ✅ |

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟡 Medium | 필터 색상 하드코딩 (AppTheme 토큰 미사용) line 262-266 |
| 2 | 🟡 Medium | `daysUntilNext` 삼항 체인 (line 345) 가독성 저하 |
| 3 | 🟡 Medium | `selectedPet` null 시 Load 안 함 + 에러 아닌 HealthInitial로 머뭇거림 |
| 4 | 🟢 Low | BouncingScrollPhysics 미적용 |
| 5 | 🟢 Low | part 디렉티브 사용 (widget/health_record_sheets.dart) — 일반적이지 않음 |

## ✅ 평가
- 정상: 8/8 | 버그 5건 (M3/L2) | 심각도 Medium
