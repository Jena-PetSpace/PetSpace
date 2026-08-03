# Windows Android 출시 작업 인계서

기준일: 2026-08-03
대상 브랜치: `win-android-release`
공통 출시 준비 코드 커밋: `5e62b8f`

## 인계 목표

Mac에서 검증한 공통 Flutter·Supabase·출시 준비 변경을 Windows 노트북의
`win-android-release`에서 이어 받아 Android 전용 출시 검증과 UI/UX 실기기
점검을 수행한다. iOS 전용 signing·APNs·App Store 작업은 Windows에서
변경하지 않는다.

## 이번에 전달되는 주요 변경

- 앱 정보와 오픈소스 라이선스 화면
- 로그인·회원가입·비밀번호 재설정 반응형 UI와 입력 검증
- 반려동물 관리의 삭제·대표 반려동물 안전 처리
- 장소 검색 실패·오프라인 복구 상태
- 커뮤니티 글 작성 공용 콘텐츠 필터
- Apple 재인증·credential revoke 기반 탈퇴 클라이언트/Edge 계약
- 30일 계정 purge, 위치 감사자료 6개월 만료 삭제, soft-delete RLS
- iOS Privacy Manifest와 공통 개인정보·출시 준비 문서
- 출시 preflight와 관련 회귀 테스트

## Windows 노트북 Codex 시작 절차

저장소 루트에서 다음 순서로 실행한다.

```powershell
git fetch origin
git switch win-android-release
git pull --ff-only origin win-android-release
git status --short --branch
git log -5 --oneline
```

다음 문서를 모두 읽는다.

- `AGENTS.md`
- `docs/work-orders/2026-08-03-windows-android-release-handoff.md`
- `docs/reviews/2026-08-03-full-app-uiux-audit-plan.md`
- `docs/release/2026-07-31-common-ios-readiness.md`
- `docs/release/2026-07-31-apple-privacy-data-inventory.md`

Flutter 앱 루트에서 기본 검증을 수행한다.

```powershell
cd pjh
flutter doctor -v
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
dart run tool/release_preflight.dart
```

## Android 정본과 불일치 주의

- 실제 namespace/application ID: `com.jena.petspace`
- 실제 version: `1.0.0+4`
- 현재 compileSdk/targetSdk: 36
- OAuth callback custom scheme `com.petspace.app`은 application ID가 아니다.
- 루트 `AGENTS.md`의 Android package/targetSdk 설명이 코드 정본과 다르면
  거버넌스 문서 변경으로 분리하고, 앱 코드는
  `pjh/android/app/build.gradle.kts`를 우선 대조한다.

## Android 출시 P0 게이트

1. `pjh/android/app/build.gradle.kts`가 `key.properties` 부재 시 release에
   debug signing을 사용하는 현재 폴백을 제거하거나 release build를
   명시적으로 실패시킨다.
2. 업로드 키/JKS와 `key.properties`는 로컬에서만 준비하고 Git에 추가하지
   않는다. 값·비밀번호·SHA를 Codex 보고서나 로그에 출력하지 않는다.
3. Firebase Android 앱 package가 `com.jena.petspace`인지 콘솔에서 확인하고
   FCM foreground/background/terminated 수신을 실제 기기에서 검증한다.
4. Kakao Android package/key hash와 OAuth callback을 릴리스 서명 기준으로
   검증한다.
5. `https://petspace.app` App Links의 `assetlinks.json`을 릴리스 인증서
   fingerprint 기준으로 검증한다.
6. Android 13+ 알림, 카메라, 사진, 위치 권한의 허용·거부·영구 거부·설정
   복구를 실제 기기에서 확인한다.
7. Play Console Data safety와 앱 내 개인정보 문구, Firebase/Supabase/AI/위치
   데이터 인벤토리를 같은 사실로 맞춘다.

서명 자산이 준비된 뒤에만 다음을 실행한다.

```powershell
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

빌드 후 APK/AAB가 debug key로 서명되지 않았는지 별도로 확인한다.

## Android 실기기 필수 시나리오

- 이메일·Google·Kakao 가입/로그인/로그아웃/비밀번호 재설정
- 반려동물 등록·수정·삭제·대표 반려동물 변경
- 게시글·커뮤니티 글 작성, 사진·장소 선택, 수정·삭제
- 댓글·좋아요·저장·컬렉션·팔로우·검색·신고·차단
- 채팅 생성·전송·수신·알림·방 설정
- 건강 기록 작성·수정·삭제·PDF 생성/공유·로컬 알림
- 감정/건강 분석 입력·촬영·로딩·결과·히스토리·공유
- MBTI·OX 퀴즈·오늘의 운세·뉴스·리워드
- FCM foreground/background/terminated, 알림 탭 딥링크
- 오프라인·서버 오류·세션 만료·권한 거부·큰 글자·다크 모드

## 보호 범위

- `secrets.dart`, `.env*`, `google-services.json`, JKS, `key.properties`의 내용,
  크기, SHA, 환경변수 이름을 보고서·manifest·외부 서비스에 포함하지 않는다.
- `GoogleService-Info.plist`, iOS entitlements, Podfile/Podfile.lock,
  `project.pbxproj`는 Android 전용 변경 대상으로 보지 않는다.
- K1/H2, auth.uid 기반 RPC, L1/L2 계정 삭제 계약을 약화하지 않는다.
- broad `public.users SELECT`와 caller-id RPC를 복구하지 않는다.

## Windows Codex에 전달할 첫 요청문

> origin/win-android-release를 fetch/pull한 뒤 AGENTS.md와
> docs/work-orders/2026-08-03-windows-android-release-handoff.md,
> docs/reviews/2026-08-03-full-app-uiux-audit-plan.md를 전부 읽어라.
> 먼저 read-only로 Android signing, Firebase/FCM, Kakao, App Links,
> 권한, Data safety 차이를 점검하고 P0 manifest를 작성하라.
> iOS 전용 파일과 운영 DB/Edge는 수정하지 말고, 실제 자격증명과 비밀값을
> 출력하지 마라. 검토 후 승인된 Android 파일만 수정하고 analyze, 전체 test,
> 서명 APK/AAB, 실제 Android 기기 시나리오를 순서대로 검증하라.
