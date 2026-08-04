# Claude read-only 교차검토 요청 — PetSpace 전체 UI/UX 기획

## 검토 목적

첨부한 전체 UI/UX 기획과 W5/W6 목업을 Flutter 구현 전에 독립 검토해 주세요.
코드 작성, 저장소 수정, DB/Edge/APNs/배포 실행은 요청하지 않습니다.

## 기준

- branch: `mac-ios-release`
- source HEAD: `164ae40ea8a82e0d27450f20ced8f602ac854a16`
- 앱: Flutter, Supabase, Firebase FCM, Gemini 기반 PetSpace
- 정확한 화면 인벤토리: presentation page 80개
- feature 테스트 인벤토리: 155개

## 고정 보호 조건

1. Home과 AI 분석 결과 화면은 기획만 하며 구현은 별도 사용자 승인까지 잠급니다.
2. 로그인 원형 Apple → Google → Kakao 버튼을 보존합니다.
3. 하단 탭은 `홈 / 건강 / AI 분석 / 피드 / MY`, AI는 기존 발바닥 일반 탭입니다.
4. 피드 내부는 `피드 / 커뮤니티`, 스토리는 추가하지 않습니다.
5. 안전하지 않은 `팔로워만` 공개 선택은 노출하지 않습니다.
6. K1/H2, `auth.uid()` RPC, Apple OAuth, iPad shareOrigin을 보존합니다.
7. 운영 DB, Edge, APNs, signing, TestFlight, 배포는 실행하지 않습니다.

## 보안·외부 전송 조건

이 번들에는 기획 문서와 가상 데이터 목업만 있습니다. 비밀 파일,
`GoogleService-Info.plist`, `.env*`, `secrets.dart`, 인증서·키·provisioning,
사용자 데이터, 로그, 빌드 생성물은 포함하지 않았습니다. 첨부되지 않은 파일을
추측하거나 요청하지 말아 주세요.

## 검토 질문

다음 네 관점에서 최소 세 번 독립적으로 검토해 주세요.

1. IA/사용자 여정: 누락된 화면·상태·복구·완료 경로가 있는가?
2. UI/UX/접근성: 바이브코딩 느낌, 과도한 카드·그라데이션·이모지, 작은 터치,
   Dynamic Type·VoiceOver·iPad·dark mode 문제가 남아 있는가?
3. 기능/백엔드/신뢰: optimistic rollback, pagination, realtime, 인증, 알림,
   차단·신고, 의료 오인, 원문 오류·민감 로그 문제가 충분히 반영됐는가?
4. 실행 가능성: B0~B9 우선순위와 잠금 조건이 회귀를 줄이는가?

## 응답 형식

아래 형식만 사용해 주세요.

```text
VERDICT: approved | changes_required

BLOCKER:
- 없으면 none

HIGH:
- 항목 / 근거 / 수정 제안

MEDIUM:
- 항목 / 근거 / 수정 제안

KEEP:
- 반드시 유지할 결정

PRIORITY_CHANGES:
- 기존 순서 → 제안 순서 / 이유

MOCKUP_REVIEW:
- W5 / W6 각각 승인 또는 수정 사항

FINAL_CONSENSUS:
- 구현 전 사용자가 선택해야 할 항목
```

모호한 `관련 화면`, `관련 테스트`, 디렉터리 전체 같은 표현 대신 가능한 경우
첨부된 문서의 정확한 섹션·파일·배치를 지목해 주세요.
