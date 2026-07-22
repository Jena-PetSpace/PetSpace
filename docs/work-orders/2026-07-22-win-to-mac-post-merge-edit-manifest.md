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

## 생성 결과 SHA-256

| path | 결과 | SHA-256 |
|---|---|---|
| `pjh/pubspec.lock` | `flutter pub get` 후 merge 결과와 byte 동일 | `3b7c89fa9afcc84544ffde18191bf1e5f050912b0e66dbf12ba4f3e0b83ed29c` |
| `pjh/ios/Podfile.lock` | `pod install`이 `package_info_plus` iOS pod/source/checksum을 추가 | `b5704a1f4ad822e4664ae8836fda498f61f9aecce0d583969106f2e682a2b757` |
| `pjh/macos/Flutter/GeneratedPluginRegistrant.swift` | dependency graph 생성 결과가 merge 결과와 byte 동일 | `138f6b1ba3070dea1aac85cc138bb0e791da7c10e7d81d57596f31ba2268392a` |

작업지시서 4개는 자기 자신의 hash를 본문에 넣는 순환 참조를 피하기 위해 이 표에서 제외하며, 최종 commit의 Git blob OID로 고정한다.
