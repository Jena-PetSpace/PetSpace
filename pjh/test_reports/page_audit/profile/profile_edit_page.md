# profile_edit_page.dart

**LOC:** 248 | ProfileService

## 🎯 상호작용 (1+ 내부)
- 이미지 변경, 닉네임, 자기소개, 저장

## 🐛 이슈
- 🟡 Medium: ProfileService 직접 주입 (BLoC 미경유)
- 🟡 Medium: 닉네임 중복 체크 없음
- 🟢 Low: MyPageStatsNotifier 동기화 확인

**평가:** 정상 | 버그 3 (M2/L1)
