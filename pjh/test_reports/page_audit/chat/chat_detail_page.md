# chat_detail_page.dart

**LOC:** 465 | BLoC: ChatDetailBloc | **Supabase 직접 호출 5건**

## 🎯 상호작용 (3+ input bar)
- 메시지 전송, 이미지 전송, 메시지 길게누르기, 상단 AppBar 프로필/설정

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟠 High | Supabase 직접 호출 5건 — 이전 리뷰에서도 지적 |
| 2 | ✅ **Pre-audit 수정: chat_input_bar SafeArea.bottom** 적용 완료 |
| 3 | 🟡 Medium | Realtime 구독 dispose 확인 필요 |
| 4 | 🟡 Medium | 이미지 그리드 레이아웃 (2~4 columns) |
| 5 | 🟢 Low | 읽음 카운트 표시 정확도 |

**평가:** 정상 | 버그 4 (H1/M2/L1) + 수정 1건
