# PetSpace 앱 심사 최우선 준비 중간점검

기준일: 2026-08-18  
기준 브랜치: `mac-ios-release`  
기준 HEAD: `1962aa63625d06f79d1398ef85f6f0191d0d5d31`  
앱 버전: `1.0.0+4`  
주 UI 검증 기기: iPhone 17 / iOS 26.4 Simulator  
판정: **로컬 코드·빌드 준비 PASS / App Store 심사 제출 NOT READY**

## 1. 현재 작업 상태

### 완료·통과

- 로컬 `mac-ios-release`와 `origin/mac-ios-release`는 동일하다.
- B0 안전·디자인 기반이 커밋되어 있다.
  - release FCM/realtime 민감 로그 정리
  - 공개 오류 메시지 정제 기반
  - Android release debug-signing fallback 차단
  - 게시물 visibility fail-closed와 `auth.uid()` 계약
  - 라이트·다크 토큰, 하단 5탭 접근성 기반
- iOS 기본 구성은 로컬 사전점검을 통과했다.
  - bundle ID `com.jena.petspace`
  - Apple 로그인 entitlement
  - release APNs `production`, debug APNs `development`
  - remote notification background mode
  - Privacy Manifest tracking=false와 required-reason API 4종
  - iOS deployment target 16.0
  - iPhone·iPad universal target
- `flutter analyze --no-pub --fatal-infos`: 오류 0건
- 제품 테스트 194개 파일, 1,021개 케이스: 전부 통과
  - 현재 미커밋 변경 자체를 금지하는 과거
    `b0_protected_paths_contract_test.dart` 1파일만 제외했다.
  - 전체 명령에서는 이 파일의 2개 단언만 실패하며 제품 로직 실패가 아니다.
  - 승인된 홈 광고·법적 문서 변경을 커밋한 뒤 전체 명령을 다시 실행해야 한다.
- `dart run tool/release_preflight.dart`: `BLOCKERS=0`
- plist·entitlement·Privacy Manifest 문법: 통과
- `git diff --check`, 충돌 표식 검색: 통과
- iOS release 무서명 빌드: 통과, `Runner.app` 91.8MB
- Xcode 26.4 / iOS SDK 26.4 / Flutter 3.41.7을 확인했다.
- 유효한 로컬 codesigning identity 2개와 알려진 Xcode 위치의 provisioning
  profile 1개가 존재한다. 실제 배포용 서명 archive 성공 여부는 아직 미검증이다.

### 현재 승인된 미커밋 제품 작업

- 공식 지원 이메일 통일
- 빈 광고 플레이스홀더를 실제 동작하는 내부 `플레이스` 추천 배너로 교체
- 배너를 `/hospital`로 연결
- 배너의 단일 접근성 버튼·200% 글자 크기 테스트
- Home 보호 범위 SHA와 계약 테스트 갱신
- 관련 출시 판단·작업지시서 초안

다음 경로는 사용자 소유 설정이므로 제품 커밋에서 제외해야 한다.

- `.codex/config.toml`
- `AGENTS.md`
- `.agents/`
- `.codex/agents/`

## 2. 전체 화면·기능 검증 범위

### 자동·코드 검증

- Presentation page 인벤토리: 80/80, drift 없음
- 같은 경로의 직접 page widget test: 42/80
- feature 테스트 파일: 156개
- 전체 제품 테스트: 194파일 / 1,021케이스 통과
- 작은 화면·큰 글자·overflow·Semantics·44pt 등 UI/접근성 단언을 포함한
  테스트 파일: 62개
- 인증, 온보딩, MY, 반려동물, 피드, 커뮤니티, 댓글, 저장, 팔로우,
  신고·차단, 채팅, 건강, MBTI, 퀴즈, 운세, 뉴스, AI 기록과 서버 계약의
  단위·widget·contract 회귀를 포함한다.

자동 테스트 통과는 실제 Supabase·OAuth·FCM·카메라·사진·위치·공유 시트가
실기기에서 동작했다는 의미가 아니다.

### iPhone 17 실제 UI 확인

로그아웃 상태에서 다음을 직접 확인했다.

- 로그인 단일 배경과 화면 overflow 없음
- 이메일·비밀번호 인라인 검증
- 로그인/회원가입 모드 전환과 회원가입 확인 필드
- 원형 Apple → Google → Kakao 로그인 버튼
- 비밀번호 재설정 화면 진입
- 이메일 미입력·형식 미충족 시 인증 코드 버튼 비활성

발견한 UI 개선점:

1. 로그인에서 오류를 발생시킨 뒤 회원가입으로 전환하면 이전 입력 오류가
   남아 첫 인상을 흐릴 수 있다. 입력 보존 여부와 오류 초기화 규칙을 분리해야 한다.
2. 전역 기획은 장식 이모지 제거를 정본으로 삼지만 현재 presentation source
   25파일, 독립 page 8파일에 이모지가 남아 있다.
3. 직접 화면 테스트가 없는 page 38개는 관련 widget/contract 테스트가 있어도
   실화면 배치·전환·키보드·스크롤을 대체하지 못한다.

### QA 계정·실기기·운영 환경이 없어 미검증

다음은 **통과로 표시하지 않는다**.

- 이메일 신규 가입·실제 메일 수신·OTP·재로그인
- Apple·Google·Kakao 실제 OAuth와 Apple 비공개 이메일 릴레이
- 반려동물 0/1/다견 등록·수정·대표 변경·삭제·복구
- 건강 5종 기록 작성·수정·삭제·PDF 저장·공유
- 감정·건강 AI 실제 업로드·응답·실패·재시도
- 피드 사진 게시글, 커뮤니티 글, 댓글, 좋아요, 저장, 팔로우
- 두 계정 간 신고·차단·차단 해제·검색 결과 제외
- 1:1/그룹 채팅, 사진 전송, 재연결 backfill, 중복 방지
- foreground/background/terminated FCM push와 알림 딥링크
- 카메라·사진·마이크·위치 권한 허용·거부·설정 복구
- Kakao 지도 정상 렌더링과 실패 시 목록 폴백
- Apple 계정 삭제 재인증·token revoke·30일 soft delete·복구·purge
- 실제 iPhone의 VoiceOver, Dynamic Type 200%, 네트워크 단절, 세션 만료
- universal iPad의 회전·Split View·선택기·대화상자

## 3. 제출 전 P0 차단 항목

### P0-1. mac 출시 기준이 Windows 공용 수정 12커밋보다 뒤처짐

`origin/mac-ios-release...origin/win-android-release`는 `0 / 12`다. Windows
브랜치에는 mac B0가 이미 포함되며 다음 공용 출시 변경이 추가되어 있다.

- FCM Vault/runtime 및 알림 route resolver
- Gemini request/proxy 계약
- FCM push 인증 계약
- Supabase release SQL 구조 정리
- Kakao OIDC 사전감사 문서
- release preflight·보호 SHA·관련 테스트 갱신

차이는 70파일이다. Android 전용 파일만 제외하고 공용 Flutter·Edge·Supabase
변경을 의미 검토하여 mac에 반영하기 전에는 iOS 최종 build를 선택하면 안 된다.

### P0-2. 공개 법적 URL이 실제 문서를 제공하지 않음

다음 URL은 모두 HTTP 200이지만 세 응답의 SHA-256이 완전히 동일하다.

- `https://petspace.app/privacy`
- `https://petspace.app/terms`
- `https://petspace.app/support`

개인정보처리방침, 이용약관, 고객지원의 서로 다른 실제 공개 페이지가 필요하다.
비로그인·시크릿 브라우저에서 본문, 시행일, 회사 연락처, 지원 이메일을 확인해야 한다.

### P0-3. 법적 문서와 현재 앱 동작이 불일치

현재 문서는 앱에 없는 다음 처리를 이미 수행하는 것처럼 적고 있다.

- IDFA/광고 식별자 수집과 맞춤형 광고
- 사용자 휴대전화번호 수집
- 결제·신용카드·구독
- 사용자 간 실시간 위치 공유
- 자체 AI 모델 학습과 학습 가중치 귀속

현재 build는 외부 광고 SDK·ATT·IDFA가 없고, 홈에는 내부 플레이스 추천만 있다.
자체 AI도 예정 기능이지 완료 기능이 아니다. 출시 1.0의 실제 데이터 흐름으로
개인정보처리방침·약관·위치약관·App Store Privacy를 다시 맞춰야 한다.

### P0-4. 미완성 기능·스토어 설명 불일치

- 홈의 `산책 기록`은 버튼만 있고 `곧 추가` 안내만 표시한다.
- 자동 건강 예정일 알림은 `준비 중`이다.
- 리워드 스토어는 `오픈 예정`이다.
- 건강 분석 결과의 메모 저장은 다음 업데이트 안내만 표시한다.
- 메타데이터 초안은 `산책과 일상 기록`을 현재 기능으로 설명한다.

가장 빠른 심사 경로는 1.0에서 미완성 진입점을 숨기고 설명에서도 제거하는
것이다. 실제 구현이 완료된 기능만 심사 build와 스크린샷에 노출한다.

### P0-5. Home/AI 잠금 범위에 원문 오류 노출 8파일이 남음

보호 계약은 Home/AI 관련 8파일의 `state.message`, `failure.message`, 예외 문자열
직접 노출을 임시 allowlist로 허용하고 있다. 일부 공유 오류는 `$e`를 사용자에게
표시한다. 출시 전에는 보호 잠금을 제한적으로 해제해 공개 안전 문구로 정리해야 한다.

### P0-6. 운영 백엔드 계약 미증명

로컬 migration·Edge 계약만으로 운영 상태를 증명할 수 없다.

- Apple revoke secret 4종과 탈퇴 Edge
- L1/L2 account purge·access guard
- purge secret, 일별 cron, 실패 알림
- FCM release migration·Vault·push Edge
- Gemini proxy와 실제 AI 공급자 계약
- K1/H2/M1과 `auth.uid()` RPC

운영 DB/Edge에 실제 적용됐는지 확인하고 QA 계정으로 검증해야 한다.

### P0-7. 심사용 계정과 실기기 E2E 없음

로그인이 필수인 앱은 만료되지 않는 심사용 demo account가 필요하다. 별도로
상호작용용 QA 계정 2개를 준비하여 게시·팔로우·차단·채팅·알림을 검증해야 한다.
Simulator는 실제 OAuth, APNs push, Apple revoke, 카메라/위치 권한의 최종
증거가 아니다.

## 4. P1 제출 패키지 준비

- App Store Connect 앱 레코드와 숫자 Apple ID 생성
- 앱의 임시 App Store URL은 현재 404이므로 숫자 ID URL로 변경
- signed Release archive 및 Organizer validation
- SDK privacy manifests, signatures, dSYM 확인
- App Privacy 답변과 공개 privacy URL 게시
- 앱 이름, 부제, 설명, 키워드, 카테고리, 저작권, 지원 URL
- 연령 등급, 콘텐츠 권리, 수출 규정, 판매 지역, 가격, 출시 방식
- 심사 연락처와 demo account, review notes
- iPhone 6.9인치 제출 스크린샷 1~10개
- universal target을 유지하면 iPad 스크린샷과 레이아웃 검증
- 스크린샷은 실제 제출 build와 일치하고 개인정보·근거 없는 `최초`, `무료`,
  `진단`, `정확도` 표현을 포함하지 않아야 한다.

## 5. Codex가 바로 진행할 수 있는 작업

사용자가 다음 단계 실행을 승인하면 아래 순서로 진행할 수 있다.

1. 현재 승인된 홈 배너·지원 이메일 변경만 분리해 커밋하고 전체 1,023개
   단언을 다시 통과시킨다.
2. Windows 12커밋을 read-only 의미 검토한 뒤 mac에 통합하고 공용
   FCM·Gemini·Supabase 계약을 재검증한다.
3. 1.0에서 미완성 산책·자동 알림·리워드·AI 메모 진입을 숨기거나 제거한다.
4. Home/AI 원문 오류 allowlist를 안전 문구로 제거한다.
5. 광고·AI 결정에 맞춘 privacy/terms/location 새 정본과 앱 내 문서를 만든다.
6. `/privacy`, `/terms`, `/support`로 배포할 정적 페이지를 작성하고 호스팅
   접근이 주어지면 배포 전후 내용을 검증한다.
7. App Store Privacy 답변표, 메타데이터, review notes, QA 계정 조건,
   스크린샷 shot list를 최종화한다.
8. QA 계정 2개가 준비되면 80화면·핵심 상태와 실제 상호작용을 iPhone 17에서
   수행하고 결함을 고친다.
9. 실제 iPhone이 연결되면 OAuth·push·권한·지도·탈퇴를 검증한다.
10. signing 환경이 확정되면 archive, Organizer validation, TestFlight용
    산출물을 검증한다.

## 6. 사용자가 직접 해야 하거나 최종 승인할 작업

### 오늘 결정할 것

1. **출시 1.0 광고**
   - 최단 경로 권고: 내부 플레이스 추천만 두고 외부 광고는 1.0.1로 연기
   - 1.0에 광고가 필수라면 광고 공급자, 맞춤형 여부, 출시 국가, 동의 관리
     방식을 확정해야 한다.
2. **자체 AI**
   - 최단 경로 권고: 1.0에서는 현재 검증된 추론 경로만 사용하고 자체 모델
     학습 문구를 제거
   - 자체 AI를 1.0에 넣으려면 입력 데이터, 추론/학습 구분, 보유기간,
     삭제, opt-in을 확정해야 한다.
3. 1.0에서 산책·자동 알림·리워드·미완성 메모를 숨기는 안 승인
4. universal iPad 지원을 유지할지, 첫 출시를 iPhone 전용으로 좁힐지 결정

### 계정·콘솔·법적 책임이 필요한 것

- Apple Developer/App Store Connect 최신 계약과 역할 확인
- App ID `com.jena.petspace`의 Sign in with Apple·Push capability 확인
- App Store Connect 앱 레코드 생성 및 숫자 Apple ID 전달
- APNs 키의 Firebase 연결 확인
- Apple revoke key/secret과 운영 Edge secret 등록
- Kakao Developers iOS bundle ID·Native App Key 연결 확인
- 운영 DB migration·Edge·cron 적용 승인
- 회사명, 주소, 전화, 담당자, 개인정보·위치 책임자 정보 최종 확인
- 법률 책임자의 개인정보처리방침·약관 최종 승인
- 실제 iPhone 제공 또는 연결
- 만료되지 않는 심사용 demo account 1개와 상호작용 QA account 2개 준비
- App Store Privacy, 연령 등급, 가격·판매 지역, 최종 제출 승인
- TestFlight 업로드 및 `Submit for Review` 최종 실행

QA 비밀번호, Apple 키, APNs 키, Firebase 설정, Supabase secret은 Git·문서·채팅에
기록하지 않고 해당 콘솔 또는 App Store Connect 보안 입력란에서만 다룬다.

## 7. 최우선 실행 순서

1. 사용자 결정 4건 확정
2. 현재 승인 변경 분리 커밋 및 전체 테스트
3. Windows 공용 출시 12커밋 통합·회귀
4. 미완성 기능 숨김·원문 오류 제거
5. 법적 문서와 공개 URL 정합화
6. 운영 DB/Edge/APNs/OAuth 계약 활성화
7. QA 계정 2개 + 심사용 demo account 준비
8. iPhone 17 Simulator 80화면 sweep
9. 실제 iPhone OAuth·push·권한·지도·탈퇴 E2E
10. App Store Connect 레코드·Privacy·메타데이터·6.9인치/iPad 스크린샷
11. signed archive·Organizer validation·TestFlight 회귀
12. 사용자 최종 승인 후 심사 제출

## 8. 중단 조건

- 비밀 파일이나 키가 diff·로그·문서에 포함됨
- manifest 밖 사용자 소유 설정이 커밋됨
- K1/H2/M1 또는 `auth.uid()` 계약이 약화됨
- 광범위 `public.users SELECT`나 구형 caller-id RPC가 복구됨
- Apple 로그인·URL scheme·entitlement·iPad shareOrigin이 손상됨
- 새로운 analyze/test/build 실패가 발생함
- 실제 데이터 처리와 법적 문서·App Store Privacy가 불일치함
- 운영 기능을 검증하지 않은 채 통과로 표시함
