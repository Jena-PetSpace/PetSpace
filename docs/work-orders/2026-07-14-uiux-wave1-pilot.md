# 작업지시서: UIUX Wave 1A — 설정·도움말·펫 관리 저위험 pilot

- 상태: Wave 1A 코드·자동 테스트·Claude Fable 5/Codex 최종 리뷰 완료 — 사람 실기기 검증 대기
- 마스터 합의 실행: `20260714-UIUX-master-plan-review-3943`
- 작성: Codex
- 구현: Claude Code (`claude-fable-5`)
- 교차 리뷰: Codex
- 사용자 승인: `docs/DECISION_LOG.md`의 양쪽 합의 범위 단계별 진행 승인 적용
- commit·merge·push·deploy: 금지

## 목표

기능과 문구를 바꾸지 않고 설정·도움말·펫 관리의 첫 화면 묶음을 신뢰도 높은 PetSpace v2 언어로 통일한다. 이 pilot은 전체 전환 전에 공용 page shell, 설정 목록, 상태 표현의 API와 회귀 검증 방식을 확인하는 단계다.

## 사용자 목업 승인 게이트

- 실제 Flutter 코드 구현 전에 설정 홈, 알림 설정, 개인정보 설정, 도움말, 펫 관리의 가시적 목업을 사용자에게 제시한다.
- 사용자가 방향을 최종 승인하기 전에는 아래 9개 manifest 파일을 수정하거나 생성하지 않는다.
- 목업 수정 의견은 먼저 목업과 이 문서에 반영하고, Claude·Codex가 변경된 manifest를 다시 확인한다.
- 사용자 승인 기록 후에만 상태를 `uiux_wave1A_approved_for_implementation`으로 바꾸고 이번 Wave에 승인된 Claude Fable 5 구현을 재개한다.

목업 승인 기록: 2026-07-14, 사용자 승인 완료.

구현 모델 승인 기록: 2026-07-14, 사용자가 `claude-fable-5` 구현을 명시적으로 승인했다. 이번 Wave 1A만 Fable 5로 실행하고 다른 run의 기본 모델은 변경하지 않는다.

## 정확한 변경 manifest

기존 파일 6개만 수정한다.

1. `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
2. `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
3. `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart`
4. `pjh/lib/features/profile/presentation/pages/help_page.dart`
5. `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
6. `pjh/lib/features/pets/presentation/widgets/pet_card.dart`

공용 파일 3개만 새로 만들 수 있다.

7. `pjh/lib/shared/widgets/petspace_page_scaffold.dart`
8. `pjh/lib/shared/widgets/petspace_settings_components.dart`
9. `pjh/lib/shared/widgets/petspace_state_view.dart`

이 목록 밖 코드와 문서는 수정하지 않는다. 특히 `add_pet_bottom_sheet.dart`는 로직과 UI 결합도가 높아 Wave 1B로 분리하며 이번 단계에서는 import와 호출 계약만 보존한다.

## 변경 전 SHA-256

| 파일 | SHA-256 |
|---|---|
| `my_settings_page.dart` | `7961f6f7464ca89ac7c26fe22e174ac5dbe3f71dae3dba97b1a152fb98779aa1` |
| `notification_settings_page.dart` | `bf3d4c15b03dd95125c32b9daebb93022f42d70a96c714efe6880a7def69b8d4` |
| `privacy_settings_page.dart` | `599a5965eeb9ce4ed0f69c89986f7753e31c98432ccedb14161ada5ecc0f2345` |
| `help_page.dart` | `8dd11d4a16cc9981518e936d0ba9f2e2aade8b52eb4060ace6a9ff4459a831e3` |
| `pet_management_page.dart` | `3c2bd44e364b9fae3a0884f7352097e935764815887b1a732ae897757559990f` |
| `pet_card.dart` | `73af49c2d8d7f53f20f6d1eff611f4767e7bc6cc05e30e4250631a99296dd89d` |

기존 파일 hash가 구현 직전에 다르면 멈추고 manifest를 다시 비준한다.

## 보호선과 기준 hash

직접 수정 금지:

- `pjh/lib/features/social/presentation/pages/home_page.dart`: `021681acf3f3c6898e2afebe7ba263dfb703bc9bc1728f450605dad369117269`
- `pjh/lib/features/home/**`: 23개 파일 tree digest `accfb9ffd08e192591ff2c8d909161f8ed86cc0e8f9eab61b429f9fd14e37716`
- `pjh/lib/features/emotion/presentation/**`: 60개 파일 tree digest `bdb555e9845430190481608fd8502b00f176c167e90fd4a2b254106b0c5f6148`
- `/home` 호스트 `pjh/lib/main_navigation.dart`: `bc048d39d03d312a4bfcb117f682dd7282804a699b8a368c383d5dfad1f334cf`
- `pjh/lib/shared/themes/app_theme.dart`
- 기존 `pjh/lib/shared/widgets/**`
- route, BLoC/Cubit, domain, data, Repository, DB, migration, RPC, secrets, legal/archive

새 공용 위젯은 이번 6개 pilot 파일에서만 import한다. 보호 화면에서 import가 생기거나 기존 공용 theme/widget 수정이 필요하면 중단한다.

주의: 마스터 합의 초안의 `pjh/lib/core/navigation/main_navigation.dart`는 실제 경로가 아니다. Wave 0 코드 대조 결과 실제 파일은 `pjh/lib/main_navigation.dart`로 정정한다.

## 진입점과 위험도

| 대상 | 진입/소비 | 상태·부작용 | 위험도 |
|---|---|---|---|
| My 설정 | `/settings/my` | AuthBloc logout/delete, 여러 기존 route 이동, 확인 dialog | medium |
| 알림 설정 | `/settings/notification` | Supabase, SharedPreferences, OS 권한, SocialRepository | medium |
| 개인정보 설정 | `/settings/privacy` | 차단 사용자 조회, SharedPreferences, Supabase | medium |
| 도움말 | `/settings/help` | FAQ 확장, 이메일 launcher, 실패 SnackBar | low |
| 펫 관리 | `/pets` | PetBloc loading/error/content, 상세·추가·수정·삭제 | medium |
| PetCard | 펫 관리 내부 위젯 | 탭, 편집·삭제 callback, 이미지 로딩/실패 | low |

직접 연동 widget test는 현재 검색에서 발견되지 않았다. 따라서 analyzer와 새 공용 위젯/pilot smoke test를 우선하고, 실기기 검증 미실행 항목은 완료로 표현하지 않는다.

## 디자인 계약

- 화면 배경은 `AppTheme.backgroundColor`, 카드·시트는 theme surface를 사용한다.
- 브랜드 헤딩은 `AppTheme.brandDeep`, 주요 action은 `AppTheme.actionBase`, 본문/보조/경계는 `textBody`/`textMuted`/`border` 의미를 따른다.
- 임의 pastel 타일과 장식용 다색 배경을 제거한다. 아이콘은 중립 surface 안의 작은 `actionContainer` 강조만 허용한다.
- 타이포 역할은 title 22, heading 17, body 15, caption 13, micro 11의 기존 v2 의미를 따른다. 본문 전체를 bold로 만들지 않는다.
- 페이지 좌우 20, section 간 24, 항목 간 12, 카드 내부 16을 기본으로 한다. 컴포넌트 필요에 따라 4/8/16/24/32 토큰만 사용한다.
- 입력 8, 카드·버튼 14, 큰 sheet/hero 20의 radius 역할을 따른다.
- 목록 행과 주요 CTA의 최소 터치 높이는 44 이상으로 하고, 아이콘 단독 버튼에는 tooltip 또는 semantic label을 둔다.
- loading, empty, error, content, disabled를 구분한다. offline 판정 로직은 새로 만들지 않는다.
- 라이트·다크에서 Theme의 surface/text를 우선 사용하되 AppTheme 자체는 이번 wave에서 수정하지 않는다.

## 공용 컴포넌트 최소 API

- `PetSpacePageScaffold`: title, body, actions, leading, bottomNavigationBar, floatingActionButton, resizeToAvoidBottomInset 정도만 제공한다.
- `PetSpaceSettingsSection`: 선택적 section title/description과 구분된 child 목록을 제공한다.
- `PetSpaceSettingsTile`: icon, title, subtitle, trailing, onTap, destructive, enabled를 제공하고 44px 터치·semantic grouping을 보장한다.
- `PetSpaceStateView`: loading/empty/error 상태에 title, message, actionLabel, onAction을 제공한다.

공용 API는 비즈니스 상태나 route를 알면 안 되며 pilot에서 필요하지 않은 추상화는 추가하지 않는다.

## 동작 불변 계약

- 모든 route 문자열, callback 연결, BLoC event, Supabase/SharedPreferences key와 호출 순서를 유지한다.
- Auth logout/account delete, 알림 저장·OS 권한, 차단 사용자 조회, 이메일 열기, 펫 추가·편집·삭제·상세 이동의 의미를 바꾸지 않는다.
- 기존 사용자 표시 문자열, 법무·개인정보·수의학 관련 문구는 수정하지 않는다. 시각적 section title이 새로 필요하면 기존 문자열 조합만 사용하고 신규 정책 문구를 만들지 않는다.
- 원시 예외 `$e` 노출, offline manager, 미사용 navigation wrapper, follow stub 등 별도 P0 항목은 고치지 않는다.
- `add_pet_bottom_sheet.dart`, `pet_detail_page.dart`, app router를 수정하지 않는다.

## 구현 순서

1. 신규 공용 위젯 3개를 추가한다.
2. 도움말과 My 설정에 적용해 page/list 계약을 확인한다.
3. 알림·개인정보 설정에 적용하되 로직 메서드 본문은 건드리지 않는다.
4. 펫 관리 shell/state와 PetCard 외관을 적용한다.
5. format/analyze/test/diff/protected hash를 검증한다.
6. Codex가 read-only 교차 리뷰하고 blocker/high 0일 때만 Wave 1A 완료로 처리한다.

## 자동 검증

`pjh/`에서 다음을 실행한다.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test
git diff --check
```

추가 확인:

- 실제 변경 경로가 위 9개 manifest의 부분집합인지 확인
- 보호 4개 hash/tree digest가 모두 동일한지 확인
- route 문자열, preference key, Supabase/Repository 호출, Bloc event가 diff에서 바뀌지 않았는지 확인
- 기존 사용자 표시 문자열 변경이 없는지 diff로 확인
- 새 공용 위젯을 보호 화면이 import하지 않는지 역참조 확인

## 사람 검증 대기

- 360×800, 390×844, 큰 화면
- 글자 크기 100%, 130~150%
- 라이트·다크
- 스크린리더 낭독 순서와 실제 대비
- OS 알림 권한 허용/거부, 이메일 앱 없음, 펫 0/1/다수, 긴 이름·긴 FAQ

기기나 세션이 없어 수행하지 못하면 `사람 검증 대기`로 남기며 자동 검증 성공만으로 실기기 완료라고 쓰지 않는다.

## 중단 조건

- manifest 기존 파일 hash 불일치
- 보호 경로 또는 기존 shared theme/widget 수정 필요
- route, 상태, 저장 key, Repository/DB/API, 인증, 법무·수의학 문구 변경 필요
- 신규 패키지·자산 필요
- Claude와 Codex의 manifest·실행자·완료 조건 불일치
- 신규 blocker/high, analyzer/test 실패, overflow 또는 접근성 악화

## 교차 리뷰 보완 addendum — 2026-07-14

첫 구현 뒤 Claude Fable 5와 Codex의 독립 리뷰 결과 상태는 `changes_required`다. 기능·route·문구 회귀는 없었지만 신규 공용 컴포넌트의 다크모드 Theme 계약과 자동 회귀 테스트를 보완해야 한다.

이번 보완에서 기존 9개 manifest 파일의 추가 수정과 아래 테스트 파일 1개 생성을 허용한다.

10. `pjh/test/shared/widgets/petspace_wave1_widgets_test.dart` (신규)

보완 직전 기준 SHA-256:

| 파일 | SHA-256 |
|---|---|
| `my_settings_page.dart` | `e489c97609f19eb25816a224c6c042d50f5231e64d958c679d8a7f12e5fe12fd` |
| `notification_settings_page.dart` | `551cc907e1240d7fe3359f2e1e7704ad4e4b0fab0f2addc5d98bdd562b363479` |
| `privacy_settings_page.dart` | `3a233dd13fa581d93e73f6f921a17151c4ba8cce5084632ae68311616a0bc2a8` |
| `help_page.dart` | `b46867a0b6e72f146682985b3a44b683a64cd1b33bb1bb72917b166c21a864ab` |
| `pet_management_page.dart` | `ca7c70b6da1d6609dc1159f182de96182fde484966d8a194a19f672423bc86d6` |
| `pet_card.dart` | `6c9437c5e3dcf33b01821ad375006c7b03fab59673dd86389d272bfe650ecdf7` |
| `petspace_page_scaffold.dart` | `d201bf22d6484ec03b301a72bc810a2518f0f178d047f125c37d9fd9e68c3429` |
| `petspace_settings_components.dart` | `f56493e64723c6992d02757a9cbb8bab52d20052a1e79d825356ba76bca9ac58` |
| `petspace_state_view.dart` | `9140770849c09073bdd169f8311fe7170ec6514aa581d105b146c6891d617c68` |

필수 보완:

1. 신규 공용 위젯 3종은 `Theme.of(context)`의 `scaffoldBackgroundColor`, `colorScheme.surface/onSurface/onSurfaceVariant/outlineVariant`를 다크모드 surface·본문·보조·경계에 우선 사용한다. 라이트모드의 기존 PetSpace v2 시각값과 brand/action/error 의미 토큰은 유지한다.
2. `PetCard`와 pilot의 직접 text/surface도 동일한 라이트·다크 원칙을 적용한다. 비즈니스 로직, 표시 문자열, callback은 변경하지 않는다.
3. AppBar 제목은 현재 AppTheme 계약과 기존 앱바 기준인 heading 17을 유지한다. content page title을 새로 추가할 때만 title 22 역할을 사용한다.
4. PetCard popup trigger는 ScreenUtil 축소와 무관하게 최소 44×44 논리 픽셀을 보장한다.
5. 알림 권한의 `설정에서 켜기 →`는 기존 문자열·onTap을 유지하면서 최소 44px 터치 영역과 Material semantics를 갖춘다.
6. 신규 테스트 하나에서 최소한 공용 scaffold/section/state의 라이트·다크 surface/text 선택, loading/empty/error와 action callback, disabled tile tap 차단, 좁은 화면·150% text scale 예외 없음, 44px 최소 영역을 검증한다.
7. 전체 테스트의 기존 14개 실패는 변경 전 baseline과 분리하고, 신규 테스트 및 analyzer는 반드시 0개 실패여야 한다.

보완 뒤 양쪽 read-only 재리뷰에서 blocker/high 0이고 필요한 medium 수정이 남지 않을 때만 Wave 1A를 완료한다.

## 완료 기록 — 2026-07-14

- 최초 구현 run: `20260714-UIUX-wave1A-ratification-d058`
- 보완·최종 승인 run: `20260714-UIUX-wave1A-ratification-db56`
- 구현 모델: `claude-fable-5`
- 최종 리뷰: Claude Fable 5 `approve`, Codex `approve`
- blocker/high/필수 medium: 0건
- 실제 변경: 승인된 기존 6개 화면·위젯, 신규 공용 위젯 3개, 신규 widget test 1개
- `flutter analyze --no-pub`: Fable·Codex 각각 통과
- 신규 `petspace_wave1_widgets_test.dart`: 13/13 통과
- 전체 테스트: 369 통과, 기존 baseline 14 실패, 신규 실패 0
- `git diff --check`: 통과
- 기능·route·상태·저장 key·사용자 표시 문자열: 변경 없음
- 보호 홈·AI 분석·main navigation: 직접 변경 없음
- commit·merge·push·deploy: 수행하지 않음
- 사람 검증 대기: 실기기 크기별 렌더, 라이트·다크 실제 대비, 130~150% 글자, 스크린리더, OS 알림 권한, 이메일 앱 부재, 펫 0/1/다수·긴 콘텐츠
