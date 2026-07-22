# PetSpace Mac mini Codex 인계 정본

> 작성일: 2026-07-22
> 목적: Windows에서 검증된 공용 앱 변경을 기존 iOS 작업과 안전하게 통합하고, Codex·Claude 협업과 출시 경계를 동일하게 유지한다.
> 우선순위: 루트 `AGENTS.md` → 이 문서 → `docs/README.md`가 지정한 현행 문서 → 승인된 작업지시서

## 1. 첫 실행에서 반드시 읽을 문서

Mac Codex는 코드를 수정하기 전에 다음 파일을 순서대로 읽는다.

1. `AGENTS.md`
2. `docs/MAC_MINI_HANDOFF.md`
3. `docs/README.md`
4. `docs/AGENT_COLLABORATION.md`
5. `docs/AUTO_ORCHESTRATOR.md`
6. 현재 작업과 직접 관련된 `docs/work-orders/` 및 `docs/qa/` 문서

`docs/archive/`는 역사 자료이며 현행 작업 기준으로 사용하거나 수정하지 않는다. 오래된 화면·라우트·테스트 개수는 실제 코드와 다시 대조한다.

## 2. 저장소와 브랜치 정본

- 원격 저장소: `https://github.com/Jena-PetSpace/PetSpace.git`
- Android 정본: `origin/win-android-release`
- iOS 정본: `origin/mac-ios-release`
- 최종 안정 브랜치: `origin/main`
- Windows 인계 직전 확인 기준: `win-android-release`와 원격이 동일하고 작업 트리가 clean이었다.

Windows와 iOS 브랜치는 서로 고유 커밋이 많은 상태다. 한쪽을 다른 쪽으로 강제 reset·force-push하거나 폴더 복사로 덮어쓰지 않는다. 매 작업 시작 시 다음 명령으로 실제 차이를 다시 측정한다.

```bash
git fetch origin --prune
git status --short --branch
git rev-list --left-right --count \
  origin/win-android-release...origin/mac-ios-release
git merge-base origin/win-android-release origin/mac-ios-release
```

## 3. Mac 작업 폴더 구성

Windows 정본 확인용 폴더와 iOS 통합 작업 폴더를 분리한다.

```bash
mkdir -p ~/Desktop/PJH
cd ~/Desktop/PJH

git clone https://github.com/Jena-PetSpace/PetSpace.git pjh_app_claude
cd pjh_app_claude
git fetch origin --prune
git switch -C win-android-release origin/win-android-release

git worktree add \
  ~/Desktop/PJH/pjh_app_ios \
  -b integration/win-to-mac-$(date +%Y%m%d) \
  origin/mac-ios-release
```

- `pjh_app_claude`: Windows 정본 확인용. 기능 코드를 수정하지 않는다.
- `pjh_app_ios`: Windows 변경과 기존 iOS 변경을 통합하는 실제 작업 폴더다.
- 동일 파일을 두 worktree나 Claude·Codex가 동시에 수정하지 않는다.

## 4. Windows 변경의 iOS 통합 절차

먼저 read-only merge preview와 충돌 manifest를 만든다.

```bash
cd ~/Desktop/PJH/pjh_app_ios
git fetch origin --prune
git merge-tree --write-tree \
  origin/mac-ios-release \
  origin/win-android-release
```

preview와 기준 상태를 확인한 뒤 integration 브랜치에서만 실제 merge한다.

```bash
git merge --no-ff origin/win-android-release
```

충돌 해결 원칙:

1. 공용 Dart 기능·보안·DB/RPC 계약은 최신 Windows 구현과 테스트를 기준으로 보존한다.
2. 기존 `mac-ios-release`의 Apple 로그인, APNs, entitlements, URL scheme, plist, Pod, Xcode signing 등 iOS 전용 변경을 보존한다.
3. 어느 한쪽을 파일 단위로 일괄 선택하지 않는다. 충돌 파일별 의미를 비교한다.
4. 공용 기능 의미, 라우팅, 상태, 문구, Supabase 계약 변경이 필요하면 작업을 멈추고 정확한 manifest와 영향을 보고한다.
5. 충돌 해결과 iOS 수정도 별도 커밋으로 나눠 원인을 추적할 수 있게 한다.

## 5. 현재 DB·운영 경계

- K1 block/privacy 운영 계약의 표·컬럼·RPC·RLS 확인값은 모두 `TRUE`로 검증됐다.
- 앱은 `get_my_user_profile`, `ensure_my_user_profile` 및 auth.uid 기반 신규 RPC를 사용한다.
- `GRANT SELECT ON TABLE public.users TO authenticated` 또는 구형 caller-id RPC 권한 복구를 실행하지 않는다.
- J1 notification과 L1 health owner migration, Edge Function, APNs/FCM 운영 배포는 각각 별도 검증·승인 대상이다.
- 운영 DB migration, 원격 RPC, Edge deploy, 스토어 배포는 Mac 초기 통합 작업에 포함하지 않는다.

## 6. 비밀 파일과 로컬 생성물

Git으로 전달되지 않는 비밀 파일은 승인된 안전한 수단으로 별도 복사한다.

- `.env*`
- `pjh/lib/config/secrets.dart`
- Android/iOS 서명키·인증서·프로비저닝 프로파일
- Git에 포함되지 않은 Firebase·APNs 설정

다음 Windows 생성물은 복사하지 않고 Mac에서 다시 만든다.

- `.dart_tool/`, `build/`, `.gradle/`
- `ios/Pods/`, `ios/.symlinks/`
- `.git/worktrees/`와 Windows 절대경로가 들어간 Git 메타데이터

비밀값과 실제 사용자 데이터는 Codex·Claude 프롬프트, 로그, 리뷰 번들, 커밋에 포함하지 않는다.

## 7. Mac 환경 점검

모든 Flutter 명령은 `pjh/`에서 실행한다.

```bash
cd ~/Desktop/PJH/pjh_app_ios/pjh
flutter doctor -v
flutter clean
flutter pub get

cd ios
pod install
cd ..
```

Xcode 라이선스, Command Line Tools, CocoaPods, iOS deployment target, signing team은 실제 Mac 환경에서 확인한다. 설치나 signing 설정을 추측으로 변경하지 않는다.

## 8. 필수 검증 게이트

최소 검증:

```bash
cd ~/Desktop/PJH/pjh_app_ios/pjh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --release --no-codesign
```

추가 확인:

- `git diff --check`
- integration manifest 밖 변경 0
- Google·Kakao·Apple 인증
- MY·피드·건강관리·채팅 주요 플로우
- 알림 권한·APNs token·딥링크·카메라·사진 권한
- PDF 생성·공유, 키보드, SafeArea, 뒤로가기 제스처
- 작은 iPhone과 큰 글씨

실제 signing, TestFlight, 운영 APNs, 스토어 제출은 별도 사람 승인으로 남긴다.

## 9. Claude × Codex 협업

1. Codex가 merge conflict와 iOS 영향 manifest, 작업지시서, 검증 계획 초안을 작성한다.
2. Claude는 동일 manifest와 diff를 독립 리뷰한다.
3. 기본 Claude 모델은 Fable 5이며 실제 한도/429일 때만 Opus 4.8로 한 번 전환한다.
4. blocker/high 또는 양쪽 불일치가 있으면 자동 수정·merge하지 않고 쟁점만 보고한다.
5. 기존 외부 전송 승인은 기록된 정확한 파일·해시에만 적용된다. 새 iOS 파일이나 변경된 번들의 외부 전송은 비밀 파일을 제외하고 별도 범위를 확정한다.
6. 자동 오케스트레이터는 feature worktree 구현·교차 리뷰까지만 수행하며 release merge·push는 검증된 결과와 사용자 승인에 따라 별도 수행한다.

Mac에서 Claude 협업을 사용할 때:

```bash
node scripts/agent-collab.mjs preflight
```

Claude Code 로그인, Codex 로그인, Node, Git, 모델 fallback 결과를 확인한 뒤 실제 run을 시작한다.

## 10. 플랫폼 release와 main 반영

iOS 통합·검증이 완료되면 사용자 승인 범위에서만 다음 순서로 진행한다.

1. integration/feature 브랜치 커밋
2. Claude·Codex 최종 diff 리뷰 blocker/high 0
3. 로컬 `mac-ios-release`에 merge
4. `mac-ios-release` 전체 검증
5. `origin/mac-ios-release` push
6. Android·iOS 실기기 최종 확인
7. 최신 `win-android-release` 포함 여부 재검증
8. 별도 승인 뒤 PR/merge로 `main` 반영

force push, rebase로 release 이력 재작성, 자동 main push, 자동 DB·Edge·스토어 배포를 금지한다.

## 11. Mac Codex 첫 요청문

Mac에서 저장소를 연 직후 다음 요청으로 시작한다.

```text
루트 AGENTS.md와 docs/MAC_MINI_HANDOFF.md, docs/README.md,
docs/AGENT_COLLABORATION.md를 먼저 전부 읽어라.

아직 코드를 수정하거나 merge하지 말고 다음을 read-only로 수행하라.
1. Git remote, 현재 branch, clean 여부, win/mac/main HEAD를 확인한다.
2. origin/win-android-release와 origin/mac-ios-release의 divergence와 merge-base를 확인한다.
3. Flutter, Xcode, CocoaPods, Node, Codex, Claude CLI 환경을 점검한다.
4. Windows 최신 변경과 기존 iOS 변경의 충돌 예상 파일 manifest를 만든다.
5. K1 계약을 보존하고 DB·Edge·배포를 수행하지 않는 통합 작업지시서 초안을 작성한다.
6. Claude 리뷰에 보낼 정확한 비밀 제외 파일 범위를 제안한다.

결과를 보고하고 사용자 승인 전에는 실제 merge와 iOS 코드를 수정하지 마라.
```

채팅 기록 자체를 복사할 필요는 없다. 지속 규칙과 현행 사실은 Git에 포함된 `AGENTS.md`, 이 인계 문서, 작업지시서, 테스트가 정본이다.
