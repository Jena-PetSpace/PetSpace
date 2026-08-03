# PetSpace Apple 개인정보 데이터 인벤토리

상태: App Store Connect 입력 전 사실 확인용 초안
원칙: 실제 앱·SDK·DB·Edge 흐름이 확정되기 전 추측으로 답변하지 않는다.

| 데이터 유형 | 현재 근거 | 사용자 연결 | 추적 | 목적 | 판정 |
|---|---|---:|---:|---|---|
| 이메일 주소 | Supabase 인증 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 이름·닉네임 | 사용자 프로필 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 사용자 ID | `auth.uid()` 기반 계정 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 사진·동영상 | 게시글·프로필·AI 분석 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 기타 사용자 콘텐츠 | 게시글·댓글·채팅·건강 기록 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 정확한 위치 | 주변 검색, 게시물 `location_lat/lng` 저장 | 예 | 아니요 | 앱 기능 | iOS manifest 반영 완료, 스토어 답변 필요 |
| 대략적 위치 | 별도 절삭·대략화 저장 경로 없음 | 해당 없음 | 아니요 | 해당 없음 | 정확한 위치로 통합 선언 |
| 기기 ID | FCM 토큰 | 예 | 아니요 | 앱 기능 | 선언 필요 |
| 제품 상호작용 | Firebase Analytics | SDK 설정 확인 | 아니요 | 분석 | 선언 필요 |
| 크래시 데이터 | Firebase Crashlytics | SDK 설정 확인 | 아니요 | 앱 기능·분석 | 선언 필요 |
| 성능 데이터 | Firebase Performance | SDK 설정 확인 | 아니요 | 분석 | 선언 필요 |
| 진단·기타 데이터 | SDK privacy manifest 통합 결과 | 확인 필요 | 아니요 | 분석·앱 기능 | archive에서 확인 |

## P0 정합성 검토

### 정확한 위치

현재 게시물 모델과 Supabase 스키마는 위도·경도를 별도 필드로 저장한다.
`PrivacyInfo.xcprivacy`는 연결된 정확한 위치·앱 기능 목적으로 수정했고,
`Info.plist`도 주변 검색과 사용자가 선택한 게시물 장소를 함께 설명한다.
산책 경로 등 원본 개인위치정보는 탈퇴·삭제 시 파기하고,
`location_access_log`에는 위치 좌표가 아닌 대상 UUID, 취득경로, 서비스,
제공받는 자, 이용 시각만 기록한다. 이 확인자료는 위치정보법 제16조
제2항과 앱 내 위치기반서비스 약관 제8조에 따라 6개월간 분리 보관한 뒤
파기하는 예외로 고지되어 있다. 매일 실행할 계정 purge 배치가 UTC 달력
기준으로 6개월이 지난 확인자료도 함께 삭제하도록 로컬 구현되어 있으며,
운영 cron 등록은 제출 전 수동 게이트다.

제출 전 남은 결정:

1. App Store Connect에 정확한 위치, 사용자 연결, 앱 기능을 동일하게 답한다.
2. Play Data safety도 같은 데이터 흐름으로 답한다.
3. 보유기간과 게시물 공개 범위를 개인정보처리방침·RLS·RPC와 대조한다.
4. 향후 좌표를 제거·절삭할 때만 manifest와 스토어 답변을 다시 좁힌다.

### 추적·IDFA

현재 iOS manifest는 tracking=false다. 그러나 개인정보처리방침은 선택적
마케팅 항목에서 IDFA 수집 가능성을 적고 있다. 실제 광고 SDK, ATT 요청,
타사 데이터 결합이 없다면 정책 문구를 실제에 맞춰 좁혀야 한다. 사용한다면
manifest와 App Store 답변, ATT 흐름을 모두 바꿔야 한다.

### AI 국외 이전

반려동물 사진·영상·텍스트가 Google AI 처리 경로로 전송되는 범위, 보관
정책, 학습 사용 여부를 실제 API 계약과 Edge 구현으로 다시 확인한다.
스토어 설명에서는 AI를 수의학적 진단으로 표현하지 않는다.

### 계정 삭제

앱 내 탈퇴와 30일 soft-delete 계약은 존재한다. Apple 로그인 사용자는
iOS 재인증 authorization code를 Edge에 즉시 전달하고, Edge가 identity와
nonce를 검증한 뒤 refresh token을 revoke하도록 로컬 구현했다. 제출 전
Apple Edge secret 등록·운영 배포·실계정 검증이 필요하다.
30일 후 purge는 발신 알림 행을 삭제하고 채팅방의 마지막 메시지 스냅샷을
비운 뒤 `auth.users`와 `public.users`를 삭제한다. 따라서 `ON DELETE SET
NULL` 관계로 발신 콘텐츠가 잔존하지 않도록 한다.

## Archive 단계 확인

- 앱 자체 manifest에서 확인된 required-reason API:
  `UserDefaults/CA92.1`, `FileTimestamp/C617.1`, `DiskSpace/E174.1`,
  `SystemBootTime/35F9.1`
- Xcode privacy report에서 포함 SDK의 privacy manifest 확인
- Firebase, Supabase, Google Sign-In, Kakao, permission_handler 결과 확인
- App Store Connect 답변과 `PrivacyInfo.xcprivacy`의 일치 확인
- tracking domain이 비어 있는지 확인
- 사용하지 않는 권한·데이터 선언 제거 여부 확인

## 금지

- 좌표 절삭 근거 없이 “대략적 위치만 공개”라고 고지하지 않는다.
- Firebase 설정 파일·비밀 키·토큰 내용을 문서나 로그에 넣지 않는다.
- 반려동물 AI 결과를 진단·치료 또는 정확도 보장으로 표현하지 않는다.
