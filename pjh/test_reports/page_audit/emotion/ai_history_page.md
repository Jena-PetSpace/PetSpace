# ai_history_page.dart

**LOC:** 1144 | BLoC: EmotionAnalysisBloc, AuthBloc, PetBloc | **Supabase 직접 호출 복수**

## 🎯 상호작용 (8개)
- 펫 스위처, 필터, 카드 탭 (emotion / health 결과), pagination, Pull-to-refresh

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟠 High | Supabase 직접 호출 (RPC get_latest_health_by_area 등) — 이미 TODO 주석 있음 |
| 2 | 🟡 Medium | 1144 LOC — 단일 파일 너무 큼 |
| 3 | 🟡 Medium | emotion/health 결과 혼재 렌더 — 상태 분기 복잡 |
| 4 | 🟡 Medium | 펫 없을 때 Graceful fallback 확인 필요 |
| 5 | 🟢 Low | BouncingScrollPhysics 미적용 |

**평가:** 정상 8/8 | 버그 5 (H1/M3/L1) — Phase 3 TODO 연속
