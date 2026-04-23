# emotion_calendar_page.dart

**LOC:** 388 | 라우트: `/emotion/calendar` | BLoC: EmotionAnalysisBloc

## 🎯 상호작용 (3)
- 달력 날짜 탭 → 선택
- 이전/다음 월
- 카드 탭 → emotion_result_page

## 🐛 이슈
- 🟡 Medium: 200건 한번에 로드 (limit 200) — pagination 없음
- 🟡 Medium: 달 이동 시 쿼리 재발생 여부 확인 필요
- 🟢 Low: BouncingScrollPhysics 미적용

**평가:** 정상 3/3 | 버그 3 (M2/L1)
