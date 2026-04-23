# emotion_analysis_page.dart

**LOC:** 1304 | 라우트: `/emotion` | BLoC: EmotionAnalysisBloc, PetBloc, AuthBloc | 로그인 ✅

## 🎯 상호작용 (14개)
| # | 라인 | 요소 | 기대 | 상태 |
|---|------|------|------|------|
| 1 | 282 | 가이드 "X" | `_dismissFullGuide` | ✅ |
| 2 | 537 | "분석 시작" | `_canAnalyze` 시 `_startAnalysis` → loading 페이지 | ✅ |
| 3 | 570 | 사진 선택 영역 | `_requestPermissionsAndOpenGuide` (카메라+갤러리) | ✅ |
| 4 | 626 | 이미지 추가(+) | 동일 | ✅ |
| 5 | 670 | 이미지 X (개별) | `_imagePaths.removeAt` | ✅ |
| 6 | 802 | 드롭다운 옵션 선택 | `onSelected(option)` | ✅ |
| 7 | 864 | 카드 탭 (종류) | 선택 | ✅ |
| 8 | 900 | 카드 탭 (품종) | 선택 | ✅ |
| 9 | 962 | 부위 선택 (눈/귀/입/자세) | `_selectedArea` | ✅ |
| 10 | 995 | "추가 정보 입력" | 확장 토글 | ✅ |
| 11 | 1138 | "설정으로 이동" | `openAppSettings()` | ✅ |
| 12 | 1287-1291 | 다이얼로그 버튼들 | | ✅ |

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟠 High | PetInlineDropdown에서 pet 선택 안 된 상태로 분석 시작 시 `_canAnalyze` 가드만 있고 에러 처리 흐름 불명확 |
| 2 | 🟡 Medium | 이미지 5장 제한 (pickMultiImage limit=5) — iOS PHPicker limit 작동 확인 필요 |
| 3 | 🟡 Medium | 이미지 파일 시스템 접근 (iOS sandbox) 에러 처리 |
| 4 | 🟡 Medium | `_startAnalysis` 호출 시 기존 분석 중인 BLoC 상태 확인 없음 (중복 요청 가능) |
| 5 | 🟡 Medium | 1300줄 단일 StatefulWidget — 분리 필요 |
| 6 | 🟢 Low | BouncingScrollPhysics 미적용 |

**평가:** 정상 12/12 | 버그 6 (H1/M4/L1) | 심각도 High
