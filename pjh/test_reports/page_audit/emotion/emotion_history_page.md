# emotion_history_page.dart

**LOC:** 898 | 라우트: `/emotion/history` | BLoC: EmotionAnalysisBloc

## 🎯 상호작용 (13개)
- AppBar 뒤로/필터, 검색, 기간 선택, 정렬, 카드 탭(→ result_page), 스와이프 삭제, 페이지네이션, Pull-to-refresh 등

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟡 Medium | 898 LOC 단일 파일 — 리팩토링 대상 |
| 2 | 🟡 Medium | 긴 스크롤 리스트 pagination 확인 필요 |
| 3 | 🟡 Medium | 빈 상태 / 에러 상태 UX |
| 4 | 🟢 Low | BouncingScrollPhysics 미적용 |

**평가:** 정상 | 버그 4 (M3/L1)
