# iOS 트랙 Follow-up 인계 메모

> win-android-release(47커밋) 머지 + iOS 관점 리뷰 결과 도출된 후속 작업.
> 머지 커밋 `c573bca` / 수정 커밋 `8ce8442`(PDF 폰트), `e7abbd7`(iPad 공유·401).
> 기준일: 2026-06-18.

## 🔴 P0 — iOS 앱 제출 100% 선행조건

### 1. Sign in with Apple 구현 + 계정삭제 시 token revoke
- **근거**: Apple Review Guideline **5.1.1(v)** — 계정 생성 기능이 있으면 앱 내 계정 삭제 제공 + **Sign in with Apple로 가입한 계정은 삭제 시 REST API로 토큰 revoke** 필수.
- **현재 상태**:
  - `supabase/functions/request-account-deletion/index.ts:5` 주석에 *"Apple token revoke는 앱이 Apple 토큰을 저장하지 않아 미구현 — iOS 트랙 인계"* 명시.
  - 계정 soft delete 흐름 자체는 완비(`G1_account_soft_delete.sql`, 30일 유예, 복구 다이얼로그). Apple 측 토큰 폐기 호출만 누락.
- **필요 작업**:
  1. 로그인 시 Apple **refresh token 저장**(서버측 안전 보관).
  2. 계정 삭제(또는 30일 purge) 시 Apple **revoke 엔드포인트 호출** 구조 추가.
  3. `purge-deleted-accounts`에서 auth.users 삭제와 함께 revoke 연계.
- **연결 이슈**: 기존 출시 블로커 **"Sign in with Apple 미구현(4.8)"**과 동일 트랙 — 함께 기획/구현할 것. (Apple은 타 소셜 로그인 제공 시 Apple 로그인도 요구)
- **트랙**: 별도. 본 머지 범위 밖.

## 🟢 P2 — 정리 권장(노출 없음, 위생)

### 2. 데드코드 리워드 스토어 타일 정리
- `pjh/lib/features/my/presentation/widgets/settings_bottom_sheet.dart:80` — `'리워드 스토어' → /reward` 타일 잔존.
- `SettingsBottomSheet`는 현재 **어디서도 호출 안 되는 데드코드**(실제 설정은 `/settings/my` → `MySettingsPage`, 거기선 이미 주석 처리됨).
- 위험: 누군가 이 위젯을 되살리면 미완성 리워드 화면이 심사 노출(2.1). → 삭제 또는 동일하게 주석 처리.

### 3. purge 배치 cron 실제 등록
- `supabase/manual_sql/history/G1_account_soft_delete.sql` / `purge-deleted-accounts` — 과거 수동 적용 이력이며 현재는 운영 반영 여부를 먼저 확인한다.
- 30일 자동 영구삭제가 실제 동작하려면 운영자가 cron 등록 필요.
- **제출 전 체크**: cron 실제 등록 + 1회 동작 확인. (미등록 시 "삭제됨" 안내와 실제 삭제 불일치)

## ℹ️ 참고 — 이번 머지에서 처리 완료
- ✅ PDF 폰트 assets 미등록(생성 100% 실패) → `pubspec.yaml` 수정 (`8ce8442`).
- ✅ iPad 공유 popover anchor 누락(크래시 위험) 9개 호출부 → `sharePositionOrigin`/`bounds` 지정 (`e7abbd7`).
- ✅ gemini-proxy 401 오안내 → "로그인 만료" 메시지 + 만료 세션 사전 refresh (`e7abbd7`).

## 검증 메모(이번 작업 기준)
- `flutter analyze`: 0 issues.
- `flutter test`: +343 -14 (실패 14건은 머지 시점 베이스라인 — Supabase 미초기화/목 TypeError 환경성, 본 수정과 무관).
- iPad 실기기 공유/PDF 크래시 검증은 첫 릴리스 전 1회 수동 권장.
