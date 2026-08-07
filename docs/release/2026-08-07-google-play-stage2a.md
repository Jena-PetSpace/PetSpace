# Google Play 출시 Stage 2A

> 기준일: 2026-08-07
> 기준 브랜치: `feature/play-release-stage2a-20260805`
> 상태: 로컬 코드·AAB 검증 완료, Play Console 저장·업로드·제출 대기

## 1. 결론

- Android 출시 버전은 `1.0.0+5`로 세 정본(`pubspec.yaml`, `AppConfig`, Gradle)이 일치한다.
- 사용하지 않는 `RECORD_AUDIO` 권한은 병합 매니페스트에서 제거됐다.
- 서명된 release AAB 생성, 서명 무결성 확인, 정적 분석 및 전체 테스트를 통과했다.
- 현재 코드 사전점검 blocker는 `KAKAO_AUTH_CONTRACT`와 `ANDROID_PHOTO_PERMISSION_POLICY` 2건이다. 두 항목을 닫기 전에는 프로덕션 제출하지 않는다.
- 사진 권한은 기능상 사용 중이지만 Google Play Photo and Video Permissions 정책 관점에서 광범위 권한을 유지할 근거가 부족하므로 Android 시스템 Photo Picker 이관을 제출 전 필수 작업으로 둔다.
- Play Console 변경, AAB 업로드, 검토 제출, 공개 웹사이트 수정은 이 단계에서 수행하지 않았다.

## 2. 빌드 산출물과 검증 근거

| 항목 | 결과 |
| --- | --- |
| applicationId | `com.jena.petspace` |
| versionName / versionCode | `1.0.0` / `5` |
| targetSdk | API 36 |
| AAB | `pjh/build/app/outputs/bundle/release/app-release.aab` |
| AAB 소스 커밋 | `7201beb0528db62a1ab8b1cce55c2ed9eb19ee40` |
| 크기 | 97,271,195 bytes |
| SHA-256 | `3468654B8921224B98E24FC98989BAF77629E0E8F39A73AAF0F3638069A0E261` |
| 일반 서명 검증 | `jarsigner -verify`: 통과 (`jar verified`) |
| strict 서명 검증 | 무결성 오류 없음. 자체 서명 업로드 인증서, 타임스탬프 없음, POSIX 속성 경고만 존재 |
| 병합 매니페스트 | `pjh/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`; versionCode 5, `RECORD_AUDIO` 없음. AAB 빌드 시 Gradle up-to-date 입력으로 재사용됨 |
| 정적 분석 | `flutter analyze --no-pub`: 문제 없음 |
| 출시 사전점검 테스트 | 보완 전 20개, 현재 검사 트리 26개 통과 |
| 전체 Flutter 테스트 | AAB 앱 코드 기준 1,039개 통과. 현재 검사 트리의 Claude 재실행은 1,043개 통과 후 `verify_uiux_scope_test` 1건이 30초 timeout. 해당 도구 테스트를 단독 재실행해 3개 모두 17초 내 통과했으므로 앱 회귀가 아닌 전체 병렬 실행 시의 시간 예산 문제로 분리 기록 |

`jarsigner -verify -strict`의 경고는 Android 업로드 키에서 일반적으로 예상되는 인증서 체인·타임스탬프 경고다. `jar verified`가 확인됐으므로 AAB 변조나 미서명으로 판정하지 않는다. 실제 Play App Signing 인증서는 Play Console 업로드 뒤 별도로 확인한다.

## 3. 권한 정밀 감사

### 3.1 마이크

- 앱에서 음성 녹음을 사용하지 않는다.
- 카메라는 `enableAudio: false`인 이미지 촬영 경로만 사용하고 동영상 녹화 API를 사용하지 않는다. 사전점검이 이 전제를 검사한다.
- `android.permission.RECORD_AUDIO`를 `tools:node="remove"`로 명시 제거했다.
- release 병합 매니페스트에서 권한이 사라졌음을 확인했다.

### 3.2 사진·동영상

현재 선언:

- Android 13 이상: `READ_MEDIA_IMAGES`
- Android 12 이하: `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`)
- Android 9 이하 호환: `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=28`)
- 동영상 권한은 선언하지 않는다.

현재 사용 근거:

- 프로필, 게시물, 채팅, AI 분석 이미지 선택에 `image_picker`를 사용한다.
- 공용 이미지 선택기, 권한 헬퍼, AI 분석 화면에서 `Permission.photos`를 직접 확인하거나 요청한다.

판정:

- 기능적 근거는 있으나 사진 접근이 앱의 핵심 상시 기능이라기보다 사용자가 선택할 때만 필요한 흐름이 많다.
- 따라서 Play 제출 전에 Android Photo Picker 기반으로 전환하고 광범위 미디어 읽기 권한을 제거하는 것을 기본 필수안으로 한다. 예외적으로 권한을 유지하려면 Play 사진·동영상 권한 선언 양식에서 지속적·핵심 용도를 입증하고 승인을 확보해야 한다.
- 이 Stage 2A에서는 감사만 수행했으며 동작 변경은 하지 않았다.

### 3.3 광고 ID

- 앱에 광고 SDK나 광고 게재 기능은 없다.
- Firebase Analytics, Crashlytics, Performance가 포함돼 있고 release 병합 매니페스트에는 종속 SDK가 추가한 `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`이 존재한다.
- 현재 구성으로 제출한다면 Play Console 광고 ID 질문은 `예`, 목적은 `분석`을 선택한다. 다만 타깃 연령에 13–15를 포함하면 Families 정책에 맞춰 AAID 수집 비활성화 또는 연령 게이트가 선행돼야 하므로 연령 결정과 함께 재확정한다.
- 광고 ID를 전혀 쓰지 않는 방향을 선택할 경우 Firebase 설정과 수집 동작을 확인한 뒤 권한 제거를 별도 구현·회귀 검증한다.

## 4. Data Safety 근거표 초안

최종 답변은 Play Console 화면과 배포된 백엔드 설정을 다시 대조한 뒤 저장한다.

| 데이터 유형 | 수집/처리 | 계정 연결 | 목적 | 제3자 공유 판단 | 주요 처리 위치·근거 |
| --- | --- | --- | --- | --- | --- |
| 이메일·사용자 ID | 수집 | 예 | 계정 관리, 인증 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | Supabase Auth |
| 닉네임·프로필 사진·소개 | 수집 | 예 | 앱 기능, 소셜 프로필 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | `public.users`, Storage |
| 반려동물 프로필·건강 기록 | 수집 | 예 | 반려동물 관리 기능 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | pets, health records |
| 사진 | 수집·처리 | 예 | 프로필, 게시물, 채팅, AI 분석 | 미확정 — AI 분석 사진을 Google Gemini API로 전송. 적용 요금제·약관 확인 필요 | Storage, 저장소 기준 인증형 Gemini Edge 프록시(운영 배포는 제출 전 확인) |
| 게시물·댓글·채팅·신고 내용 | 수집 | 예 | 소셜 기능, 안전·운영 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | Supabase DB/Storage |
| 정확한 위치 | 선택 시 수집 | 예 | 장소 검색·장소 첨부 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | 게시물 `location_lat`, `location_lng` |
| 대략적인 위치 | 선택 시 수집 | 예 | 주변 장소 검색·장소 첨부 | 미확정 — Supabase 서비스 제공자 예외·계약 확인 | `ACCESS_COARSE_LOCATION`, `Permission.locationWhenInUse`, `LocationAccuracy.low` 경로. 정확한 위치와 별도 Console 항목으로 선언 검토 |
| 앱 활동 | 수집 | 기기/계정 상황에 따라 연결 | 분석 | 미확정 — Firebase Analytics 약관 확인 | Firebase Analytics |
| 충돌·성능 진단 | 수집 | 기기/세션 상황에 따라 연결 | 앱 안정성 | 미확정 — Firebase Crashlytics/Performance 약관 확인 | Crashlytics, Performance |
| 기기 또는 기타 ID(FCM 토큰·광고 ID) | 수집 | 예 | 앱 기능(서비스 알림), 분석 | 미확정 — Firebase Cloud Messaging/Analytics 서비스 제공자 예외·약관 확인 | FCM 토큰은 `user_devices.user_id`와 연결해 저장. Analytics의 AAID 수집이 기본 활성이고 release 매니페스트에 AD_ID 권한 존재. 선택적 마케팅 동의는 저장하지만 `1.0.0+5`에는 서버 측 마케팅 발송 경로 없음 |

추가 원칙:

- 사람의 의료·건강 데이터가 아니라 반려동물 기록이다.
- 저장소 기준으로 Gemini 키는 앱에 포함하지 않고 인증·크기·출력·안전 제한이 있는 Supabase Edge 프록시를 사용한다. 실제 운영 프록시와 레거시 함수 상태는 제출 전 별도 확인한다.
- 저장소에는 계정 삭제 30일 유예·영구 삭제 계약과 위치 접근 기록 6개월 보존 예외가 구현돼 있다. 운영 migration·Edge 배포·일일 스케줄은 아직 확인되지 않았으므로 Data Safety 저장 전에 검증한다.
- 비밀번호 원문을 앱의 데이터 수집 항목으로 주장하지 않는다. 인증 제공자가 전송·검증하며 앱은 저장된 평문 비밀번호를 열람하지 않는다.
- 전송 중 암호화: `예` 권고. Android는 cleartext 통신을 차단하고 서비스 통신은 HTTPS를 사용한다. 최종 AAB와 실제 endpoint를 제출 전에 재확인한다.
- 사용자 데이터 삭제 요청: `예` 권고. 앱 내 계정 삭제 진입점과 30일 유예 계약이 있으나, 공개 삭제 URL과 운영 purge 스케줄 검증이 완료돼야 Console에 저장한다.

## 5. Play Console App content 답변 초안

| 질문 | 권고 답변 | 근거/주의 |
| --- | --- | --- |
| 광고 포함 | 아니요 | 광고 SDK·광고 화면 없음 |
| 앱 액세스 | 제한된 기능 있음 | 로그인 후 주요 기능 접근. 심사용 계정과 경로 제공 |
| 콘텐츠 등급 | 설문 필요 | UGC, 댓글, 채팅, 신고·차단 기능을 사실대로 선택 |
| 타깃 연령 | 미확정 — 제출 차단 | 현 약관은 만 14세 이상을 허용하지만 Play 구간은 13–15로 묶인다. 14–15세를 유지할지 최소 연령을 16세로 올릴지 결정 후 약관·가입 게이트·미성년 UGC/광고 ID 정책을 정렬 |
| Data safety | 본 문서 표를 기준으로 입력 | Console 용어와 실제 SDK 설정 재대조 |
| 광고 ID 사용 | 현재안: 예 — 분석 | Data Safety의 통합 `기기 또는 기타 ID` 행과 동일 결론. 13–15 타깃 시 AAID 비활성화·연령 게이트 결정 후 재확정 |
| 정부 앱 | 아니요 | 민간 서비스 |
| 금융 기능 | 없음 | 결제·대출·투자 기능 없음 |
| 건강 앱 | 아니요 | 사람 의료 앱이 아님. AI 결과는 반려동물 참고 분석이며 진단이 아님 |
| 사진·동영상 권한 | 현재 광범위 사진 권한 존재, 미완료 | 제출 전 Photo Picker 이관·권한 제거가 기본안. 유지하려면 Play 사진·동영상 권한 선언 양식 승인 필요 |

## 6. 심사용 계정 계획

- 실제 사용자 개인정보가 없는 전용 심사 계정을 만든다.
- 이메일 인증을 완료하고 테스트용 반려동물 1마리를 미리 등록한다.
- 운영 이메일 인증·재발송 검증 게이트를 먼저 통과한 뒤 심사용 계정을 만든다.
- Play Console의 App access 영역에만 ID·비밀번호를 입력하며 Git, 문서, 이슈, 로그에는 기록하지 않는다.
- 심사 경로를 함께 제공한다.
  1. 이메일 로그인
  2. 반려동물 프로필 확인
  3. AI 분석 화면과 저장 기록 확인
  4. 피드 게시물·댓글·저장 확인
  5. 채팅, 신고, 차단 확인
  6. 설정에서 개인정보처리방침과 계정 삭제 진입 확인
- OTP, 지역 제한, 추가 인증 등 심사를 막는 조건이 있다면 우회가 아닌 재현 가능한 정확한 절차를 제공한다.
- AI 분석 경로는 운영 Gemini 프록시와 레거시 `analyze-emotion` 종료 상태를 확인한 뒤 심사 절차에 포함한다.

## 7. 스토어 등록 문구 초안

### 앱 이름

`펫페이스(PetSpace)`

### 짧은 설명

`반려동물의 일상·건강 기록과 AI 분석, 소통을 한곳에서 관리하세요.`

### 전체 설명

펫페이스는 반려동물의 일상과 건강 기록을 한곳에서 관리하고, 보호자들이 서로 경험을 나눌 수 있는 반려동물 통합 플랫폼입니다.

- 반려동물 프로필과 건강 일정 관리
- 사진 기반 AI 감정·건강 참고 분석
- 분석 기록과 변화 흐름 확인
- 반려동물 동반 장소와 주변 시설 탐색
- 게시물, 댓글, 저장, 팔로우와 채팅
- MBTI, 오늘의 운세, O/X 퀴즈 등 즐길 거리

AI 분석 결과는 반려동물을 이해하기 위한 참고 자료이며 수의학적 진단을 대신하지 않습니다. 이상 징후가 있거나 건강이 걱정될 때에는 수의사와 상담해 주세요.

### 분류·연락처 초안

- 카테고리: 라이프스타일
- 지원 이메일: `jera.00003@gmail.com`
- 기존 법무 문서의 다른 연락처 표기는 공개 페이지 수정 승인 뒤 하나의 지원 이메일로 통일한다.
- 개인정보처리방침 URL: 공개 페이지 접근성과 실제 문구를 제출 전 재검증
- 계정 삭제 URL: 현재 별도 공개 웹 경로 확인 필요

## 8. 출시 전 차단·수동 게이트

### Blocker

1. `KAKAO_AUTH_CONTRACT`: 클라이언트 파생 비밀번호·임의 이메일 확인 RPC를 제거하고 Supabase Kakao OIDC 정본으로 이관한다.
2. `ANDROID_PHOTO_PERMISSION_POLICY`: Photo Picker 이관·광범위 권한 제거 전 제출 금지. 광범위 권한을 유지하려면 Play 선언 양식 승인 뒤 사전점검 게이트를 의도적으로 재비준한다.
3. 문서 게이트 `DATA_SAFETY_THIRD_PARTY_SHARING`(사전점검 자동 코드 아님): Supabase, Google Gemini, Firebase의 적용 요금제·계약을 확인해 서비스 제공자 예외 성립 여부와 데이터 유형별 공유 답변을 확정하기 전 Console 저장 금지.
4. 문서 게이트 `TARGET_AUDIENCE_ALIGNMENT`(사전점검 자동 코드 아님): 현재 약관이 허용하는 14–15세와 Play의 13–15 구간 불일치를 해결하기 전 타깃 연령 저장 금지.

### Play 제출 전 별도 승인 작업

아래는 Play 제출에 직접 관련된 수동 게이트다. 사전점검의 15개 수동 게이트 전체를 대체하지 않는다. iOS 전용인 Apple revoke/APNs/App Store Connect/private relay/iPad/third-party iOS privacy manifest 항목은 이번 Android 제출 목록에서 제외했으며 iOS 출시 때 별도로 닫는다.

1. 제출 전 필수: Photo Picker 이관 후 `READ_MEDIA_IMAGES`·`READ_EXTERNAL_STORAGE` 제거하고 release 병합 매니페스트에서도 부재를 재확인. 권한을 유지하려면 Play 사진·동영상 권한 선언 양식으로 지속적 핵심 용도를 제출하고 승인을 확보
2. 공개 개인정보처리방침·이용약관·지원 URL 접근 확인
3. 공개 계정 삭제 URL 제공
4. Firebase/Kakao의 release package와 업로드·App Signing 인증서 지문 대조
5. Supabase 이메일 인증·재발송·비밀번호 재설정·만료·rate limit 실계정 검증
6. `ACCOUNT_PURGE_RUNTIME`: 계정 삭제 migration·purge Edge 함수·비밀값·일일 스케줄·실패 알림을 운영에서 확인
7. `LEGACY_ANALYZE_EDGE_RUNTIME`: 운영 `analyze-emotion`이 삭제됐거나 검토된 인증형 410 tombstone인지 확인하고 Gemini 프록시 배포·호출을 검증
8. 심사용 계정 생성과 Play Console App access 입력
9. AAB 내부 테스트 트랙 업로드와 사전 출시 보고서 확인. Kakao OIDC 이관 전에는 실제 사용자에게 개방하지 않고 폐기 가능한 테스트 계정만 사용
10. `MARKETING_PUSH_CONSENT`: 현재 마케팅 발송 경로가 없음을 유지하며, 향후 도입 시 서비스 알림과 별도 동의·철회를 검증
11. Play Console Data safety/App content 답변 저장 및 제출
12. 타깃 연령 결정: 14–15세 이용을 유지하면 Play 13–15 선택에 따른 Families/UGC/콘텐츠 등급/광고 ID 영향을 검토하고 앱의 만 14세 게이트를 강화. 16+로 제한하면 약관·가입 흐름·기존 계정 처리를 먼저 정렬
13. Supabase·Google Gemini·Firebase 적용 계약을 확인해 데이터 유형별 `공유` 답변과 서비스 제공자 예외 근거를 기록
14. 지원 이메일 `jera.00003@gmail.com` 실수신을 재확인하고 공개 법무 문서의 다른 연락처를 웹사이트 변경 승인 후 단일화
15. `REAL_DEVICE_PUSH`: Android 실기기에서 포그라운드·백그라운드·종료 상태의 서비스 알림 수신과 탭 라우팅 검증
16. Play 내부 테스트 업로드 뒤 Console의 번들 매니페스트 보기 또는 `bundletool`로 versionCode와 최종 권한 집합을 다시 확인

## 9. 승인 경계

다음은 이 문서 작성과 Stage 2A 검증에 포함되지 않는다.

- Play Console에 답변 저장
- AAB 업로드
- 내부/비공개/프로덕션 트랙 제출
- 운영 DB·Edge 변경 또는 배포
- 공개 웹사이트 변경
- 실제 심사용 계정 자격 증명을 저장소에 기록
