# analysis_guide_page.dart

**LOC:** 263 | 라우트: 진입 시점 TBD (first-time guide) | BLoC: 없음

## 🎯 상호작용 (3)
| # | 라인 | 요소 | 기대 | 상태 |
|---|------|------|------|------|
| 1 | 115 | AppBar "X" | `Navigator.pop` | ✅ |
| 2 | 206 | "카메라" 버튼 | `_pick(camera)` | ✅ |
| 3 | 229 | "갤러리" 버튼 | `_pick(gallery)` | ✅ |

## 🐛 이슈
- 🟢 Low: Navigator.pop 사용 (GoRouter 불일치)
- 🟢 Low: `_pick` 결과 반환 후 처리 로직 확인 필요 (호출자에게 전달되는지)

**평가:** 정상 3/3 | 버그 2 (L2)
