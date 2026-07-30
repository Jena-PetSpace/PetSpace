# 작업지시서 초안: ICON-1 — 펫페이스 아이콘 시스템 정비

- 상태: ICON-1A·1B Mac 병합 완료, 자동·Claude 코드 검토 통과
- 작성자: Codex
- 승인자: 사용자 (2026-07-30 앱 코드 수정·복구 가능한 커밋 진행 승인)
- 담당: Codex
- 교차 리뷰어: 미정
- 기준 브랜치: `win-android-release` (`02f74e50`)
- 작업 브랜치: `feature/icon-system-plan-20260730`
- 관련 자료:
  - `C:\Users\wjdgu\Documents\카카오톡 받은 파일\펫페이스 아이콘(svg)_260729.xlsx`
  - 2026-07-30 사용자 제공 SVG 6개
  - 사용자 제공 홈 바로가기 참고 이미지

## 0. Mac 병합 승인 기록

- Base: `02f74e50d645a2e4eb29cb0d4ac735ff40d39445`
- Windows 구현:
  - `1ade66db5d61d0fcbba0fe0c07fe8b34aca05262`
  - `40753dd14b1f0756d150ce7ef7e6cd2faf9790a6`
- Mac 병합 커밋: `bddb840`
- 병합 대상: 이 문서와 코드·테스트·PNG를 포함한 정확한 12개 경로
- 충돌: 없음
- Codex 검토: blocker/high 없음
- Claude 검토: `PASS`, blocker/high 없음

이 병합은 기존 Home/AI 결과 동결 정책의 일반 해제가 아니다. 고정된 두
Windows 커밋의 홈 퀵액션 아이콘 변경만 사용자 승인 예외로 수용하며, 새 공용
아이콘 코드와 PNG를 포함한 전체 렌더링 입력은 갱신된 UI/UX 동결 스냅샷으로
다시 보호한다.

## 1. 결론

이번 작업은 SVG 파일을 같은 이름으로 덮어쓰는 방식으로 진행하면 안 된다.

1. 현재 앱은 홈 바로가기 SVG에 브랜드 단색 필터를 강제로 적용한다. 새 컬러 아이콘을 그대로 연결하면 원래 색이 모두 사라진다.
2. 현재 `icon_feed.svg`는 피드가 아니라 북마크 모양이다. 엑셀의 `피드`와 `저장`을 같은 자산으로 취급하면 의미가 다시 충돌한다.
3. 사용자 제공 컬러 SVG 6개는 순수 벡터가 아니라 base64 PNG를 감싼 SVG다. 화면에 사용할 수는 있지만, SVG로 오인해 무제한 확대 가능한 자산으로 관리하면 안 된다.
4. 앱 곳곳에서 Material 아이콘과 SVG가 혼용된다. 전역 일괄 교체는 회귀 범위가 너무 크므로 공용 렌더러를 먼저 만들고 단계별로 이관한다.
5. 기존 합의에 따라 하단 5탭 UI는 이번 1차 구현 범위에서 제외한다. 하단 탭 아이콘 변경은 별도 목업과 승인을 거친다.

권고안은 **컬러 기능 아이콘과 단색 조작 아이콘을 서로 다른 계층으로 분리**하는 것이다.

- 컬러 기능 아이콘: 홈의 플레이스·MBTI 검사·산책 기록·오늘의 운세·O/X 퀴즈
- 단색 조작 아이콘: 검색·알림·메시지·닫기·설정·작성·공유·댓글·저장·뒤로가기
- 하단 탐색 아이콘: 홈·건강·AI 분석·피드·MY — 이번 구현 보류

## 2. 확인된 사실

### 2.1 엑셀 원본

엑셀 `Sheet1`의 아이콘 행은 총 21개다.

| 번호 | 아이콘 | 원본 상태 | 엑셀 메모 | 초안 판정 |
|---:|---|---|---|---|
| 1 | 홈 | SVG 있음 | - | 현행 유지 후보 |
| 2 | 건강 | SVG 있음 | - | 현행 유지 후보 |
| 3 | 측정 | SVG 있음 | 미사용 | 미도입 |
| 4 | 피드 | SVG 있음 | 반영 필요 | 저장과 분리 후 보류 |
| 5 | 개인 | SVG 있음 | - | 현행 MY와 비교 유지 |
| 6 | 검색 | SVG 있음 | - | 24 viewBox로 정규화 후보 |
| 7 | 알림 | SVG 있음 | - | 24 viewBox로 정규화 후보 |
| 8 | 메시지 | SVG 있음 | - | 24 viewBox로 정규화 후보 |
| 9 | 닫기 | SVG가 아닌 HTML 아이콘 태그 | 반영 필요 | 현행 유효 SVG 유지 |
| 10 | 설정 | SVG 있음 | 반영 필요 | 공용 조작 아이콘으로 도입 |
| 11 | 작성 | SVG 있음 | 반영 필요 | 공용 조작 아이콘으로 도입 |
| 12 | 공유 | SVG 있음 | 반영 필요 | 공용 조작 아이콘으로 도입 |
| 13 | 댓글 | SVG 있음 | 반영 필요 | 공용 조작 아이콘으로 도입 |
| 14 | 저장 | SVG 있음 | 반영 필요 | `피드`와 별도 이름으로 도입 |
| 15 | AI 분석 | SVG 있음 | 반영 필요 | 하단 탭 보류, 기능 화면 후보 |
| 16 | 뒤로가기 | SVG 있음 | 반영 필요 | 공용 앱바 아이콘으로 도입 |
| 17 | 플레이스 | 엑셀 비어 있음 | - | 별도 제공 컬러 원본 사용 |
| 18 | MBTI 검사 | 엑셀 비어 있음 | - | 별도 제공 컬러 원본 사용 |
| 19 | 산책 기록 | 엑셀 비어 있음 | - | 별도 제공 2개 원본을 하나로 합성 |
| 20 | 오늘의 운세 | 엑셀 비어 있음 | - | 별도 제공 컬러 원본 사용 |
| 21 | O/X 퀴즈 | 엑셀 비어 있음 | - | 별도 제공 컬러 원본 사용 |

엑셀에서 명시적으로 `반영 필요`인 항목은 피드·닫기·설정·작성·공유·댓글·저장·AI 분석·뒤로가기 9개다.

### 2.2 별도 제공된 컬러 원본

사용자가 별도로 제공한 6개 파일로 5개 홈 기능을 모두 식별했다.

| 기능 | 전달 파일 구성 | 캔버스 | 형식 판정 |
|---|---:|---:|---|
| 플레이스 | 1개 | 91×91 | PNG 내장 SVG |
| MBTI 검사 | 1개 | 115×115 | PNG 내장 SVG |
| 산책 기록 | 2개 | 66×58, 78×72 | PNG 내장 SVG, 하나의 자산으로 합성 필요 |
| 오늘의 운세 | 1개 | 159×159 | PNG 내장 SVG |
| O/X 퀴즈 | 1개 | 97×97 | PNG 내장 SVG |

기획 확정에는 추가 피그마 열람이 필요하지 않다. 실제 구현도 내장 PNG를 추출해 진행할 수 있다.

단, 다음 중 하나를 구현 전에 자산 계약으로 확정한다.

- 권고: Figma에서 이미지 임베드가 아닌 path 기반 SVG로 다시 export한다.
- 즉시 적용안: 현재 SVG에서 PNG를 추출해 `assets/images/quick_actions/`에 명시적인 래스터 자산으로 저장한다.

PNG 내장 SVG를 그대로 `assets/svg/`에 넣는 방식은 파일 확장자와 실제 품질 계약이 달라지므로 사용하지 않는다.

### 2.3 현재 코드

- 홈 5개 바로가기는 `pjh/lib/features/home/presentation/widgets/home_quick_actions.dart:31-54`에서 기존 단색 SVG를 사용한다.
- 각 아이콘은 52dp 원형 안에 24dp로 렌더링된다 (`home_quick_actions.dart:86-96`).
- 모든 아이콘에 `AppTheme.primaryColor` 단색 필터가 강제된다 (`home_quick_actions.dart:98`).
- `pjh/assets/svg/icon_feed.svg`는 이름과 달리 북마크/저장 모양이다.
- 현재 검색·알림·메시지 SVG는 60 viewBox와 4px stroke를 쓰고, 홈·건강·MY 등은 24 viewBox와 2px stroke를 쓴다.
- `pjh/assets/svg/icon_paw.svg`는 오래된 Illustrator 메타데이터와 base64 이미지를 포함하고 흰색이 하드코딩되어 있다.
- 공용 앱바 뒤로가기는 아직 Material `Icons.arrow_back`을 사용한다 (`pjh/lib/shared/widgets/petspace_app_bar.dart:94`).
- 게시물 액션은 Material 댓글·공유·북마크 아이콘을 사용한다 (`post_card_actions.dart:250`, `:274`, `:299-300`).
- MY 헤더와 MY 페이지의 설정도 Material 아이콘을 사용한다 (`my_profile_header.dart:126`, `my_page.dart:164`).
- `flutter_svg` 2.x와 `assets/svg/` 폴더 등록은 이미 존재한다.

## 3. 제품·UI 원칙

### 3.1 아이콘 역할을 분리한다

| 계층 | 표현 | 색상 처리 | 예시 |
|---|---|---|---|
| `featureColor` | 기능을 기억하게 하는 컬러 일러스트형 | 원본 색 유지, tint 금지 | 플레이스, MBTI, 산책, 운세, 퀴즈 |
| `actionMono` | 화면 조작을 위한 선형 아이콘 | `currentColor` 또는 단색 tint | 닫기, 설정, 공유, 댓글, 저장 |
| `navigationMono` | 하단 탐색 상태 | 선택/비선택 토큰 적용 | 홈, 건강, AI, 피드, MY |
| `status` | 오류·경고·성공 상태 | 상태 토큰만 사용 | 별도 상태 아이콘 |

컬러 기능 아이콘을 단색으로 만들거나, 조작 아이콘을 제각각 컬러 일러스트로 만들지 않는다.

### 3.2 크기는 파일 너비가 아니라 시각 무게로 맞춘다

- 홈 바로가기 터치 영역: 현행 52dp 원형을 유지한다.
- 컬러 아이콘 목표 시각 크기: 약 28–32dp.
- 아이콘마다 투명 여백이 다르므로 모두 같은 `width: 30`으로 끝내지 않는다.
- 기준 시안에서 플레이스·MBTI·산책·운세·퀴즈의 실루엣 면적이 비슷하게 보이도록 optical size를 개별 조정한다.
- 단색 조작 아이콘 기본 크기: 20 또는 24dp.
- 실제 터치 타깃: 최소 44×44dp.

### 3.3 색상·접근성

- 새 임의 HEX를 코드에 추가하지 않는다. 단색 아이콘은 `AppTheme` 또는 `ColorScheme` 토큰만 사용한다.
- 컬러 기능 아이콘은 원본 팔레트를 보존하되, 밝은 회색 원형 배경에서 경계가 사라지지 않는지 확인한다.
- 아이콘만 있는 버튼은 의미가 있는 `Semantics.label`을 제공한다.
- 선택 상태는 색상만으로 구분하지 않고 컨테이너·라벨·굵기 중 하나를 함께 사용한다.
- 장식 아이콘은 중복 읽기를 막기 위해 semantics에서 제외한다.

## 4. 자산·코드 구조 권고안

### 4.1 이름 계약

기능과 행위를 이름에서 구분한다.

```text
assets/images/quick_actions/
  quick_place.png
  quick_mbti.png
  quick_walk.png
  quick_fortune.png
  quick_quiz.png

assets/svg/
  icon_action_back.svg
  icon_action_close.svg
  icon_action_comment.svg
  icon_action_edit.svg
  icon_action_save.svg
  icon_action_settings.svg
  icon_action_share.svg
```

진짜 벡터 SVG를 다시 받는 경우 `quick_*.svg`로 동일한 의미 계약을 유지하고 확장자만 바꾼다.

- 기존 `icon_feed.svg`를 저장 아이콘으로 계속 사용하지 않는다.
- 새 저장 자산은 `icon_action_save.svg`로 분리한다.
- 피드 아이콘은 하단 탭 재기획 전까지 자산만 보관하고 코드에 연결하지 않는다.

### 4.2 공용 렌더러

새 공용 컴포넌트는 최소한 다음 계약을 가진다.

```dart
enum PetSpaceIconTone { mono, originalColor }

class PetSpaceIcon extends StatelessWidget {
  final String asset;
  final PetSpaceIconTone tone;
  final double size;
  final Color? color;
  final String? semanticLabel;
}
```

- `mono`: SVG에만 tint를 적용한다.
- `originalColor`: `colorFilter`를 적용하지 않는다.
- PNG와 SVG를 호출부가 직접 구분하지 않도록 공용 컴포넌트가 형식별 렌더러를 선택한다.
- 단순 문자열 경로 난립을 막기 위해 상수 또는 enum registry를 둔다.
- 기능별 화면에서 `SvgPicture.asset`·`Image.asset`을 반복하지 않는다.

## 5. 구현 순서

### ICON-1A — 자산 정규화와 렌더러

1. 제공 자산을 실제 형식에 맞게 추출한다.
2. 투명 여백과 캔버스를 정리한다.
3. 산책 기록의 두 발자국을 하나의 투명 캔버스로 합친다.
4. 공용 `PetSpaceIcon`과 registry를 추가한다.
5. 16·20·24·32·48dp 렌더 스모크 테스트를 추가한다.

완료 조건:

- 컬러 아이콘은 컬러가 유지된다.
- 단색 아이콘은 라이트·다크 토큰을 따른다.
- 잘못된 파일명과 의미 충돌이 없다.

### ICON-1B — 홈 5개 바로가기

1. `HomeQuickActions`만 새 컬러 기능 아이콘으로 교체한다.
2. 검색·탭·라우팅·잠금/미구현 동작은 바꾸지 않는다.
3. 5개 실루엣의 시각 무게와 간격을 맞춘다.
4. 320px 폭, 일반 폭, 200% 글자에서 잘림을 확인한다.

이 단계가 가장 작은 범위에서 사용자에게 가장 큰 시각적 개선을 준다.

### ICON-1C — 공용 조작 아이콘

우선 공용 또는 반복 사용 컴포넌트만 이관한다.

1. `PetSpaceAppBar`의 뒤로가기
2. 공용 모달/시트의 닫기
3. MY 헤더의 설정
4. 피드 카드의 댓글·공유·저장
5. 공용 작성 진입 버튼

개별 화면의 모든 Material 아이콘을 한 번에 교체하지 않는다. 각 공용 컴포넌트 이관 후 회귀를 확인한다.

### ICON-1D — 하단 5탭

이번 구현 범위에서 제외한다.

홈·건강·AI 분석·피드·MY의 선택/비선택 형태, 중앙 탭 여부, 뱃지 위치를 별도 목업으로 확정한 뒤 정확한 manifest와 사용자 승인을 받는다.

## 6. 비요구사항

- 기능 라우팅, 상태 관리, API, DB, Edge, 운영 데이터는 변경하지 않는다.
- 홈 바로가기 5개 기능의 동작 의미를 바꾸지 않는다.
- 산책 기록 미구현 상태를 아이콘 작업과 함께 기능 구현으로 확대하지 않는다.
- 하단 5탭 UI를 승인 없이 변경하지 않는다.
- 앱 전체 Material 아이콘을 일괄 치환하지 않는다.
- 빨간색을 새 브랜드 주색으로 도입하지 않는다.

## 7. 예상 구현 manifest

아래는 초안이며, 구현 승인 전 실제 파일 해시와 테스트 범위를 포함한 별도 manifest로 확정한다.

### 1A·1B 후보

- 수정:
  - `pjh/pubspec.yaml` — PNG 폴더를 사용할 때만
  - `pjh/lib/features/home/presentation/widgets/home_quick_actions.dart`
- 생성:
  - `pjh/lib/shared/widgets/petspace_icon.dart`
  - `pjh/lib/shared/models/petspace_icon_asset.dart`
  - `pjh/assets/images/quick_actions/quick_place.png`
  - `pjh/assets/images/quick_actions/quick_mbti.png`
  - `pjh/assets/images/quick_actions/quick_walk.png`
  - `pjh/assets/images/quick_actions/quick_fortune.png`
  - `pjh/assets/images/quick_actions/quick_quiz.png`
  - 관련 widget/render 테스트

### 1C 후보

- 수정:
  - `pjh/lib/shared/widgets/petspace_app_bar.dart`
  - `pjh/lib/features/home/presentation/widgets/home_dashboard_header.dart`
  - `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`
  - `pjh/lib/features/my/presentation/pages/my_page.dart`
  - `pjh/lib/features/social/presentation/widgets/post_card_actions.dart`
- 생성:
  - `pjh/assets/svg/icon_action_*.svg`
  - 관련 widget 테스트

## 8. 검증

### 자동 검증

```powershell
# pjh/에서 실행
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

추가 테스트:

- 컬러 자산에 tint가 적용되지 않는지
- 단색 자산에 요청 색상이 적용되는지
- 없는 자산 경로가 테스트에서 실패하는지
- 홈 5개 항목의 라벨과 semantics가 유지되는지
- 320×568, 일반 Android, iOS, 200% 글자에서 오버플로가 없는지

### 사람 검증

- 플레이스·MBTI·산책·운세·퀴즈가 참고 이미지와 같은 기능으로 인식되는지
- 다섯 아이콘의 크기와 시각 무게가 균등한지
- 컬러가 배경과 충돌하거나 과하게 유아적으로 보이지 않는지
- 각 버튼을 눌렀을 때 기존 라우팅·안내가 유지되는지
- 라이트·다크 모드에서 단색 조작 아이콘의 대비가 충분한지

## 9. 위험과 중단 조건

- PNG 내장 SVG가 기기에서 렌더되지 않거나 불필요하게 커지면 즉시 PNG 추출안으로 전환한다.
- 산책 기록 두 자산의 상대 위치가 참고 이미지와 크게 다르면 단일 그룹 export를 추가로 요청한다.
- `icon_feed.svg` 이름을 그대로 바꾸면서 기존 사용처가 깨질 가능성이 있으면 먼저 새 이름을 추가하고 호출부를 단계적으로 이관한다.
- 하단 5탭 또는 AI 분석 보호 범위에 변경이 필요해지면 별도 승인 전 중단한다.
- 기존 기능 라우팅·상태·문구 변경이 필요해지면 아이콘 작업에서 분리한다.

## 10. 사용자 결정

권고 기본안:

1. 홈 5개 바로가기는 제공된 컬러 디자인을 채택한다.
2. 이번 구현은 현재 자료에서 PNG를 추출해 우선 적용하고, 진짜 벡터 SVG는 후속 자산 품질 개선으로 받는다.
3. 단색 공용 아이콘은 엑셀 원본을 24 viewBox·`currentColor` 규격으로 정규화한다.
4. 하단 5탭은 이번에 변경하지 않는다.
5. 1A·1B 실기기 검증 후 1C를 진행한다.

## 11. ICON-1A·1B 구현 결과

2026-07-30 사용자 승인에 따라 홈 바로가기 5종까지만 구현했다.

### 구현 내용

- 사용자 제공 PNG 내장 SVG에서 원본 PNG를 추출했다.
- 모든 자산을 512×512 투명 캔버스로 정규화했다.
- 산책 기록의 두 발자국을 하나의 자산으로 합성했다.
- 컬러 래스터와 단색 SVG를 구분하는 `PetSpaceIcon` 렌더러를 추가했다.
- 홈 바로가기 5종을 컬러 자산으로 교체했다.
- 기존 라우팅·반려동물 선택·미구현 안내 동작은 변경하지 않았다.
- 하단 5탭과 ICON-1C 공용 조작 아이콘은 변경하지 않았다.

### 변경 파일

- `pjh/pubspec.yaml`
- `pjh/assets/images/quick_actions/quick_place.png`
- `pjh/assets/images/quick_actions/quick_mbti.png`
- `pjh/assets/images/quick_actions/quick_walk.png`
- `pjh/assets/images/quick_actions/quick_fortune.png`
- `pjh/assets/images/quick_actions/quick_quiz.png`
- `pjh/lib/shared/models/petspace_icon_asset.dart`
- `pjh/lib/shared/widgets/petspace_icon.dart`
- `pjh/lib/features/home/presentation/widgets/home_quick_actions.dart`
- `pjh/test/shared/widgets/petspace_icon_test.dart`
- `pjh/test/features/home/presentation/widgets/home_quick_actions_test.dart`

### 자동 검증 결과

- 신규 대상 widget test: 5건 통과
- 변경 파일별 `dart analyze`: 모두 통과
- `flutter analyze --no-pub`: 통과, 이슈 0건
- 전체 `flutter test --no-pub`: 901건 통과
- `git diff --check`: 통과

### 남은 사람 검증

- 실제 홈 화면에서 다섯 아이콘의 시각 무게가 균등한지
- 산책 기록 두 발자국 간격과 방향이 참고 이미지와 자연스럽게 일치하는지
- Android·iOS 실제 화면에서 컬러가 흐리거나 번져 보이지 않는지
- 각 버튼을 눌렀을 때 기존 기능 또는 기존 안내가 그대로 동작하는지

실기기에서 이상이 없을 때만 ICON-1C 공용 조작 아이콘 이관을 별도 커밋으로 진행한다.
