# emotion_loading_page.dart

**LOC:** 82 | 라우트: `/emotion/loading` (ShellRoute 밖) | BLoC: EmotionAnalysisBloc

## 🎯 상호작용
- 없음 (자동 전환)

## 🔄 상태 전환
- `EmotionAnalysisSuccess` → `MaterialPageRoute` → EmotionResultPage
- `EmotionAnalysisError` → `context.pop()`

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟡 Medium | Navigator/GoRouter 혼용 — MaterialPageRoute push, GoRouter pop |
| 2 | 🟡 Medium | Timeout 없음 (Gemini API 30초+ 걸릴 수 있음) — stream에서 timeout 이벤트가 오면 OK, 없으면 무한 대기 |
| 3 | 🟢 Low | 로딩 중 뒤로가기 방어 없음 (PopScope 없음) |

**평가:** 자동 전환 | 버그 3 (M2/L1)
