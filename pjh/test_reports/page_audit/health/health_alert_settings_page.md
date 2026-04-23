# lib/features/health/presentation/pages/health_alert_settings_page.dart

**감사일:** 2026-04-23 | **LOC:** 210줄

## 📍 개요
- 라우트: `/health/alert-settings` | BLoC: 없음 (SharedPreferences 직접) | 로그인 ✅

## 🎯 상호작용 (6개)
| # | 라인 | 요소 | 기대 | 상태 |
|---|------|------|------|------|
| 1 | 62-65 | AppBar "저장" | `_saveSettings` → SharedPreferences | ✅ |
| 2 | 80 | SwitchListTile (알림 ON/OFF) | `_alertEnabled` 토글 | ✅ |
| 3 | 94-96 | CheckboxListTile × 3 (D-7/D-3/D-1) | 각 값 토글 | ✅ |
| 4 | 107-121 | 시간 선택 | `showTimePicker` → `_alertTime` | ✅ |

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟠 High | **FCM 토큰 연동 안 됨** — SharedPreferences 저장만. 실제 푸시 스케줄링 없음. 안내 문구(line 151)는 동작 암시하나 미구현 |
| 2 | 🟡 Medium | 알림 OFF 상태에서 D-day/시간 비활성 opacity 0.4만, 클릭 막는 로직은 `_alertEnabled ? onChanged : null`로 개별 처리 — 일관성 부족 |
| 3 | 🟢 Low | SharedPreferences 직접 호출 (BLoC 미경유) |
| 4 | 🟢 Low | 에러 처리 없음 (`await prefs.setBool` 실패 시) |

## ✅ 평가
- 정상: 6/6 (UI는 작동) | 버그 4건 (**H1**/M1/L2) | 심각도 High (실제 알림 미작동)
