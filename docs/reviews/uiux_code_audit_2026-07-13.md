# 홈·AI 분석 제외 UI/UX 및 코드 감사 — 2026-07-13

- 상태: Codex 사전 감사 완료, Claude Opus 4.8 교차 검토 대기
- 기준: `win-android-release` HEAD `024d685`, 현재 작업 브랜치 `feature/agent-setup`
- 정적 검증: `flutter analyze --no-pub` — No issues found (49.0초)
- 목적: 폴더 정리 완료 뒤 Claude와 Codex가 동일한 코드 증거로 기획·작업 범위·실행자를 합의하기 위한 입력

## 1. 범위와 보호 화면

직접 수정 금지:

- 실제 `/home` 본체: `pjh/lib/features/social/presentation/pages/home_page.dart`
- 홈 하위 UI: `pjh/lib/features/home/**`
- AI 분석 화면군: `pjh/lib/features/emotion/presentation/**`

`app_theme.dart`와 공용 위젯은 보호 화면에도 영향을 줄 수 있다. 공용 변경은 허용 후보지만, 보호 화면을 직접 고치지 않고 변경 전후 회귀 캡처·테스트가 가능한 경우에만 합의 대상으로 삼는다.

보호 범위를 제외한 페이지 파일은 58개다.

| 기능군 | 페이지 수 |
|---|---:|
| auth | 6 |
| chat | 4 |
| feed_hub | 2 |
| fortune | 1 |
| health | 3 |
| mbti | 2 |
| my | 6 |
| news | 1 |
| onboarding | 9 |
| pets | 3 |
| profile | 6 |
| quiz | 2 |
| social | 13 |

대상 presentation 전체는 180개 Dart 파일, 약 40,275줄이다. 500줄 초과 파일이 16개이며 상위 위험 파일은 온보딩 펫 등록 870줄, 채팅방 설정 858줄, 건강 기록 시트 782줄, 게시글 상세 692줄, 펫 추가 시트 687줄이다. 전 화면을 한 번에 수정하면 리뷰와 회귀 원인 추적이 불가능하므로 단계 분리가 필수다.

## 2. 복구 가능한 기존 레퍼런스

Claude 로컬 프로젝트 컨텍스트에서 확인 가능한 시각 결정은 주로 2026-07-06 홈 화면 피그마·스크린샷 논의다.

- 다색 Material 기본 아이콘 조합은 기성품·바이브코딩 인상을 강화한다.
- Feather/Lucide 계열 단색 선 아이콘과 통일된 선 굵기가 우선안이었다.
- 화면 표면은 연회색 배경 + 흰 표면을 기본으로 하고, 구획은 미세 그림자 카드 또는 8~12px 중립 밴드 중 하나만 쓴다.
- 과한 테두리와 그림자를 동시에 쓰지 않는다.
- Toss식 미니 일러스트·3D 아이콘은 비용이 큰 후속안으로 분류됐다.
- AppTheme v2에서 CTA·링크·활성 상태는 `actionBase #3A6EA8`, 헤딩·브랜드는 `brandDeep #1E3A5F`로 분리됐다.

비홈 화면 전체에 대한 완결된 레퍼런스 패키지나 화면별 매핑은 로컬 대화 기록에서 찾지 못했다. 이미지 첨부 원본도 세션 JSONL에 재사용 가능한 파일로 남아 있지 않다. 1:35 재개 시 Claude Opus 4.8이 기존 프로젝트 컨텍스트를 이어 받아 추가 레퍼런스와 결정이 있는지 다시 확인해야 한다. 확인되지 않은 앱 이름이나 레이아웃을 추측해 기획 근거로 쓰지 않는다.

## 3. 디자인 시스템 감사

### A. 현행 문서가 코드보다 뒤처짐 — High

`app_theme.dart`는 v2 토큰을 사용한다. `brandDeep`, `actionBase`, `backgroundColor #F7F8FA`, radius 8/14/20, 타입 22/17/15/13/11이 코드 기준이다(`app_theme.dart:7-9,28,179-188`). 반면 `DESIGN_BASELINE.md:22-25,40,52`는 배경 `#F8F9FA`, 이전 텍스트 색, 원빨강 오류색, 미정의 타이포 스케일을 기록한다.

판정: 디자인 구현 전에 기준 문서를 v2 코드와 합의 결과로 갱신해야 한다. 구 문서를 기준으로 화면을 고치면 이미 완료된 v2 결정이 역전된다.

### B. 토큰은 있으나 화면 적용 계약이 없음 — High

보호 화면 제외 presentation 코드의 정적 지표:

| 항목 | 발견 수 |
|---|---:|
| `Colors.*` 직접 사용 | 658 |
| 숫자형 `fontSize` | 816 |
| `FontWeight.w700~w900` | 96 |
| 숫자형 `BorderRadius.circular` | 257 |
| 숫자형 `EdgeInsets` | 403 |
| `AppTheme.*` 참조 | 845 |
| `Theme.of(context)` 참조 | 17 |
| `Semantics` | 12 |

토큰 참조가 많아도 숫자형 글자·여백·radius가 함께 남아 화면별 스타일이 갈린다. `Colors.white/transparent/black`처럼 의미가 명확한 예외와 실제 부채를 분류해야 하며, 단순 검색 치환은 금지한다.

### C. lightTheme와 darkTheme가 서로 다른 세대 — High

lightTheme는 v2 타입·버튼·radius를 쓰지만 darkTheme는 18/16 크기, radius 12/16, `primaryColor` 채움 등 이전 규칙이 남아 있다(`app_theme.dart:381,410,424,563`). 전역 디자인 통일은 라이트 화면만 바꾸고 끝낼 수 없다. 다크모드를 한 번에 전면 수정하기 어렵다면 최소한 새 공용 컴포넌트가 양쪽 ThemeData에서 같은 의미 토큰을 사용하도록 계약해야 한다.

### D. 핵심 공용 상태 패턴 부족 — High

공용 Empty/Error/Loading 위젯은 있지만 적용이 균일하지 않다. 접근성은 180개 presentation 파일에서 `Semantics` 12건뿐이다. 다음을 공용 계약으로 고정해야 한다.

- 페이지 shell, app bar, section header
- primary/secondary/destructive button
- text field, selector, chip/filter
- content card, settings row, list item
- loading/skeleton, empty, offline, recoverable error
- bottom sheet/dialog, toast/snackbar
- 44px 이상 터치 영역, text scale, 대비, semantic label

## 4. 코드 신뢰도 감사

### A. 원시 예외가 사용자 문구로 전파됨 — High

보호 경로를 제외한 feature 코드에서 `$e`/`e.toString()` 보간이 280건이며, `failure.message`가 화면 상태나 SnackBar에 직접 연결되는 명확한 경로가 최소 12건이다. 예: 채팅방 나가기·멤버 추가(`chat_room_settings_page.dart:249,677`), 채팅 신고(`chat_detail_page.dart:137,155`), 온보딩 펫 등록과 펫 추가의 이미지·저장 실패 경로.

영향: 서버 주소, 내부 예외, 영어 기술 문구가 사용자에게 노출되면 제품 신뢰와 개인정보·보안 인상이 악화된다. Repository 로그와 사용자 안전 문구를 분리하는 별도 P0 작업지시서가 필요하다.

### B. 오프라인 동기화가 구현된 것처럼 보이는 placeholder — High(현재 미사용)

`offline_manager.dart:117`의 create-post 동기화는 로그만 남긴다. 그런데 호출자는 정상 완료로 보고 큐 항목을 삭제한다(`offline_manager.dart:82`). 현재 외부 사용처는 검색되지 않아 즉시 사용자 데이터 손실 경로는 확인되지 않았지만, 연결되는 순간 조용한 데이터 손실이 된다.

조치 후보: 기능을 연결하지 않을 것이라면 제거하거나 명시적으로 실패시켜 큐를 보존한다. 기능 활성화는 Repository 계약·중복 실행·재시도 정책을 별도 설계한 뒤 진행한다.

### C. 사용되지 않는 구형 내비게이션 구현 — Medium

`shared/widgets/main_navigation_wrapper.dart`는 자기 파일 외 참조가 없다. 실제 앱은 `app_router.dart:266-268`의 `/home`과 `main_navigation.dart`를 사용한다. 구형 래퍼에는 빈 사용자 ID placeholder와 별도 5탭 상태가 있어 잘못 수정할 가능성을 높인다. 참조·테스트·동적 로딩이 없음을 Claude와 재확인한 뒤 정리 후보로 분류한다.

### D. 구조적 부채 — Medium

- `social_repository_impl.dart:607-608`에 중복 `@override`가 있다.
- 팔로우 요청 승인 인터페이스는 자동 승인 스키마에서 항상 “미지원” 실패를 반환한다.
- 500줄 초과 presentation 파일 16개가 UI, 검증, 네트워크 결과 처리, bottom sheet를 한 파일에 섞는다.
- 정적 분석은 0건이지만 이런 의미·구조 부채는 잡지 못한다.

기능 의미나 DB 계약을 바꾸지 않는 순수 분리만 UI wave 안에서 허용하고, offline/follow처럼 동작 의미가 있는 변경은 별도 합의 작업으로 분리한다.

## 5. 권고 디자인 방향

목표 인상은 “차분한 반려동물 건강 기록 서비스 + 따뜻한 생활 커뮤니티”다. 의료기관처럼 차갑거나, 놀이 앱처럼 원색·이모지 중심이 되지 않게 한다.

- 90% 중립 표면, 브랜드 딥블루는 헤딩·선택·브랜드에 제한
- CTA는 steel blue `actionBase`, 코랄은 오류·주의·좋아요 등 제한된 의미
- Pretendard 역할형 5단 스케일, 본문 과도한 bold 금지
- 카드·버튼·입력·칩 radius를 20/14/8 세 단계로 제한
- 페이지 좌우 20, 섹션 24~32, 요소 8/12/16의 기본 리듬을 합의 후 토큰화
- 장식용 그라데이션·다색 타일·이모지를 기본값으로 쓰지 않음
- 정보 위계는 제목 → 핵심 상태 → 다음 행동 순서로 통일
- 오류는 원인 코드가 아니라 “무엇이 안 됐고 무엇을 할 수 있는지”를 표시

## 6. 권고 구현 순서

1. 정리 작업 완료 및 양쪽 교차 리뷰
2. 레퍼런스 복구·화면별 감사표·DESIGN_BASELINE v2 합의
3. 디자인 토큰과 공용 컴포넌트 계약, 보호 화면 회귀 기준 고정
4. 저위험 pilot: profile 설정·help·pets 관리
5. auth/onboarding
6. health/my/profile 나머지
7. feed_hub/social/chat
8. mbti/quiz/fortune/news
9. 전 화면 접근성·다크모드·오류 상태 회귀와 실기기 검증

각 단계는 한 실행자만 수정하고 다른 AI가 교차 리뷰한다. 한 단계에서 blocker/high가 생기면 다음 단계로 넘어가지 않는다.

## 7. Claude 교차 검토 질문

1. 기존 컨텍스트에서 비홈 화면 레퍼런스와 화면별 결정 원본을 더 복구할 수 있는가?
2. 보호할 “AI 분석 화면군”의 정확한 파일 경계가 더 좁거나 넓어야 하는가?
3. v2 브랜드 토큰 중 실기기에서 이미 문제였던 값·컴포넌트가 있는가?
4. pilot 기능군과 실행자를 위 순서로 잡는 데 반대 근거가 있는가?
5. 원시 예외 정리와 죽은 placeholder 코드를 UI 작업과 분리하는 데 동의하는가?

