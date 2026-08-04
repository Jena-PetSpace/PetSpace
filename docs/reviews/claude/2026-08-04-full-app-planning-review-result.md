# Claude 전체 앱 기획 교차검토 결과

기준일: 2026-08-04
검토 모델: Claude Opus 5 높음
검토 방식: Claude Desktop, read-only 3회 관점 검토 후 v2 합의 재검토

## 외부 전달 범위

실제 파일 첨부는 다음 2개였다.

1. `docs/reviews/claude/2026-08-04-full-app-planning-review-request.md`
2. `docs/reviews/2026-08-04-full-app-uiux-master-plan.md` v1

인벤토리와 W5/W6 이미지는 Claude에 첨부되지 않았다. 대신 첫 검토 뒤 Codex가
정확한 변경 결정과 80/80 결과, W5/W6 v2 보정 내용을 같은 대화에서 텍스트로
전달해 기획 정합성 재검토를 받았다. 따라서 Claude의 최종 `approved`는
기획 계약에 한정되며 이미지 픽셀·파일 바이트 검증을 뜻하지 않는다.

비밀 파일, Firebase plist, 환경변수, 인증서·키, provisioning profile,
사용자 데이터, 로그, 빌드 생성물은 전송하지 않았다.

## 1차 판정

`VERDICT: changes_required`

Claude는 정보구조·시각/접근성·기능/백엔드 관점을 분리해 다음을 지적했다.

### Blocker

- CTA `#3B78B8`는 흰색 대비 여유가 거의 없고 승인된 `#2F6399`보다 후퇴함
- 다크 토큰이 없는데 B9로 미뤄 B1~B6 재작업이 예정됨
- 레거시 `팔로워만`/미지 visibility의 읽기 정책이 없음
- 반려동물 삭제가 연결 데이터·대표 재지정 계약보다 먼저 열릴 수 있음

### High

- 온보딩 중단 복귀와 탈퇴 유예 재로그인 redirect 상태표 부재
- 반려동물 0마리 사용자의 건강·AI 루트 상태 부재
- 세션 만료 시 작성·채팅·건강 입력 손실 위험
- presentation 80개와 배치의 1:1 매핑 부재
- Dynamic Type 200%와 5탭 라벨의 충돌 규칙 부재
- 채팅 reconnect backfill 계약 부재
- 게시글 위치정보 수집·정밀도·삭제 정책 부재

### Medium

- 공통 아이콘 세트, 채팅 차단 진입, 카운터 정합, 오프라인 쓰기 기본값
- 포인트 이력·유효기간, 건강 긴급도 문구의 근거, pending deep link
- 목업과 기획 절의 대응표

## Codex 판정과 v2 반영

Claude 지적을 코드·기존 승인 문서와 대조해 다음처럼 처리했다.

| 항목 | Codex 판정 | v2 결정 |
|---|---|---|
| CTA 대비 | 수용 | `#2F6399`, light canvas `#F7F8FA` 복귀 |
| 다크 토큰 | 수용 | B0에서 팔레트·상태·경계·아이콘·AX 확정, B9는 회귀만 |
| visibility | 수용 | `auth.uid()` 서버 view/RPC/RLS fail-closed + 소유자 재설정 |
| 반려동물 삭제 | 수용 | soft delete 30일, 대표 직접 선택, 참조 데이터 표시 규칙 확정 |
| 온보딩 | 수용 | 5상태 redirect 표와 탈퇴유예 복구 화면 |
| 세션 | 수용 | silent refresh 1회, task draft 저장, 로그인 후 복원 질의 |
| 0마리 | 수용 | 건강·AI 루트 전용 상태와 등록 CTA 하나 |
| 화면 누락 | 수용 | path/route/batch/evidence/completion 80/80 매핑 |
| 채팅 | 수용 | REST backfill 후 realtime 재구독, client id 중복 제거 |
| 위치 | 수용 | 신규 쓰기 금지, 기존 조회·인덱스 제외, 장소 UI 숨김 |
| 탭 접근성 | 수정 수용 | 전체 semantic label·Tooltip, nav만 1.3배, 본문은 200% |
| 참여 기능 | 수용 | 포인트 이력·유효기간 없음, W5 v2 단색 CTA |

Home과 AI 분석 결과 구현 잠금, 원형 Apple/Google/Kakao 로그인,
루트 5탭, 피드/커뮤니티 명칭, 스토리 미추가, K1/H2와 `auth.uid()` 계약,
Apple OAuth·entitlement·iPad shareOrigin은 그대로 유지했다.

## 최종 판정

Claude의 최종 응답:

- `VERDICT: approved`
- `BLOCKER: none`
- `HIGH: none`
- B0 착수 승인
- B1~B6 착수 조건 충족
- Home·AI 결과 구현 잠금 유지

판정에 영향 없는 마지막 권고인 `1.3배 제한은 nav 라벨에만 적용`도 v2
디자인 시스템 표에 명시했다.

## Codex 최종 결론

기획 수준 blocker/high는 0이다. 구현 권한은 아직 발생하지 않았으며,
실제 각 배치는 정확한 수정 manifest와 사용자 승인 뒤 시작한다. W5/W6 v2는
Codex가 로컬에서 검토했으며 구현 시 Simulator·실기기·접근성 검증으로 다시
확인한다.
