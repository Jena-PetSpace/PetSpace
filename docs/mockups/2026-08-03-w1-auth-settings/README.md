# PetSpace W1 인증·온보딩·설정·알림 목업

기준일: 2026-08-03
상태: 사용자 선택 대기 — 구현 금지

## 고정 조건

- 로그인 첫 화면은 이메일 폼과 원형 Apple·Google·Kakao 로그인을 함께 제공한다.
- 소셜 로그인 순서는 iOS에서 Apple → Google → Kakao로 유지한다.
- 로그인 화면은 헤더·폼·하단 CTA가 갈라지지 않는 하나의 배경을 기본으로 한다.
- Home과 AI 분석 결과 페이지는 이 Wave에서 수정하지 않는다.
- 인증·알림·회원탈퇴의 기존 보안·서버 계약은 시각 변경보다 우선한다.

## 목업 선택지

### A. 인증 진입

[A-auth-entry-ab-v1.png](A-auth-entry-ab-v1.png)

- 권고: `A · 단일 흐름 정돈`
- 보존: 승인된 문구, 이메일/비밀번호, 원형 소셜 버튼, 단일 캔버스
- 개선: iPad 최대 너비, 입력 오류 위치, 비밀번호 보기, 키보드 스크롤
- 비권고: `B · 브랜드 패널 강조`는 배경 영역이 다시 분절돼 이전 문제를 반복할 수 있다.

### B. 설정·알림

[B-settings-notifications-ab-v1.png](B-settings-notifications-ab-v1.png)

- 설정 권고: `A · 컴팩트 그룹형`
- 알림 권고: `A · 권한과 앱 설정 분리`
- 개선: 큰 아이콘 박스를 줄이고 행 밀도를 높이며, 시스템 알림 권한과 앱 내부 알림 선택을 분리한다.
- 위험 액션은 일반 메뉴와 별도 섹션 및 색으로 유지한다.

### C. 가입 후 온보딩

[C-post-signup-onboarding-ab-v1.png](C-post-signup-onboarding-ab-v1.png)

- 권고: `A · 필수만 먼저`
- 순서: 이메일 인증 → 약관 동의 → 프로필 → 반려동물 등록/나중에
- 감정 분석 튜토리얼은 가입을 막는 7단계 흐름 대신 실제 기능 첫 진입의 맥락형 안내로 옮긴다.
- 필수/선택 동의, 입력 실패 보존, 건너뛰기 결과, OTP 비공개 계약은 유지한다.

## 현행 비교 자료

- [W0-current-ipad-login.jpeg](W0-current-ipad-login.jpeg): 현재 iPad mini 가로 로그인 화면
- [기존 iPhone 로그인 캡처](../../../qa/2026-07-30-simulator-review/02-login.png)
- [기존 설정 상단 캡처](../../../qa/2026-07-30-simulator-review/09-settings-top.png)
- [기존 설정 하단 캡처](../../../qa/2026-07-30-simulator-review/10-settings-bottom.png)

목업의 작은 보조 문구는 시각 비교용이다. 구현 시 이 문서와
`docs/reviews/2026-08-03-w1-auth-settings-notification-review.md`의 정확한
한국어 문구를 정본으로 사용한다.
