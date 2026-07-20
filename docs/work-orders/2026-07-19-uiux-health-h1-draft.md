# PetSpace 건강관리 H1 공동 기획 초안

> 상태: Codex 예비 코드 감사와 반응형 목업을 바탕으로 만든 공동 검토 초안  
> 구현 승인: 없음  
> 선행 게이트: Feed F2 구현·테스트·Codex/Claude 리뷰 완료  
> 다음 게이트: Claude Fable 5 우선 검토 → 필요 시 Opus 4.8 fallback → Codex 합의 → 사용자 목업·정확한 manifest 승인  
> 금지: 이 문서만으로 Flutter·DB·Edge·운영 환경을 수정하지 않는다.

## 1. 목표

건강관리 탭을 반려동물별 기록과 일정의 정본 화면으로 정리한다.

1. 선택한 반려동물이 바뀌면 기록·예정 일정·요약이 함께 바뀐다.
2. 저장·수정·삭제는 서버 성공 여부와 사용자 피드백이 일치한다.
3. 오류 세부 정보나 건강 개인정보가 사용자 화면에 노출되지 않는다.
4. 반려동물 없음, 기록 없음, 불러오기 실패가 서로 다른 행동을 제공한다.
5. 기록 유형의 의미는 아이콘과 라벨로 전달하고 장식적인 다색 사용을 줄인다.
6. 자동 건강 알림의 미제공 상태를 숨기거나 과장하지 않는다.
7. 기존 기록 유형·PDF·체중 추이·감정 추이의 기능 의미를 보존한다.
8. 수의학적 진단·치료 권고로 오인되는 문구를 새로 만들지 않는다.

## 2. 확인된 현재 사실

### H1-H1 — 반려동물 변경 후 이전 기록이 남을 수 있음

`HealthMainPage`는 `initState`에서만 `_loadHealthData()`를 호출한다. `PetBloc`의
선택 반려동물이 바뀌면 앱바 이름은 갱신되지만 `HealthBloc` 재조회는 보장되지 않는다.

권고:

- 선택 pet ID 변경을 감지해 정확히 한 번 재조회한다.
- 이전 요청의 늦은 응답이 새 pet 화면을 덮지 않도록 request identity를 둔다.
- 로딩 중에는 새 pet 이름과 이전 pet 기록을 섞어 표시하지 않는다.

### H1-H2 — 예정 일정이 사용자 전체 반려동물을 조회함

`GetUpcomingRecordsParams`와 repository의 예정 조회는 `userId`만 사용한다.
건강관리 화면 제목은 선택 pet 기준이므로 다른 pet의 일정이 섞일 수 있다.

권고:

- 예정 조회 계약에 `petId`를 포함한다.
- 사용자 소유권은 서버 RLS, 화면 의미는 `petId` 필터로 각각 보장한다.
- 서버 schema 변경이 필요한지 Claude 검토 snapshot에서 SQL 정본과 대조한다.

### H1-H3 — pet 없음에도 기록 추가가 가능해 보임

pet이 없어도 FAB와 시트가 열리고 저장 단계에서 안내 없이 return할 수 있다.

권고:

- pet 없음에는 FAB 대신 `반려동물 등록` CTA를 제공한다.
- 직접 진입이나 상태 경합에도 같은 일반화 안내를 보장한다.

### H1-H4 — 내부 오류 정보 노출

repository가 `DB 오류`, `e.message`, `e.toString()`을 Failure에 포함하고 메인·PDF가
그 메시지를 사용자 화면에 그대로 표시할 수 있다.

권고:

- load/save/update/delete/PDF별 사용자용 일반화 메시지를 고정한다.
- 기술 세부 정보는 기존 logger 경계에서만 남기고 PII·token·query를 기록하지 않는다.

### H1-H5 — mutation 성공을 서버 응답 전에 가정함

추가·수정 시트는 event 전송 직후 닫히고, 수정 시트 삭제는 즉시 성공 SnackBar를
표시한다. 느린 네트워크에서 중복 제출과 거짓 성공이 생길 수 있다.

권고:

- mutation 종류와 record ID별 pending lock을 둔다.
- 저장·수정은 성공 뒤 닫고, 실패 시 입력값과 시트 상태를 보존한다.
- 삭제 실패는 원래 항목을 복원하고 같은 위치에서 재시도할 수 있게 한다.
- 성공·실패 상태를 접근성 live region으로 전달한다.

### H1-H6 — 건강 알림 설정 진입점 없음

`/health/alert-settings` route는 있으나 제품 화면에서 이동하는 진입점이 없다.
자동 예약은 아직 운영 연결 전이며 현재 화면도 이를 disabled 설명으로 표시한다.

권고:

- 건강 메인에 `건강 도구` 또는 명확한 알림 설정 action을 둔다.
- 자동 예정일 알림과 기기 알림 테스트를 별도 기능으로 표시한다.
- 자동 예약이 연결되기 전에는 활성화 가능한 스위치처럼 보이지 않게 한다.

### H1-H7 — 예정 조회와 화면 D-day의 날짜 정본 불일치

repository는 `scheduled + record_date`로 조회하지만 화면은 `next_date`로 D-day를
계산한다. 완료된 기록의 다음 예정일이 빠지거나 숫자가 비는 일정이 생길 수 있다.

권고:

- `next_date`가 있는 반복 일정과 미래 `record_date`인 예정 기록을 하나의
  `dueDate` 계약으로 결합한다.
- cancelled를 제외하고 record ID로 중복 제거한다.
- 조회, 정렬, D-day 표시가 같은 날짜 정본을 사용한다.

### H1-H8 — entity 동등성 누락으로 수정 상태가 방출되지 않을 수 있음

`HealthRecord.props`에 description, nextDate, data, updatedAt 등 수정 가능한 필드가
빠져 있다.

권고:

- 사용자에게 보이는 모든 의미 필드를 동등성에 포함한다.
- description/nextDate/data 단독 수정 test를 추가한다.

### H1-H9 — mutation 뒤 예정 일정 stale

추가·수정·삭제는 records만 갱신하고 upcoming 목록은 갱신하지 않는다.

권고:

- mutation 성공 뒤 같은 pet의 예정 일정을 서버 정본으로 재조회한다.
- 실패 시 records와 upcoming을 함께 rollback한다.
- pet/request identity가 다른 늦은 결과는 폐기한다.

### H1-H10 — 테스트 알림 성공 판정이 실제 예약 결과와 분리됨

`HealthAlertSettingsPage`는 `scheduleHealthAlert()`가 예외를 던질 때만 실패를
표시하지만, `LocalNotificationService`는 스케줄 예외를 내부에서 삼키고 정상
반환한다. 권한 거부·초기화 실패·예약 실패에도 성공 안내가 나올 수 있다.

권고:

- 로컬 알림 예약은 성공 여부를 호출자에게 전달하는 명시적 결과 계약을 사용한다.
- 실제 예약 성공 뒤에만 테스트 성공 문구를 표시한다.
- 권한 거부와 예약 실패는 일반화된 안내, 재시도 또는 OS 설정 이동으로 분리한다.
- 자동 예정일 알림 미제공 상태와 기기 알림 테스트를 계속 구분한다.

### H1-H11 — `health_records`의 pet-owner 일치 계약 부재

canonical SQL의 health record RLS는 `auth.uid() = user_id`만 확인하고, `pet_id`가
같은 사용자의 반려동물인지 검증하지 않는다. 자신의 user ID와 타인의 pet ID를
조합한 행이 만들어질 수 있어 데이터 소유 관계가 깨질 수 있다.

권고:

- INSERT·UPDATE의 새 행과 기존 행 접근 모두 pet-owner 일치를 확인한다.
- RLS, 복합 FK 또는 trigger 중 최소하고 일관된 정본을 Claude와 확정한다.
- 기존 불일치 행은 운영 환경 읽기 전용 inventory 뒤 migration 방향을 사람이
  승인한다.
- 로컬 SQL·contract test 작성과 운영 migration 적용을 별도 게이트로 분리한다.

### H1-H12 — 수정 화면의 다음 예정일 해제 경로 부재

수정 시트는 기존 `nextDate`를 다른 날짜로 바꿀 수만 있고 `null`로 해제할 수 없다.
예정 일정 정본에 `next_date`를 포함하면 잘못된 일정을 사용자가 제거하지 못한다.

권고:

- 값이 있을 때 명확한 `예정일 해제` action을 제공한다.
- 해제 저장은 `next_date = NULL`로 검증한다.
- pending·실패 입력 보존과 records+upcoming 재조정을 같은 mutation 계약으로
  처리한다.

### H1-M1 — 필터 결과와 건수 의미 불일치

목록은 선택 유형으로 필터링하지만 헤더는 전체 기록 수를 표시한다.

권고:

- 전체 상태는 `전체 n건`, 선택 상태는 `체중 n건`처럼 현재 결과 의미를 표시한다.

### H1-M2 — 유형별 강한 색 사용

백신·검진·체중·투약·수술에 여러 의미색을 배경과 카드에 반복 사용한다.

권고:

- 선택 상태는 브랜드 action color 하나로 통일한다.
- 유형 구분은 아이콘·라벨과 약한 tint만 사용한다.
- 삭제·오류 외 유형에 error 의미색을 사용하지 않는다.
- 신규 hardcoded red를 추가하지 않는다.

### H1-M3 — 접근성·터치 계약 부족

필터와 기록 카드가 `GestureDetector` 중심이고 selected/button 의미와 44dp 계약이
명시되지 않았다.

권고:

- Material interaction, 44dp, selected/button semantics, tooltip을 적용한다.
- 기록 카드에는 편집 가능 의미를 제공한다.
- swipe 삭제 외에도 발견 가능한 삭제 경로를 유지한다.

### H1-M4 — 감정 추이의 empty와 failure 혼합

`EmotionTrendMiniChart`가 repository failure를 빈 데이터로 바꿔
`아직 분석 기록이 없어요`를 표시한다.

권고:

- health 소속 adapter/widget에서 empty와 failure를 구분하고 안전한 재시도를 제공한다.
- `features/emotion/presentation/**`는 수정하지 않는다.
- confidence 백분율과 진단 문구를 새로 노출하지 않는다.

### H1-M5 — presentation의 service locator 직접 사용

메인 PDF export와 감정 추이가 presentation에서 repository를 직접 조회한다.

권고:

- 선택적 loader/repository 주입 또는 화면 전용 controller/BLoC 경계를 사용한다.
- 전역 DI 구조 개편과 Presentation→Supabase 신규 접근은 금지한다.

### H1-M6 — 공유 PDF의 AI 감정 라벨·비율 표현

PDF가 내부 영문 감정 키와 `positiveRatio`를 그대로 표시한다. 한국어 건강 요약서의
완성도를 낮추고 AI 비율이 임상 지표처럼 오인될 수 있다.

권고:

- health 경계에서 승인된 한국어 감정 라벨로 변환한다.
- 공유 PDF에서는 맥락 없는 비율을 제거하고 분석일·대표 감정 중심으로 제한한다.
- AI 분석 화면과 emotion presentation은 수정하지 않는다.
- 새 면책 문구를 작성하지 않고 필요하면 승인된 정본만 연결한다.

### H1-L1 — 미사용 하드코딩 건강 알림 카드

`HealthAlertCard`는 날짜·예방접종 예시가 하드코딩돼 있으나 사용처가 없다.

권고:

- 미사용이 확정되면 제거하거나 entity 입력형 컴포넌트로 전환한다.
- 하드코딩 샘플을 실제 제품 화면에 연결하지 않는다.

## 3. 제안 화면

### 3.1 건강관리 메인 — 기록 있음

- 앱바: `건강관리`, 선택 pet 이름, 건강 도구 진입.
- 예정 일정: 선택 pet 기준의 가장 가까운 일정과 D-day.
- 기록: 현재 필터 의미가 포함된 건수, 단일 브랜드 선택색, 기록 목록.
- 주요 CTA: pet이 있을 때만 `건강 기록 추가`.
- PDF는 건강 도구 또는 명확한 보조 action으로 제공한다.

### 3.2 메인 상태 — pet 없음·기록 없음·오류

- pet 없음: `/pets` 등록 CTA.
- 기록 없음: 첫 기록 추가 CTA.
- 불러오기 실패: 일반화 메시지와 재시도.
- 세 상태 모두 서로 다른 제목·설명·행동을 사용한다.

### 3.3 기록 추가·수정

- 유형: 백신·검진·체중·투약·수술.
- 타입별 validation과 기존 data composition을 보존한다.
- 날짜·다음 예정일·메모를 같은 시트에서 편집한다.
- 저장 중 중복 제출을 막고 진행 상태를 표시한다.
- 실패하면 시트를 닫지 않고 입력값을 보존한다.
- 삭제는 서버 성공 이후에만 성공을 표시한다.

### 3.4 건강 도구 — 알림·PDF

- 자동 예정일 알림: 운영 연결 전에는 `준비 중`으로 비활성 표시.
- 알림 테스트: 기기 권한과 수신 여부 확인 기능으로 분리.
- 테스트 알림은 service가 실제 예약 성공을 반환한 경우에만 성공으로 표시.
- 권한 거부·예약 실패는 성공 문구 없이 재시도 또는 OS 설정 이동을 제공.
- PDF: 선택 pet 기록만 사용한다는 설명과 미리보기 진입.
- PDF AI 요약은 승인된 한국어 감정 라벨만 사용하고 맥락 없는 비율은 표시하지 않음.
- PDF 생성 실패는 일반화 메시지만 표시한다.

## 4. Codex 권고 구현 순서

### H1A — 데이터·상태 정확성

1. selected pet change 감지와 request identity를 추가한다.
2. upcoming 조회를 `userId + petId + dueDate` 계약으로 정렬한다.
3. entity 동등성에 사용자 의미 필드를 모두 포함한다.
4. health record의 pet-owner 일치 계약과 migration 경계를 확정한다.
5. load와 mutation의 raw-error 노출을 차단한다.
6. mutation pending/outcome 상태를 BLoC에 추가한다.
7. 추가·수정·삭제 UI와 다음 예정일 해제를 서버 결과에 연결한다.
8. 모든 mutation 뒤 upcoming을 재조정한다.

### H1B — 메인 UI/UX

1. pet identity·예정 일정·기록 헤더 계층을 정리한다.
2. 필터 선택색과 표시 건수를 현재 결과에 맞춘다.
3. pet 없음·기록 없음·오류 상태를 분리한다.
4. 필터·카드·CTA에 44dp와 semantics를 적용한다.
5. 건강 도구 진입을 메인에 연결한다.

### H1C — 보조 흐름

1. 자동 알림 미제공과 알림 테스트를 명확히 분리한다.
2. 로컬 알림 예약 결과를 호출자에게 전달하고 거짓 성공 안내를 제거한다.
3. PDF 준비·실패·미리보기 피드백을 정리한다.
4. PDF의 AI 감정 라벨을 한국어로 정돈하고 맥락 없는 비율을 제거한다.
5. 감정 추이 empty/failure를 health 경계에서 분리한다.
6. presentation 직접 repository 접근을 테스트 가능한 경계로 이동한다.
7. 미사용 `HealthAlertCard` 처리 방향을 확정한다.

## 5. 보존 계약

- 기록 유형과 enum 의미
- 유형별 validation/data composition 순수 함수
- 선택 pet 기준 기록 조회
- 체중 추이와 감정 추이의 기존 기능 의미
- PDF 온디바이스 생성·미리보기·공유
- empty pet CTA `/pets`
- 자동 건강 알림 미제공 사실
- 서버 record 기반 D-day
- 수의학적 진단·치료 권고 금지
- 홈·AI 분석·하단 5탭 UI 보호

## 6. Claude 공동 검토 후보 manifest

이 목록은 read-only 기획 검토 후보이며 구현 manifest가 아니다.

### 제품 소스

1. `pjh/lib/config/injection_container.dart`
2. `pjh/lib/core/navigation/app_router.dart`
3. `pjh/lib/core/services/local_notification_service.dart`
4. `pjh/lib/shared/themes/app_theme.dart`
5. `pjh/lib/features/auth/presentation/bloc/auth_bloc.dart`
6. `pjh/lib/features/emotion/domain/entities/emotion_analysis.dart`
7. `pjh/lib/features/pets/domain/entities/pet.dart`
8. `pjh/lib/features/pets/presentation/bloc/pet_bloc.dart`
9. `pjh/lib/features/pets/presentation/bloc/pet_state.dart`
10. `pjh/lib/features/health/data/models/health_record_model.dart`
11. `pjh/lib/features/health/data/repositories/health_repository_impl.dart`
12. `pjh/lib/features/health/domain/entities/health_record.dart`
13. `pjh/lib/features/health/domain/repositories/health_repository.dart`
14. `pjh/lib/features/health/domain/usecases/get_health_records.dart`
15. `pjh/lib/features/health/domain/usecases/get_upcoming_records.dart`
16. `pjh/lib/features/health/presentation/bloc/health_bloc.dart`
17. `pjh/lib/features/health/presentation/bloc/health_event.dart`
18. `pjh/lib/features/health/presentation/bloc/health_state.dart`
19. `pjh/lib/features/health/presentation/pages/health_main_page.dart`
20. `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
21. `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
22. `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
23. `pjh/lib/features/health/presentation/widgets/health_record_card.dart`
24. `pjh/lib/features/health/presentation/widgets/health_record_data.dart`
25. `pjh/lib/features/health/presentation/widgets/health_pdf_data.dart`
26. `pjh/lib/features/health/presentation/widgets/emotion_trend_mini_chart.dart`
27. `pjh/lib/features/health/presentation/widgets/weight_trend_chart.dart`
28. `pjh/lib/features/health/presentation/widgets/health_alert_card.dart`
29. `pjh/lib/features/health/presentation/widgets/health_pdf_generator.dart`

### 테스트·계약

30. `pjh/test/features/health/domain/usecases/health_usecases_test.dart`
31. `pjh/test/features/health/presentation/health_record_data_test.dart`
32. `pjh/test/features/health/presentation/weight_trend_test.dart`
33. `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`
34. `pjh/test/features/health/presentation/health_pdf_data_test.dart`
35. `supabase/petspace_setup.sql`의 `health_records`·RLS·trigger 관련 구간

### 기획 자료

36. `docs/reviews/2026-07-19-health-h1-preliminary-audit.md`
37. `docs/work-orders/2026-07-19-uiux-health-h1-draft.md`
38. `health-h1-preliminary-mockup.html`의 Claude 검토용 고정 복사본

## 7. Claude 판정 질문

1. selected-pet stale state와 user-wide upcoming을 blocker/high 중 무엇으로 분류할지.
2. `next_date`와 미래 `record_date`를 결합한 due-date 계약이 맞는지.
3. upcoming에 `petId`와 due-date 조건을 추가할 때 schema/RLS 변경 없이
   repository 계약만으로 충분한지.
4. entity 동등성 누락과 mutation 뒤 upcoming stale을 같은 wave에서 닫아야 하는지.
5. mutation 시트를 성공까지 유지하는 패턴이 현재 BLoC 구조에서 가장 안전한지.
6. 자동 예약 미제공 상태에서도 제품 진입점을 노출할지, 알림 테스트만 별도 둘지.
7. 로컬 알림 예약 결과 계약을 bool/result/exception 중 무엇으로 정본화할지.
8. pet-owner 일치 보장을 RLS·복합 FK·trigger 중 어디에 둘지와 기존 행 감사 방법.
9. 다음 예정일 해제와 due-date/upcoming 재조정을 같은 mutation 계약으로 닫는지.
10. 감정 추이가 건강관리 핵심인지 보조인지와 empty/failure 표시 수준.
11. PDF의 AI 영문 라벨·비율을 제거하는 최소 계약과 개인정보 안내 필요 여부.
12. 후보 review manifest에 빠진 증거 파일이나 불필요한 파일이 있는지.
13. 서버 schema 변경 없이 구현 가능한 범위와 별도 운영 gate가 무엇인지.

## 8. 구현 manifest 확정 규칙

1. Feed F2가 Codex·Claude 양쪽 approve 상태여야 한다.
2. Claude가 H1 기획·목업을 검토하고 blocker/high/medium을 제시한다.
3. Codex가 findings를 반영해 동일 합의안을 기록한다.
4. 합의된 화면과 정확한 구현 파일 manifest를 사용자에게 제시한다.
5. 사용자가 승인하기 전에는 H1 Flutter 코드를 수정하지 않는다.
6. 운영 DB migration·Edge 배포·법무 문구는 별도 승인이다.

## 9. 자동 검증 후보

- H1 대상 domain/repository/BLoC/widget tests
- 작은 화면과 150% 글자 크기
- pet change stale-response test
- upcoming pet-scope·due-date·dedupe·sort test
- description·nextDate·data 단독 수정 emission test
- mutation 뒤 upcoming 재조정·rollback test
- mutation 중복 제출·성공·실패·입력 보존 test
- empty pet·empty records·load error test
- alert unavailable/test-notification separation test
- PDF safe-error test
- `flutter analyze --no-pub`
- 전체 `flutter test --no-pub`
- `git diff --check`
- 정확한 manifest와 보호 hash 확인
- Codex·Claude blocker/high/medium 0

## 10. 마지막 실기기 통합 검증으로 이관

- pet 전환 직후 이름·기록·예정 일정 일치
- pet 0마리·1마리·여러 마리
- 기록 추가·수정·삭제 성공과 네트워크 실패
- 키보드·작은 화면·150% 글자 크기
- 필터별 표시 건수와 카드 목록
- 알림 권한 허용·거부와 테스트 알림
- 자동 건강 알림 미제공 설명
- PDF 생성·미리보기·공유·실패
- 느린 네트워크·오프라인·복구
