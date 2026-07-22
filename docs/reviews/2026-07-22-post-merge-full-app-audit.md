# PetSpace 통합 후 전 화면·기능 감사

> 기준 브랜치: `codex/post-merge-full-app-audit-20260722`
> 기준 SHA: `c49a8c4`
> 작성일: 2026-07-22
> 리뷰 방식: Claude/Anthropic 외부 전송 없이 Codex 단독 3-pass
> 판정: **changes_required — 안정화 검증은 통과했으나 출시 전 제품 신뢰도·접근성 보완 필요**

## 1. 범위와 경계

### 포함

- 인증, 비밀번호 재설정, 약관, 온보딩
- 반려동물 등록·편집·관리·공개 프로필
- MY, 프로필, 설정, 알림, 개인정보·차단, 도움말, 법정 문서
- 피드 발견·라운지, 게시물 작성·상세·댓글·좋아요·저장·검색·신고·차단·공유
- 건강 기록, 추이, PDF, 기기 알림 안내
- 채팅 목록·생성·대화·방 설정·신고·차단
- 공용 내비게이션과 이미지 뷰어의 회귀·접근성

### 이번 기획에서 제외

- 홈 탭 화면과 홈 정보 구조
- AI 감정·건강 분석 탭, 결과, 히스토리, 타임라인, 주간 보고
- 홈이 소유한 병원 검색, MBTI, 운세, 퀴즈, 뉴스 화면
- 하단 5탭의 순서, 중앙 AI FAB, 아이콘·라벨 재설계
- 운영 DB/RPC, Edge, APNs, signing, TestFlight, 스토어 배포

설정의 `AI 분석 히스토리`와 온보딩 완료 화면의 AI CTA는 링크가 깨지지 않는지만 확인한다. AI 화면 자체의 문구·UI·기능은 변경하지 않는다.

## 2. 현재 검증 기준선

| 항목 | 결과 |
|---|---|
| `origin/mac-ios-release` | `c49a8c4` push 완료 |
| `flutter analyze --no-pub` | 통과, issue 0 |
| `flutter test --no-pub` | 692/692 통과 |
| `flutter build ios --release --no-codesign --no-pub` | 통과 |
| `git diff --check` | 통과 |
| 비밀 파일 | `secrets.dart` ignored·untracked, 검증용 integration 복사본 제거 |
| 보호 파일 | Apple/OAuth, entitlement, plist, Xcode, Pod, Firebase, K1/H2, `auth.uid()` 관련 변경 없음 |

시뮬레이터는 iPhone 17 / iOS 26.4에서 확인했다. 홈 기본 로드, 건강, 피드, MY, 프로필 편집, 설정, 채팅 목록·새 채팅 진입을 스모크했다. 피드의 레거시 AI confidence 노출과 `HomePage.dispose` 예외는 `c49a8c4`에서 수정·재검증했다.

시뮬레이터 확인 중 테스트 계정에 기본 `예방접종` 건강 기록 1건이 생성됐다. 이는 사용자 삭제 승인 전까지 보존한다.

## 3. 1-pass — 화면·기능·테스트 인벤토리

### 3.1 인증·온보딩

| 화면 | 진입 | 핵심 기능 | 현재 자동 테스트 |
|---|---|---|---|
| Splash | `/splash` | 세션 확인, 다음 경로 결정 | 전용 page test 없음 |
| 온보딩 인트로 | `/onboarding` | 시작 | 없음 |
| 소개 슬라이드 | `/onboarding/slides` | 건너뛰기, 다음 | 없음 |
| 로그인·회원가입 | `/onboarding/login` | Apple/Google/Kakao/Email, 복구 | AuthBloc만 존재, page test 없음 |
| 이메일 인증 | `/onboarding/email-verification` | 코드 확인, 재발송, 취소 | 없음 |
| Kakao 동의 | `/onboarding/kakao-consent` | 필수·선택 동의 | 없음 |
| 약관 동의 | `/onboarding/terms` | 필수·선택 동의 저장 | 없음 |
| 약관 상세 | 내부 push | 문서 열람·동의 | 없음 |
| 프로필 설정 | `/onboarding/profile` | 사진, 표시 이름, 소개 | 없음 |
| 첫 반려동물 등록 | `/onboarding/pet-registration` | 다중 등록, 사진 업로드 | 없음 |
| 튜토리얼 | `/onboarding/tutorial` | 기능 안내 | 없음 |
| 완료 | `/onboarding/complete` | 온보딩 완료 저장, 홈/AI CTA | 없음 |
| 비밀번호 재설정 요청 | `/auth/password-reset/request` | 메일 전송 | 없음 |
| 코드 확인 | `/auth/password-reset/verify` | OTP 확인·재전송 | 없음 |
| 새 비밀번호 | `/auth/password-reset/new-password` | 비밀번호 변경 | 없음 |

핵심 결론: 온보딩·인증 page widget test는 0개다. 현재 692개 전체 테스트 통과만으로 신규·기존·취소·실패·재시도 흐름을 보증할 수 없다.

### 3.2 반려동물·MY·설정

| 화면 | 진입 | 핵심 기능 | 현재 상태 |
|---|---|---|---|
| 반려동물 관리 | `/pets` | 목록, 대표 변경, 등록·상세 | widget test 있음 |
| 반려동물 등록·편집 | `/pets/new`, `/pets/:petId/edit` | 2단계 등록, 사진, 필수·선택 정보 | 상세 widget test 있음 |
| 반려동물 상세 | 내부 push | 신원, 등록일, 편집·삭제 | widget test 있음 |
| 공개 반려동물 | `/pet/public/:petId` | 공개 정보, 팔로우 | 전용 test 없음 |
| MY 메인 | `/my` | 프로필, 내 글, 저장 글 | 상태 test 있음, 탭 접근성 미검증 |
| 내 게시물 | `/my/posts` | 목록·상세 | 전용 test 없음 |
| 저장 허브 | `/my/saved` | 전체·미분류·컬렉션 | widget test 있음 |
| 프로필 편집 | `/my/edit-profile` | 이름, bio, 사진 | widget test 있음 |
| 설정 | `/settings/my` | 계정·정보·탈퇴 | widget test 있음, 실제 AX 역할 미검증 |
| 알림 설정 | `/settings/notification` | 로컬·서버 설정 | widget test 있음 |
| 개인정보·차단 | `/settings/privacy` | 공개 범위, 차단 해제 | widget test 있음 |
| 도움말 | `/settings/help` | FAQ, 지원, 버전 | widget test 있음 |
| 개인정보처리방침 | `/privacy` | 법정 문서 | 전용 test 없음 |
| 커뮤니티 가이드라인 | `/community-guidelines` | 운영 규칙 | widget test 있음 |
| 리워드 스토어 | `/reward` | 포인트·아이템 | 현재 주요 UI에서 숨김, 전용 test 없음 |

### 3.3 피드·소셜

| 화면·표면 | 진입 | 핵심 기능 | 현재 상태 |
|---|---|---|---|
| 피드 허브 | `/feed` | 발견·라운지 전환 | page test 없음 |
| 발견 피드 | 피드 탭 | 추천, 새로고침, 추가 로드 | BLoC·상태 test 다수 |
| 라운지 | 피드 탭 | 카테고리, 커뮤니티 글 | Cubit test만 존재 |
| 사진 게시물 작성 | `/create-post` | 다중 이미지, 캡션, 위치, 임시저장 | page test 없음 |
| 커뮤니티 글 작성 | 내부 push | 카테고리, 본문, 제출 | page test 없음 |
| 검색 | `/search`, `/explore` | 게시물·사용자·태그·통합 결과 | canonical search test 있음 |
| 게시물 상세 | `/post/:postId` | 좋아요, 저장, 댓글, 신고·차단 | widget test 있음 |
| 댓글·답글 | bottom sheet | 작성, 좋아요, 삭제, 실패 복구 | widget test 있음 |
| 좋아요 사용자 | bottom sheet | 검색, 추가 로드, 프로필 | widget test 있음 |
| 저장 컬렉션 | bottom sheet | 컬렉션 선택·해제 | widget test 있음 |
| 전체화면 미디어 | 내부 push | 확대, 다중 이미지, 닫기 | 전용 test 없음 |
| 타인 프로필 | `/user-profile/:userId` | 팔로우, 글, 신고·차단 | widget test 있음 |
| 팔로워·팔로잉 | `/followers/:uid`, `/following/:uid` | 검색, 페이지네이션 | widget test 있음 |
| 해시태그 | `/hashtag/:tag` | 태그 게시물 | widget test 있음 |
| 위치 선택·게시물 | 내부 push, `/location` | 지도·검색·위치 피드 | 위치 게시물 test만 있음 |
| 알림 | `/notifications` | 읽음, 전체 읽음, 딥링크 | model/BLoC test, page test 없음 |
| 채널 구독 | `/channels` | 구독 | 라우트만 보존, 현재 진입점 숨김 |
| 구형 CommentsPage | 직접 route 없음 | 과거 댓글 표면 | canonical bottom sheet와 중복 후보 |

### 3.4 건강

| 화면·표면 | 진입 | 핵심 기능 | 현재 상태 |
|---|---|---|---|
| 건강 메인 | `/health` | pet 전환, 필터, 기록, 추이 | BLoC·위젯 단위 test, page test 없음 |
| 기록 추가·편집 시트 | 건강 메인 | 유형별 입력, CRUD | 저장 계약 test 부족 |
| PDF 미리보기 | 내부 push | 생성·미리보기·공유 | data test 있음, page test 없음 |
| 알림 안내 | `/health/alert-settings` | 권한, 테스트 알림, 준비 중 안내 | widget test 있음 |

### 3.5 채팅

| 화면 | 진입 | 핵심 기능 | 현재 상태 |
|---|---|---|---|
| 채팅 목록 | `/chat` | 로드, 검색, 새로고침, 빈 상태 | widget test 있음, 시뮬레이터 빈 상태 통과 |
| 새 채팅 | `/chat/new` | 사용자 검색, 1:1·그룹 생성 | widget test 있음, 시뮬레이터 빈 상태 통과 |
| 채팅 상세 | `/chat/:roomId` | 텍스트·다중 이미지, 실시간, 실패 복구 | widget/BLoC test 있음, 실제 방 미검증 |
| 방 설정 | `/chat/:roomId/settings` | 이름·사진·멤버·신고·차단·나가기 | widget test 있음, 역할별 실서버 미검증 |

## 4. 2-pass — 기능·UI/UX·안전성 검토

### P0 — 출시 신뢰도

#### P0-AUTH-01 약관 증빙 실패를 조용히 무시함

`terms_agreement_page.dart`는 `saveConsents` 실패를 잡은 뒤 오류 안내·재시도 없이 프로필 단계로 이동한다. 필수 동의를 실제로 저장했다는 증빙과 화면 진행 상태가 어긋날 수 있다.

기획 결정:

- 필수 동의 저장 성공 후에만 다음 단계로 이동한다.
- 실패하면 선택 상태를 보존하고 안전한 인라인 오류와 `다시 시도`를 제공한다.
- 중복 제출을 막고, 저장 중 뒤로 가기·앱 종료 시 재진입 계약을 정한다.
- 약관 버전과 동의 시각은 서버 정본을 유지한다. DB/RPC 변경이 필요하면 별도 작업으로 분리한다.

#### P0-PRIV-01 PII·내부 예외 노출 경계가 일관되지 않음

- 라우터가 사용자 UID를 debug log에 기록한다.
- 로그인·이메일 인증 화면이 이메일·응답·예외 문자열을 log하거나 UI 상태 문자열에 포함할 수 있다.
- 온보딩·반려동물·소셜 repository 일부가 `e.toString()`을 Failure/message로 올려 화면까지 전달할 수 있다.

기획 결정:

- 사용자 메시지는 `error_messages.dart`의 안전한 코드→한국어 매핑만 사용한다.
- UID, 이메일, OAuth URL/token, SQL, storage path, raw exception은 UI와 운영 log에서 제거한다.
- 개발 진단은 redaction된 event code와 stack만 debug/profile 조건에서 남긴다.

#### P0-TEST-01 인증·온보딩 화면 안전망 부재

필수 15화면에 대한 page test가 없다. Apple 이름 1회 제공, OAuth 취소, 이메일 인증 rate limit, 약관 저장 실패, 프로필·펫 업로드 실패, 작은 화면·큰 글자 상태를 테스트로 고정해야 한다.

### P1 — 데이터 무결성·접근성·주 흐름

#### P1-HEALTH-01 빈 예방접종·검진 기록 저장

시뮬레이터에서 모든 사용자 입력을 비운 채 저장했을 때 기본 `예방접종` 기록이 생성됐다. 코드도 예방접종·검진 전용 필드를 필수로 검증하지 않고 유형명을 자동 제목으로 사용한다.

기획 결정:

- 예방접종은 `백신 종류` 또는 명시적 사용자 제목 중 하나를 요구한다.
- 검진은 `병원`, `결과/소견`, 사용자 제목 중 하나를 요구한다.
- 저장 버튼 활성 조건과 필드 오류를 즉시 설명한다.
- 값 없는 기록을 허용해야 한다면 `오늘 예방접종 기록을 추가할까요?` 같은 별도 확인을 요구한다.

#### P1-A11Y-01 실제 AX tree에서 역할·이름 누락

- MY의 아이콘 전용 탭이 `Tab 1 of 2`, `Tab 2 of 2`로만 읽힌다.
- 라운지 `CategoryChip`은 선택 가능한 button/selected 역할이 없다.
- 설정 행은 시각적으로 tappable이지만 Simulator AX에서 button 역할이 안정적으로 노출되지 않았다.
- 전체화면 미디어 닫기 버튼에 tooltip/의미 이름이 없다.
- 보호 범위인 홈 헤더의 검색·알림·채팅 아이콘도 이름이 없었다. 홈 변경은 별도 범위로 이관한다.

기획 결정:

- 모든 아이콘 전용 액션에 한국어 semantic label·tooltip을 부여한다.
- 탭은 `내 게시물`, `저장한 게시물`을 이름으로 제공한다.
- 선택 칩은 button + selected 상태를 노출한다.
- 44pt, 150%/200% text scale, VoiceOver 순서를 자동 테스트한다.

#### P1-PET-01 온보딩 등록과 정본 PetEditor의 이중 구현

온보딩 등록은 855줄의 독립 폼이고, 일반 등록·편집은 `PetEditorPage`와 공용 form widget을 사용한다. 검증·사진 업로드·품종·문구가 쉽게 갈라진다.

기획 결정:

- 화면 전체를 즉시 합치지 않고 필드 모델·검증·사진 업로드 상태부터 공용화한다.
- 온보딩은 `완료/나중에`, 다중 등록이라는 고유 흐름만 소유한다.
- 정본 editor와 같은 이름 길이, 종·품종, 사진 실패 복구 계약을 사용한다.

#### P1-FEED-01 작성·알림·피드 허브 page test 공백

피드 상호작용 하위 컴포넌트는 강하지만 `FeedHubPage`, 두 작성 화면, `NotificationsPage`, `ImageViewerPage` 전용 화면 테스트가 없다. 임시저장 복구, 이미지 권한, 제출 중 중복 방지, 위치 실패, 알림 딥링크가 취약하다.

#### P1-CHAT-01 실제 2계정·실시간 증거 부족

빈 목록과 새 채팅 진입은 시뮬레이터에서 통과했다. 실제 방이 없어 메시지 재전송, 다중 이미지, 읽음 badge, 관리자/일반 멤버 권한, 차단 후 비노출은 자동 test만 확인했다. 두 테스트 계정과 2기기/시뮬레이터 검증이 필요하다.

### P2 — 구조·일관성·제품 명료성

- `/search`와 `/explore`는 canonical SearchPage를 공유하지만 외부 딥링크 호환 목적을 문서화해야 한다.
- `ChannelSubscriptionPage`, `CommentsPage`, `RewardStorePage`는 숨김·중복·휴면 상태를 명시하고 유지/삭제 결정을 해야 한다.
- MY의 MBTI·펫 요약은 상수로 숨겨져 있다. 사용자 가치 검증 전 재노출하지 않는다.
- 대형 page 파일은 기능 wave 완료 후 분리한다. 통합 직후 구조 개편과 UX 변경을 한 commit에 섞지 않는다.
- 문서의 Flutter 3.41.6과 실제 3.41.7 차이를 갱신한다.

## 5. 3-pass — 반대 관점 재검토

### 반론 1: 692개 테스트 통과면 충분하지 않은가

아니다. 온보딩 page test 0개, 실제 OAuth·알림 권한·공유·실시간 채팅은 unit/widget test가 대체하지 못한다. 따라서 `자동 통과 = 출시 준비 완료`로 판정하지 않는다.

### 반론 2: 접근성 수정은 한 번에 전 앱에 적용하면 빠르지 않은가

공용 위젯 3개는 한 wave로 가능하지만, 모든 `GestureDetector` 치환은 행동·hit test를 바꿀 수 있다. 이번에는 실제 재현된 `CategoryChip`, MY 탭, settings tile, image viewer부터 고정하고 화면별 회귀를 확장한다.

### 반론 3: 온보딩 PetEditor를 즉시 하나로 합치면 중복이 사라지지 않는가

온보딩은 다중 임시 목록과 건너뛰기, 일반 editor는 create/edit route data와 PetBloc 수명이라는 다른 계약이 있다. 필드 모델·검증·업로드 상태를 먼저 공용화하고 화면 통합은 후속 결정으로 남긴다.

### 반론 4: 모든 오류를 한 번에 중앙화해야 하는가

원시 예외가 화면에 도달하는 P0 경로부터 막는다. repository 전체의 Failure 재설계는 별도 refactor다. 각 wave는 사용자 노출 경계 test를 추가하고 내부 구조는 필요한 만큼만 바꾼다.

### 반론 5: UI 개선 전에 인증을 먼저 하는 이유는 무엇인가

필수 동의 증빙, 개인정보 log, OAuth 취소·복귀는 법적·계정 신뢰도 문제다. 피드·건강의 시각 업그레이드보다 우선한다.

## 6. 최종 우선순위

1. **W0 인증·온보딩 신뢰도와 테스트 안전망**
2. **W1 공용 접근성·오류 노출 경계**
3. **W2 반려동물·MY 일관성**
4. **W3 피드·소셜 작성/탐색/알림 마감**
5. **W4 건강 기록 데이터 무결성·PDF·알림 UX**
6. **W5 채팅 2계정 실시간 검증과 실패 복구 마감**
7. **W6 휴면 라우트·문서·QA 정본화**

각 wave는 목업/문구 승인, 정확한 file manifest, feature worktree 구현, 집중 test, 전체 test, iOS no-codesign build, 시뮬레이터 캡처, 최종 diff review 순서로 진행한다.

## 7. 아직 완료로 말할 수 없는 항목

- Apple/Google/Kakao 신규·기존·취소·복구 실기기 시나리오
- 2계정 채팅 송수신·읽음·차단·관리자 권한
- iPad share popover와 실제 APNs 알림
- 건강 PDF 실제 한글 렌더·공유 수신 앱 확인
- 테스트 계정에 생성된 예방접종 기록 1건의 삭제
- 동일 `c49a8c4` Android release build와 실기기 회귀

이 항목들은 기능 결함 확정이 아니라 검증 증거 부족이다. 외부 상태 변경·운영 배포 없이 별도 QA 세션으로 닫는다.
