# MY Navigation Wave 2 기획 초안

- 작성일: 2026-07-14
- 상태: 검색 확장 포함 Claude Opus 4.8 approve, 최종 사용자 목업 승인 대기, Flutter 구현 미승인
- 상위 감사: `docs/reviews/2026-07-14-my-tab-full-audit.md`
- 선행 완료: MY Core 1 및 실기기 6파일 보정, Codex·Claude 최종 approve, blocker/high 0
- 하단 5탭 UI: 동결

## 1. 이번 기획의 목적

MY 메인 자체가 아니라 MY에서 실제로 이동하는 화면을 사용자 여정 단위로 정리한다. 화면 하나씩 임시로 고치지 않고, 데이터·라우트·복귀 흐름을 공유하는 3~5화면을 한 wave로 묶는다.

이번 초안은 가시적 목업과 다음 구현 작업지시서를 만들기 위한 기준이다. 사용자 목업 승인 전에는 Flutter UI를 수정하지 않는다.

## 2. 실기기 캡처 재리뷰 결론

### 즉시 보정 완료

1. 대표 반려동물의 `대표` 배지를 이름 바로 뒤에 부착했다.
2. 프로필 편집 저장 CTA가 중앙 발바닥 돌출 영역에 가리지 않도록 화면 내부 여백을 확보했다.
3. 반려동물 관리의 대표 설정·작업 성공·오류 안내를 floating SnackBar로 통일해 중앙 발바닥을 피했다.

자동 검증은 analyze 0 issue, 대상 13/13, 영향권 43/43, 전체 417 pass / 기존 실패 14 / 신규 실패 0이다. Claude Opus 4.8 최종 판정은 approve, blocker/high 0이다.

### 다음 기획으로 분리

첨부 4번의 타인 프로필은 `features/social/presentation/pages/profile_page.dart`가 렌더링하는 공용 소셜 표면이다. 현재 문제는 단일 색상 수정이 아니라 프로필 → 팔로워/팔로잉 → 게시물 상세의 정보 위계가 서로 불일치하는 것이다.

## 3. MY에서 이어지는 실제 사용자 여정

| 여정 | 실제 진입 | 핵심 화면 | 현재 판정 |
|---|---|---|---|
| 소셜 정체성 | MY 통계의 팔로워·팔로잉, 목록 사용자 탭 | 팔로워/팔로잉 목록 → 타인 프로필 → 게시물 상세 | **다음 우선순위** |
| 내 콘텐츠 | MY 내 글·저장 그리드 | 게시물 상세, 작성, 피드 복귀 | 게시물 상세를 소셜 정체성 wave와 함께 정돈 |
| 저장 보관함 | MY 저장 탭, 미연결 `/my/saved` | 저장 그리드·컬렉션 | 정본 선택 필요, 별도 wave |
| 계정·지원 | 설정 허브 | 계정 정보, 알림, 도움말, 법무, 로그아웃·탈퇴 | 기능·운영·법무 게이트별 분리 |
| 반려동물 | 설정 허브 `/pets` | 관리·등록·수정·상세 | Core 1 및 실기기 보정 완료, 사람 재검증 대기 |
| AI 기록 | 설정 허브 `/ai-history-page` | 분석 히스토리 | AI 분석 탭 wave로 이관 |

## 4. 권장 다음 단위: MY-N1 소셜 정체성·게시물 여정

한 번에 아래 3화면만 목업한다.

### N1-1. 팔로워·팔로잉 목록

현재 파일: `pjh/lib/features/social/presentation/pages/followers_page.dart`

- 표준 MY 하위 화면 top bar와 2개 segmented tab을 사용한다.
- 상단 tab 아래에 `이름 또는 사용자 아이디 검색` 필드를 둔다. 입력한 검색어는 현재 선택된 팔로워/팔로잉 목록에 적용하고 tab을 전환해도 유지한다.
- 공백 제거·대소문자 비구분으로 `display_name`과 `username`을 검색한다. `@username` 서브타이틀은 값이 있을 때만 표시하되, username이 없는 사용자도 display name으로 검색·표시 대상에 남긴다. 상태 메시지·상호 팔로우 여부를 추정하지 않는다.
- 300ms debounce와 이전 요청 무효화를 적용해 빠른 연속 입력에서 오래된 결과가 새 결과를 덮지 않게 한다.
- 검색어가 비어 있으면 기본 목록으로 복귀한다. `관계 목록 자체가 비어 있음`과 `검색 결과 없음`을 서로 다른 상태와 문구로 표시한다.
- 현재 Repository는 팔로워/팔로잉을 각각 최대 50명만 요청하고 다음 페이지를 UI에 연결하지 않는다. 따라서 로컬 필터만 추가하면 51번째 이후 사용자를 찾지 못하므로 금지한다.
- 기본 목록과 검색 결과 모두 서버 페이지네이션을 사용한다. 정확한 cursor/offset 및 검색 query 계약은 작업지시서에서 data source·repository·presentation을 함께 묶어 확정한다.
- 현재 remote source가 이미 user의 `display_name`과 `username`을 select하므로 새 개인정보 필드를 만들지 않는다. 다만 Follow/UI 모델 전달과 검색용 repository 계약 확장은 사용자 구현 승인 후 별도 manifest에 포함한다.
- 구현 작업지시서에는 다음 세 계약을 필수로 확정한다.
  1. `Follow` 또는 전용 UI 모델에 username을 전달하고 remote → repository → presentation에서 보존
  2. `follows → users` 임베디드 검색의 inner join/filter 또는 전용 RPC 중 하나를 코드·테스트로 선택
  3. 현재 사용되지 않는 `lastUserId`를 그대로 믿지 않고 `follows.created_at` 기반 안정적 keyset cursor와 동률 tie-breaker를 정의
- 사용자 사진이 없을 때는 표시 이름 첫 글자 fallback으로 통일한다. 사람 아이콘·paw·emoji를 사용자마다 임의로 섞지 않는다. 반려동물 사진 없음은 별도로 paw fallback을 유지한다.
- 탭의 개수와 `프로필 보기` 보조 문구는 이미 불러온 목록을 설명하는 presentation 값이며 새 사용자 데이터가 아니다.
- 행 전체가 프로필 진입 액션이며 최소 44px 터치 영역을 보장한다.
- loading, followers empty, following empty, error/retry를 서로 구분한다.
- 기본 첫 조회, 기본 추가 조회, 검색 첫 조회, 검색 추가 조회, 검색 결과 없음, 검색 오류/retry를 테스트한다. 추가 조회 실패는 이미 보이는 결과를 지우지 않는다.
- 내부 예외 원문을 노출하지 않는다.
- 목록 화면에 새 팔로우 버튼·검색·정렬은 만들지 않는다. 이는 현재 화면 기능 계약에 없다.

### N1-2. 타인 프로필

현재 파일: `pjh/lib/features/social/presentation/pages/profile_page.dart`

- 첨부 4번의 큰 파란 gradient hero를 제거하고 표준 top bar + compact identity로 전환한다.
- 사진, 표시 이름, 실제 username, 실제 bio만 노출한다. username과 bio가 없으면 대체 문구를 만들지 않고 해당 줄을 숨긴다.
- 게시글·팔로워·팔로잉 통계를 한 줄로 유지하고 해당 목록 진입 의미를 분명히 한다.
- 팔로우/팔로우 중은 같은 위치에서 상태만 바뀌며, 팔로우 중을 disabled처럼 회색 처리하지 않는다.
- 메시지는 보조 outline/icon 액션으로 유지한다. 전송 중 상태와 실패를 구분한다.
- 게시물 그리드는 사진, 감정 분석 배지, 다중 이미지 표시를 유지한다.
- 이미지 없는 게시물은 임의 원색 한 글자 블록 대신 중립 텍스트 미리보기로 표시한다.
- 게시물이 1개뿐인 sparse 상태는 자연스러운 여백으로 두되 거대한 hero와 결합해 화면이 비어 보이지 않도록 위계를 압축한다.
- profile loading/error, posts loading/empty/error를 분리한다. 현재 `UserPostsList`가 조회 실패를 empty로 바꾸는 문제는 구현 작업지시서에서 필수로 닫는다.
- 현재 타인 프로필의 내부 팔로워·팔로잉 TabBarView는 제거하고 통계 탭이 정본 `FollowersPage`로 이동하게 한다. 따라서 inline follow 조회의 error→empty 혼합도 함께 제거한다.
- `ProfilePage`는 본인/타인이 공유하는 파일이다. 본인 분기는 cover 편집, 프로필 편집, 설정, 본인 pet switcher를 보존하며 이번 타인 프로필 목업 때문에 기능을 잃지 않는다.
- 현재 타인 분기에도 pet switcher와 `/emotion-timeline` 진입 코드가 있으나 공개 pet RLS·분석 공개 정책이 성립하지 않는다. 타인 분기에서는 이를 의도적으로 숨기고, 본인 분기만 보존하는 것을 이번 목업 승인 항목으로 올린다.
- 타인 프로필의 상단 overflow 메뉴는 현재 기능에 없으므로 새로 만들지 않는다. 신고·차단은 별도 운영/기능 계약 wave 전까지 추가하지 않는다.

### N1-3. 게시물 상세

현재 파일: `pjh/lib/features/social/presentation/pages/post_detail_page.dart`

- MY 내 글·저장 글·타인 프로필 그리드에서 같은 상세 화면으로 진입한다.
- 표준 top bar, 작성자, 본문/미디어, 감정 분석 요약, 좋아요·댓글, 댓글 목록, 입력 순서로 위계를 통일한다.
- 기존 좋아요, 답글, 댓글 생성·삭제, 다중 이미지, 감정 insight 의미를 보존한다.
- 게시물 자체 loading/error/not-found와 댓글 loading/empty/error를 서로 구분한다.
- 댓글 입력은 키보드와 중앙 발바닥 돌출 영역 양쪽에서 가리지 않아야 한다.
- 현재 상세 화면의 AppBar에는 overflow 메뉴가 없다. 이번 목업에도 새 ellipsis·신고·차단·삭제 메뉴를 추가하지 않는다.
- 피드 카드 등 다른 표면의 권한별 메뉴를 상세 화면으로 옮기지 않는다. 운영/법무 문구를 새로 만들지 않는다.
- 실제 감정 게시물은 단순 배지보다 풍부한 `이 사진의 AI 감정분석` 요약과 전체 추이 진입을 제공한다. 목업에서도 label 중심 요약을 보여주고 confidence를 새로 노출하지 않는다.
- 게시물 작성자와 댓글 작성자도 사용자 정체성이므로 사진이 없으면 표시 이름 첫 글자를 사용한다. 반려동물용 paw fallback과 구분한다.
- 승인된 정본에 없는 AI·수의학·법무 안내 문구를 목업이나 구현에서 새로 만들지 않는다.

## 5. N1 목업 상태

사용자에게 보여줄 목업은 다음 세 장을 한 화면에서 비교 가능하게 만든다.

1. 팔로워 목록 loaded
2. 타인 프로필 following + 게시글 1개 sparse
3. 게시물 상세 + 댓글 loaded

목업은 구조·밀도·위계 승인을 위한 것이며 실제 사용자 사진이나 신규 기능을 약속하지 않는다. loading/empty/error 상세 상태는 작업지시서와 테스트 매트릭스에서 확정한다.

팔로워·팔로잉 목업의 검색창은 4개 예시 행을 대상으로 동작을 보여주는 presentation 시연일 뿐 구현 계약이 아니다. 구현에서는 현재 50명 제한 목록의 로컬 필터로 축소하지 않고 서버 검색·페이지네이션 계약을 함께 승인받는다.

## 6. 후속 wave

### MY-N2 저장 보관함

- MY 내부 저장 탭과 미연결 `MySavedPostsPage` 중 하나를 정본으로 선택한다.
- 컬렉션을 채택할지 단일 저장 그리드로 유지할지 제품 결정을 먼저 받는다.
- loaded/empty/error/offline, 저장 해제 후 복귀 위치를 설계한다.

### MY-N3 계정·지원

- 계정 정보는 AlertDialog보다 표준 read-only 상세 또는 간결한 sheet 중 하나로 통일한다.
- 알림 설정은 서버 발송 경로가 선호도를 실제 적용한 뒤 UI 완료 판정을 한다.
- 도움말의 FAQ, 지원 이메일, 버전은 운영 가능한 정본 확인 후 수정한다.
- 개인정보처리방침은 법무 정본을 바꾸지 않고 렌더링 UI만 정돈할 수 있다.
- 커뮤니티 가이드라인·회원탈퇴는 SLA, 차단 효과, 30일 soft delete와 문구가 합의되기 전 자동 수정하지 않는다.

### MY-N4 보류

- 공개 반려동물 프로필: RLS·공개 필드·딥링크 선행
- 개인정보 스위치: 서버 접근/검색 계약 선행
- 리워드·뱃지·MBTI: 제품 출시 결정 선행
- AI 분석 히스토리: AI 분석 탭 wave로 이관

## 7. N1 구현 전 필수 게이트

1. Codex 3화면 목업 초안
2. Claude Opus 4.8 독립 목업·기획 리뷰
3. 사용자 목업 최종 승인
4. 정확한 source/test manifest와 기준 hash
5. Codex 작업지시서 초안, Claude 독립 리뷰
6. 사용자 구현 승인
7. 구현 → format/analyze/target/affected/full baseline/diff/protected hash
8. Codex·Claude 독립 최종 리뷰
9. 사람 실기기 검증

## 8. 불변 범위

- 하단 5탭 UI와 `main_navigation.dart` 수정 금지
- 홈·감정 분석 보호 경로 수정 금지
- routing/state/data/API/DB/RLS/법무/운영 계약을 목업만으로 변경 금지
- commit, merge, push, deploy, 운영 DB 작업 금지
- N1 목업 승인 전 Flutter UI 코드 수정 금지

## 9. 현재 권고

MY 다음 구현 순서는 **팔로워·팔로잉 목록 → 타인 프로필 → 게시물 상세**가 가장 적절하다. 세 화면은 하나의 진입·복귀 흐름이고, 첨부 4번에서 드러난 시각 불일치와 MY 통계의 실제 이동 경험을 동시에 닫는다. 설정·저장·AI 기록을 같은 manifest에 섞지 않는다.

## 10. Claude Opus 4.8 독립 목업 리뷰

- 1차: batch coherent, 범위 분리 pass. 현재 코드에 없는 profile/post detail ellipsis가 신규 신고·차단 기능처럼 읽히는 high 1건을 발견했다.
- 반영: 두 ellipsis 제거, 본인 `isMyProfile` 분기 보존, 타인 inline follow 탭 정본화, 타인 pet/AI 노출 보류, username/bio 조건부 표시를 명문화했다.
- 2차: `approve`, blocker/high 0, 세 화면과 범위 분리 모두 pass, 사용자 승인용 준비 완료.
- 추가 정리: 사용자 avatar는 표시 이름 첫 글자, pet avatar는 paw로 의미를 분리하고 승인되지 않은 AI 참고 문구를 제거했다.
- 최종 확인: `approve`, blocker/high 0, cleanup items closed, findings 0, 사용자 목업 승인 요청 가능.

## 11. 사용자 제안 반영: 대규모 팔로우 검색

- 사용자 판단: 수십·수백 명의 팔로워·팔로잉을 한 명씩 찾는 것은 불가능하므로 검색이 필요하다.
- 코드 대조: 현재 repository는 remote source를 `limit 50, cursor null`로 한 번만 호출하므로 로컬 필터는 51번째 이후 사용자를 검색하지 못한다.
- Codex 반영: tab 아래 이름/사용자 아이디 검색, search-empty, debounce, stale response 방지, 기본·검색 pagination을 기획에 추가했다.
- Claude Opus 4.8: `approve`, blocker/high 0, local-only search rejected, server search+pagination required, mockup search pass, 사용자 승인 요청 가능.
- 구현 전 필수 medium: username 모델 전달, embedded user 검색 방식, `follows.created_at` keyset cursor와 dead `lastUserId` 정리. 본 문서 N1-1의 필수 작업지시서 계약에 반영했다.
