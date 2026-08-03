# PetSpace Google Play 출시 준비 현황

> 작성일: 2026-08-03
> Android 기준 브랜치: `win-android-release`
> 기준 커밋: `8b275f17c13c58a055553660d0accc537cb9974e`

## 1. 브랜치와 작업 로직

- `origin/win-android-release`와 `origin/mac-ios-release`는 현재 동일한 기준
  커밋이다. Windows 로컬도 해당 커밋으로 fast-forward 되었다.
- Mac에서 진행 중인 전화면·전기능 UI/UX 감사 결과가 아직 push되지 않았다면
  이 문서의 기준에는 포함되지 않는다.
- 이후 순서는 `Mac 감사 feature → mac-ios-release push → Windows에서 fetch →
  전용 integration worktree에서 win-android-release로 merge → Android 전체 검증 →
  win-android-release push`로 고정한다.
- 같은 파일을 Mac과 Windows에서 동시에 수정하지 않는다. Mac 감사 중인 UI 파일은
  Windows 출시 준비 트랙에서 건드리지 않는다.

## 2. 단계별 현황

| 단계 | 상태 | 완료 조건 |
|---|---|---|
| S0 브랜치 동기화 | 완료 | 두 원격 브랜치와 Windows 로컬의 기준 커밋 확인 |
| S1 정적 출시 감사 | 완료 | analyze/test/preflight, 서명·FCM·인증·AI·DB 계약 점검 |
| S2 보안 차단 해소 | 차단 | 카카오 OIDC 전환, 레거시 분석 Edge 폐기/보호 |
| S3 서명 AAB 생성 | 완료 | 업로드 키로 release AAB 생성 및 서명 확인 |
| S4 콘솔 설정 | 사람 확인 | Play/Firebase/Kakao/Supabase 설정 증빙 확보 |
| S5 내부 테스트 | 대기 | 설치·업데이트·로그인·푸시·AI·삭제 E2E 통과 |
| S6 심사 제출 | 대기 | App content, Data safety, 스토어 등록정보 최종 확인 |
| S7 단계적 출시 | 대기 | 오류율·ANR·Crashlytics 모니터링과 중단 기준 확정 |

## 3. 코드 감사 결과

### 완료 또는 보완 중

- Android 패키지와 namespace는 `com.jena.petspace`, targetSdk는 36이다.
- release 빌드가 업로드 서명 설정 부재 시 debug 키로 대체되지 않고 실패하도록
  fail-closed 처리한다.
- FlutterFire가 등록하는 메시징 서비스를 덮어쓰던 Android manifest의 직접
  `FirebaseMessagingService` 선언을 제거한다.
- FCM은 토큰 갱신, foreground, background entry point, 종료 상태 탭 진입 경로를
  보유한다. 알림 본문과 data가 release 로그에 남지 않도록 제한한다.
- Gemini 키는 앱에 넣지 않고 인증된 Supabase Edge proxy가 보유한다. 프록시에
  요청 크기·허용 필드 제한과 일반화된 오류 응답을 추가하고, 앱의 분석 원문 로그를
  제거한다.
- Windows CRLF 때문에 iOS privacy manifest와 UI 동결 hash가 거짓 실패하지 않도록
  사전점검 입력을 LF 기준으로 정규화한다.
- 로컬 release AAB 생성과 서명 검증을 통과했다. 이 산출물은 아직 Play Console에
  업로드하지 않았으며, 아래 차단 항목 해소 후 새 빌드 번호로 다시 생성한다.

### 출시 차단

1. **카카오 인증 계약**
   - 현재 앱은 카카오 ID와 앱 내 salt로 Supabase 비밀번호를 결정적으로 만들고,
     `confirm_kakao_user_by_email` SECURITY DEFINER RPC로 이메일을 확인한다.
   - 클라이언트에서 추출 가능한 값으로 비밀번호를 재현할 수 있고 RPC가 임의 이메일을
     받으므로 출시 전 Supabase Kakao OIDC로 전환해야 한다.
   - 기존 카카오 사용자의 `auth.users.id`와 연결 데이터를 보존해야 하므로 단순 코드
     교체는 금지한다. 세부 순서는 별도 작업지시서를 따른다.

2. **레거시 `analyze-emotion` Edge function**
   - 요청 body의 `userId`를 service role 쓰기 주체로 신뢰하고, API 실패 시 난수 결과를
     저장할 수 있다.
   - 앱에서 현재 호출하지 않더라도 운영 배포 여부를 확인해 undeploy하거나 인증된
     단일 Gemini proxy로 대체하기 전에는 출시 완료로 판정하지 않는다.

3. **영구 비용 제한**
   - Gemini proxy의 현재 rate limit은 인스턴스 메모리 기반 best-effort다.
   - 내부 테스트에는 사용할 수 있지만 공개 출시 전 사용자·시간창 기반 영구 quota와
     운영 알림을 별도 DB migration으로 설계·승인한다.

## 4. Play Console 준비

### 계정과 테스트 트랙

- 회사 계정이면 조직 정보와 D-U-N-S 검증 상태를 확인한다.
- 2023-11-13 이후 생성한 개인 개발자 계정이면 production access 전에 **12명 이상이
  14일 연속 opt-in한 closed test**가 요구될 수 있다. 조직 계정인지 먼저 확인하고
  해당되는 경우에만 이 일정을 적용한다.
- 첫 업로드는 Android App Bundle(AAB)로 internal testing에 올리고 pre-launch report,
  기기 호환, ANR, 접근성 결과를 확인한다.

### 스토어 등록정보

- 앱 이름, 짧은/전체 설명, 앱 아이콘, feature graphic, 휴대전화 스크린샷을 준비한다.
- 개인정보처리방침 공개 URL, 지원 이메일, 웹사이트, 계정 삭제 공개 URL을 실제 비로그인
  브라우저에서 연다.
- 리뷰 계정 또는 앱 접근 방법을 제공한다. 로그인·위치·카메라·반려동물 등록·AI 분석까지
  심사자가 재현할 수 있어야 한다.

### App content

- 광고 포함 여부, 타깃 연령, content rating, 사용자 생성 콘텐츠/신고·차단,
  위치 권한, 사진/카메라 권한, 계정 삭제를 실제 구현과 일치시킨다.
- Data safety에는 최소한 다음 흐름을 대조한다.
  - Supabase: 인증 식별자, 프로필, 반려동물, 게시물·댓글·채팅, 건강·AI 기록, 위치
  - Firebase: Analytics, Crashlytics, Performance, FCM 토큰과 알림 상호작용
  - Google/Kakao: 소셜 로그인 식별자와 공개 프로필
  - Gemini: 업로드 이미지, 입력 문맥, 분석 결과의 서버 처리와 보관 여부
- “수집하지 않음”은 SDK가 전송하는 진단·분석 데이터까지 확인한 뒤 선택한다.

## 5. 외부 서비스 점검표

### Firebase / FCM

- Firebase Android app package가 `com.jena.petspace`인지 확인한다.
- 업로드 키와 Play App Signing 키의 release SHA 지문을 필요한 Firebase/Kakao 앱에
  각각 등록한다. 지문 값은 문서·로그·Git에 남기지 않는다.
- Android 13 이상 알림 권한: 최초 맥락, 허용, 거부, 재허용을 확인한다.
- foreground 알림 표시, background 탭, terminated 탭, 딥링크, 로그아웃 뒤 토큰 정리,
  재로그인과 token refresh를 실제 기기로 확인한다.

### Supabase / DB

- 운영 migration 목록과 `supabase/petspace_setup.sql` 정본의 schema/RPC signature/RLS
  드리프트를 읽기 전용으로 비교한다.
- `anon`/`authenticated`/service role의 권한 경계를 확인하고 클라이언트가 service role을
  보유하지 않는지 재확인한다.
- migration과 Edge deploy는 코드·구버전 앱 호환 순서를 확정한 뒤 사람이 별도 승인한다.
- 이메일 OTP/재전송/비밀번호 재설정 템플릿, production SMTP, 만료 시간, rate limit을
  실계정으로 확인한다.

### Google / Kakao 로그인

- Google은 release SHA, OAuth Android client, Supabase provider 설정을 signed internal
  build에서 검증한다.
- Kakao는 native app key, Android package, release key hash, Kakao Login/OIDC 동의항목,
  Supabase Kakao provider와 기존 계정 이전을 함께 검증한다.
- 신규/기존/탈퇴 후 재가입/소셜 이메일 중복/취소/네트워크 끊김을 각각 시험한다.

### Gemini

- 로그인하지 않은 요청 401, 과대 요청 413, 잘못된 payload 400을 확인한다.
- 감정·건강 분석 정상/안전 차단/timeout/429/5xx에서 민감 원문이나 서버 내부 오류가
  사용자·release 로그에 노출되지 않아야 한다.
- 호출량·오류율·비용 경보와 영구 quota를 공개 출시 전에 설정한다.

## 6. 내부 테스트 필수 시나리오

1. Play internal track 신규 설치와 이전 build에서 업데이트
2. 이메일 가입·OTP·재전송·로그인·재설정·탈퇴
3. Google과 Kakao 신규/기존 로그인, 취소, 중복 이메일, 로그아웃
4. 반려동물 등록·수정·대표 변경과 앱 재시작 후 유지
5. 카메라/앨범 권한 허용·거부·설정 복귀 후 AI 감정/건강 분석
6. FCM 네 상태: foreground, background, terminated, token refresh
7. 피드·댓글·답글·좋아요·저장·팔로우·차단·신고·채팅
8. 위치 거부/허용/정밀 위치 변경과 플레이스/게시물 위치 기능
9. 계정 삭제 요청, 재로그인 차단, 보존 예외 문구와 purge 운영 경로
10. 네트워크 끊김, 서버 401/403/429/5xx, 앱 재시작과 중복 제출

## 7. 현재 사람이 제공해야 할 정보

- Play Console 개발자 계정이 조직 계정인지 개인 계정인지
- 기존 카카오 계정 수와 공급자/이메일 연결 상태의 익명 집계
- 운영 `analyze-emotion` function 배포 여부와 최근 호출 수(내용 제외)
- Firebase/Kakao/Google/Supabase 콘솔 설정 완료 증빙
- Play 스토어 문구·그래픽·스크린샷 최종본과 리뷰용 계정

## 8. 공식 기준

- Google Play target API 정책: https://support.google.com/googleplay/android-developer/answer/16561298
- 새 개인 계정 테스트 요구사항: https://support.google.com/googleplay/android-developer/answer/14151465
- App content 준비: https://support.google.com/googleplay/android-developer/answer/9859455
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Android App Bundle 배포: https://developer.android.com/studio/publish
- Firebase Flutter FCM 수신: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- Supabase native deep linking: https://supabase.com/docs/guides/auth/native-mobile-deep-linking
- Supabase Kakao Auth: https://supabase.com/docs/guides/auth/social-login/auth-kakao
- Kakao Flutter 로그인: https://developers.kakao.com/docs/en/kakaologin/flutter

## 9. 권한 경계

이번 트랙은 로컬 코드·테스트·문서와 Windows 브랜치 반영까지만 수행한다. 운영 DB
migration, Edge deployment, Firebase/Kakao/Google/Supabase 콘솔 변경, Play 업로드·제출,
실사용자 데이터 조회는 수행하지 않는다.
