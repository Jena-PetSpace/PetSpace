# post_merge_edit_manifest v3

충돌 37파일 해소 뒤 변경 가능한 파일은 아래 7개뿐이다. 자동 유입 223파일과 충돌 해소 37파일은 이 목록과 별도로 관리한다.

| path | 허용 조건 |
|---|---|
| `pjh/pubspec.lock` | 해결된 `pubspec.yaml`에 대한 `flutter pub get` 결과 |
| `pjh/ios/Podfile.lock` | `flutter pub get` 성공 뒤 `pod install` 결과; pod/plugin 변경 이유 기록 |
| `pjh/macos/Flutter/GeneratedPluginRegistrant.swift` | 해결된 dependency graph의 Flutter 생성 결과 |
| `docs/work-orders/2026-07-22-win-to-mac-integration.md` | PRE_MERGE_HEAD·검증·최종 SHA 기록 |
| `docs/work-orders/2026-07-22-win-to-mac-merge-import-manifest.md` | 자동 유입 검증 결과 기록 |
| `docs/work-orders/2026-07-22-win-to-mac-resolution-manifest.md` | 37개 해소 결과 SHA 기록 |
| `docs/work-orders/2026-07-22-win-to-mac-post-merge-edit-manifest.md` | post-merge 결과 SHA 기록 |

`Podfile.lock` 직접 편집과 ours/theirs 일괄 선택은 금지한다.
