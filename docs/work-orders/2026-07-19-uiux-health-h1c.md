# PetSpace 건강관리 H1C 작업지시서

## 상태

- 선행 기획: H1 Codex·Claude Fable 5 공동 승인
- 선행 구현: H1A 공동 승인, H1B `snapshot-v2` 사후 비준 중
- 실행자: Codex
- Claude 정책: 동일 변경 번들 사후 리뷰. 한도·지연은 Codex 구현을 막지 않음
- 운영 DB·Edge·commit·merge·push·deploy: 미실행

## 목표

건강관리의 보조 흐름에서 거짓 성공, 내부 오류 노출, AI 수치의 과도한
의미 부여를 없앤다. 자동 예정일 알림과 기기 알림 테스트를 별도 기능으로
표시하고, PDF와 감정 추이는 안전하고 테스트 가능한 health 경계를 사용한다.

## 합의 계약

1. 자동 예정일 알림은 운영 연결 전까지 `준비 중` 정보로만 표시하며 스위치,
   D-7/D-3/D-1, 시간 저장 UI를 활성 기능처럼 노출하지 않는다.
2. 기기 알림 테스트는 별도 44dp 이상 버튼으로 제공하고 진행 중 중복 실행을
   막는다.
3. 로컬 알림 서비스는 `scheduled`, `permissionDenied`, `unavailable`,
   `invalidDate`, `failed` 결과를 명시적으로 반환한다.
4. 실제 예약 성공일 때만 성공 안내를 표시한다. 권한 거부, 초기화 불가,
   잘못된 시간, 플랫폼 예약 실패는 서로 다른 안전 문구로 표시한다.
5. PDF 오류에는 exception·plugin·path 등 내부 세부 정보를 노출하지 않는다.
6. PDF AI 요약은 분석일과 승인된 한국어 대표 감정만 표시한다. 영문 내부 키와
   `positiveRatio` 백분율은 공유 PDF에서 제거한다.
7. 감정 추이는 정상 0건과 repository 실패를 구분하고, 실패에는 안전한 문구와
   재시도를 제공한다.
8. health presentation은 `EmotionRepository`를 직접 호출하지 않고 주입 가능한
   health 전용 loader 경계를 사용한다.
9. 선택 pet·사용자가 바뀐 뒤 늦게 도착한 감정 결과는 현재 화면을 덮지 않는다.
10. 미사용·하드코딩 샘플인 `HealthAlertCard`는 제거한다.
11. 홈, AI 분석 presentation, 소셜 홈, 하단 5탭과 `main_navigation.dart`는
    수정하지 않는다.
12. 새 진단·치료·정확도·confidence·법무 문구를 만들지 않는다.

## 정확한 구현 manifest

### 앱 소스 10개

1. `pjh/lib/config/injection_container.dart`
2. `pjh/lib/core/services/local_notification_service.dart`
3. `pjh/lib/features/health/presentation/controllers/health_emotion_loader.dart` (생성)
4. `pjh/lib/features/health/presentation/pages/health_main_page.dart`
5. `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
6. `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
7. `pjh/lib/features/health/presentation/widgets/emotion_trend_mini_chart.dart`
8. `pjh/lib/features/health/presentation/widgets/health_pdf_data.dart`
9. `pjh/lib/features/health/presentation/widgets/health_pdf_generator.dart`
10. `pjh/lib/features/health/presentation/widgets/health_alert_card.dart` (삭제)

### 테스트 5개

11. `pjh/test/core/services/local_notification_service_test.dart` (생성)
12. `pjh/test/features/health/presentation/health_alert_settings_page_test.dart` (생성)
13. `pjh/test/features/health/presentation/health_emotion_loader_test.dart` (생성)
14. `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`
15. `pjh/test/features/health/presentation/health_pdf_data_test.dart`

문서와 목업은 검토 증거이며 구현 manifest 수에 포함하지 않는다.

## UI 계약

### 건강 알림

- `자동 예정일 알림`: `준비 중` 배지, 기능 미제공 이유, 활성 control 없음.
- `기기 알림 테스트`: 설명, `5초 뒤 테스트 알림 보내기` 버튼, 진행 표시.
- 결과: 접근성 live region에 성공·권한·초기화·날짜·예약 실패를 구분해 표시.
- 성공 이외 결과에는 성공 SnackBar를 표시하지 않는다.

### PDF

- 제목과 선택 pet 파일명 계약을 보존한다.
- 생성 오류는 `건강 리포트를 만들지 못했어요`와 재시도만 표시한다.
- AI 요약은 `분석일`, `대표 감정`만 표시한다.

### 건강 변화

- 로딩, 정상 0건, 실패, 1건, 2건 이상을 구분한다.
- 실패는 `건강 변화를 불러오지 못했어요`와 `다시 시도`.
- 정상 0건은 기존 `AI 분석하러 가기`를 보존한다.

## 검증

- 알림 결과 enum과 page 결과 매핑 단위/widget test
- PDF 감정 라벨·비율 제거 contract test
- 감정 loader 성공·빈 결과·실패 test
- 감정 추이 empty/failure/retry widget test
- health 전체 테스트
- 전체 `flutter test --no-pub`
- `flutter analyze --no-pub`
- `git diff --check`
- 정확한 15파일 manifest와 보호 hash
- Codex 리뷰와 동일 번들 Claude Fable 5 리뷰

## 운영·실기기 이관

- Android 13+ 권한 허용·거부
- 5초 테스트 알림 실제 수신
- 앱 초기화 실패·권한 변경 후 재시도
- PDF 생성·재시도·공유
- 자동 예정일 알림의 실제 제공은 별도 운영 구현·검증 전까지 미완료
