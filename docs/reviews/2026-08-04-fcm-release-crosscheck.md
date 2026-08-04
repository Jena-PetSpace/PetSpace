# Firebase/FCM 출시 전 Codex·Claude 교차검토

> 최종 판정: `accept`
> 최종 검토 모델: `claude-opus-5`
> blocker/high: `0`
> 범위: 운영 metadata/숫자 집계와 로컬 코드
> 제외: secret 값, 사용자 token/payload, 운영 변경

## 합의 결론

- 운영 푸시 경로는 DB 설정, Edge 배포, Firebase secret 3계층이 모두 비어 있어 현재 동작하지 않는다.
- 로컬 알림 navigator key 미주입으로 포그라운드 알림과 건강 예약 알림의 탭 라우팅이 동작하지 않는다.
- FCM과 로컬 알림의 `health_alert`/`emotion_analysis` 라우팅이 서로 다르다.
- Android 백그라운드 알림에 정본 채널 ID가 전달되지 않는다.
- service role key는 SQL 정본에 실제 값을 기입하지 않고 Dashboard에서만 설정해야 한다.

## 승인된 로컬 수정

- 공용 알림 라우트 resolver
- 두 알림 서비스의 동일 navigator key 주입
- Edge type→Android channel ID 매핑과 기본 채널 metadata
- 계약 테스트와 운영 활성화 런북
- `petspace_setup.sql`의 secret 취급 경고 강화

운영 DB 설정, Edge secret 등록·배포, 실제 푸시 전송은 계속 별도 승인으로 둔다.

## 최종 재검토

초기 high였던 DB 트리거 조기 활성화 순서를 다음과 같이 바로잡았다.

1. `pg_net` 확인
2. Firebase Edge secret 등록
3. JWT 검증을 유지한 Edge 함수 배포와 `401`/`403` 확인
4. DB `app.settings`를 마지막에 설정해 트리거 활성화
5. 새 세션 검증 후 테스트 알림 1건 전송

추가로 포그라운드 유형별 Android 채널, 원격·로컬 완전 종료 탭의 pending 라우팅,
단색 상태바 아이콘, 다중 기기 전송 실패 격리, 잘못된 token 구조 판정, 구체적 롤백,
정본·J1의 빈 설정값 가드, payload 키 인코딩과 예약 키 보호를 반영했다.

Claude Opus 5 최종 재검토 결과 `accept`, blocker/high 0이다. 남은 비차단 항목은
콜드스타트 시 인증 초기화와 라우팅의 타이밍을 실기기 E2E로 확인하는 것과, 향후 producer가
임의 FCM 예약 키를 추가할 경우 allowlist를 도입하는 것이다.

최종 검증은 `flutter analyze --no-pub` 무경고, 전체 `flutter test --no-pub`
1,016건 통과, 최종 알림·SQL 계약 테스트 20건 통과다.
