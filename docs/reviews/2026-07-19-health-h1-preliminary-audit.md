# PetSpace 건강관리 H1 예비 코드 감사

- 작성일: 2026-07-19
- 작성자: Codex 예비 감사
- 상태: Feed F2 완료 뒤 Claude 공동 기획 전
- 목적: 다음 탭 작업을 앞당겨 구현하지 않고, 화면·계약·테스트 현황만 고정
- 금지: 이 문서만으로 Flutter·DB·Edge 구현을 시작하지 않는다.
- 보호: 홈, AI 분석 탭, `features/emotion/presentation/**`,
  `main_navigation.dart`, 하단 5탭 UI

## 1. 현재 화면 인벤토리

| 화면/표면 | 경로 | 현재 진입 | 역할 |
|---|---|---|---|
| 건강관리 메인 | `/health` | 하단 건강관리 탭 | 선택 반려동물 기록·추이·예정 일정·PDF |
| 기록 추가 시트 | 메인 FAB | 메인 | 백신·검진·체중·투약·수술 기록 |
| 기록 수정 시트 | 기록 카드 | 메인 | 유형·상태·날짜·메모 수정, 삭제 |
| 건강 알림 설정 | `/health/alert-settings` | 라우트만 존재 | 로컬 테스트 알림과 미제공 자동 예약 안내 |
| 건강 PDF 미리보기 | Material route | 메인 PDF 버튼 | 건강 요약서 생성·공유 |

현재 widget/page test는 없다. 존재하는 테스트는 usecase, 기록 data 변환, 체중·감정
차트 순수 로직, PDF data 중심이다.

## 2. 확인된 사실

### H1-H1. 선택 반려동물 변경 시 기록을 다시 읽지 않는다

`HealthMainPage`는 `initState`에서만 `_loadHealthData()`를 호출한다. `PetBloc`은
화면 제목의 반려동물 이름을 다시 그리지만, 선택 pet ID가 달라져도 HealthBloc
재조회 event를 보내지 않는다.

영향:

- 제목은 새 반려동물인데 기록·예정 일정은 이전 반려동물일 수 있다.
- 기록 추가 시트는 현재 선택 pet ID를 사용하므로 기존 목록과 새 mutation 대상이
  섞일 수 있다.

권고:

- `BlocListener` 또는 선택 pet ID 추적으로 ID 변경 때 한 번만 reload한다.
- 이전 pet 요청의 늦은 응답이 새 pet 상태를 덮지 않도록 request identity를 둔다.

### H1-H2. 예정 일정이 선택 반려동물이 아니라 사용자 전체를 조회한다

`GetUpcomingRecordsParams`와 repository는 `userId`만 전달하고
`health_records.user_id`로 조회한다. 메인 제목은 `OOO의 건강 기록`이므로 다른
반려동물의 예정 일정이 섞일 수 있다.

권고:

- selected `petId`를 정본 조건으로 포함한다.
- 사용자 ID는 소유권 권한 근거로 클라이언트에서 신뢰하지 않는다. 현재 RLS 계약을
  별도 검토하고 Flutter 필터는 표시 정합을 위해 사용한다.

### H1-H3. 반려동물이 없어도 FAB가 활성화된다

빈 pet 상태에서도 `건강 기록 추가` FAB가 보이고 시트를 열 수 있다. 저장 단계에서
pet이 없으면 아무 안내 없이 return한다.

권고:

- pet 없음에는 FAB를 숨기거나 등록 CTA로 의미를 바꾼다.
- 직접 진입·상태 경합에도 일반화된 안내가 있어야 한다.

### H1-H4. 사용자 화면에 backend 상세 오류가 노출될 수 있다

- repository의 `PostgrestException`은 `DB 오류: ${e.message}`를 Failure로 반환한다.
- add/update/delete/upcoming의 일부 catch는 `${e.toString()}`을 포함한다.
- `HealthMainPage`는 `HealthError.message`와 `HealthLoaded.error`를 그대로 표시한다.
- PDF preview는 `PDF 생성에 실패했습니다: $error`를 그대로 표시한다.

권고:

- 사용자 문구는 load/save/delete/PDF별 일반화된 메시지로 고정한다.
- 상세는 기존 logger 경계에서만 기록하고 PII·token·query를 남기지 않는다.

### H1-H5. 저장·수정·삭제 성공을 서버 성공 전에 가정한다

- 추가·수정 시트는 event 전송 직후 닫히며 pending lock이나 결과 상태가 없다.
- 수정 시트 삭제는 event 전송 직후 `기록을 삭제했어요`를 표시한다.
- swipe 삭제는 optimistic rollback이 있으나 실패 안내가 목록 하단의 작은 텍스트다.

영향:

- 느린 네트워크에서 중복 제출할 수 있다.
- 실패했는데 성공으로 인식하거나 오류를 못 볼 수 있다.

권고:

- mutation ID/record ID별 pending 상태를 둔다.
- 성공 안내와 sheet 종료는 repository 성공 뒤에만 수행한다.
- 실패 시 입력과 원래 항목을 보존하고 같은 위치에서 재시도한다.

### H1-H6. 건강 알림 설정 라우트에 제품 진입점이 없다

`/health/alert-settings`는 등록돼 있으나 `pjh/lib`에서 해당 경로로 이동하는
코드는 발견되지 않았다. 메인 앱바에는 PDF만 있다.

권고:

- 건강 메인 앱바 또는 기록 섹션의 명확한 설정 action으로 연결한다.
- 자동 예약 미제공 상태는 현재의 정직한 disabled 설명을 유지한다.
- 테스트 알림과 자동 예약을 같은 기능처럼 오해하지 않게 구분한다.

### H1-H7. 예정 일정 조회 기준과 화면 D-day 기준이 다르다

`HealthRepositoryImpl.getUpcomingRecords`는 `status = scheduled`이며
`record_date`가 30일 안인 행을 조회한다. 반면 메인의 예정 일정 문구는
`HealthRecord.daysUntilNext`, 즉 `next_date`를 기준으로 D-day를 표시한다.

영향:

- 완료된 백신 기록에 다음 접종일(`next_date`)을 넣어도 예정 일정에서 빠질 수 있다.
- 미래 `record_date`는 조회되지만 `next_date`가 없으면 `D` 뒤 숫자가 비어 보일 수 있다.
- 조회 정렬과 사용자에게 보이는 날짜가 서로 다를 수 있다.

권고:

- `dueDate` 정본을 하나로 정의한다.
- `next_date`가 있는 반복 일정과 미래 `record_date`인 예정 기록을 모두 포함하되
  cancelled는 제외하고 record ID로 중복 제거한다.
- 표시·정렬·D-day가 같은 `dueDate`를 사용하게 한다.
- 기존 컬럼으로 닫을 수 있는지 SQL/RLS와 대조한다.

### H1-H8. HealthRecord 동등성에서 수정 가능한 필드가 빠져 있다

`HealthRecord.props`는 id, petId, recordType, title, recordDate, status만 포함한다.
description, nextDate, data, updatedAt 등만 바뀌면 이전 entity와 같다고 판단될 수 있다.
`HealthLoaded`는 record 목록을 props에 포함하므로 BLoC 상태 emission이 누락될 수 있다.

권고:

- 사용자에게 보이는 모든 entity 의미 필드를 동등성에 포함한다.
- description, nextDate, data만 바뀌는 수정 test를 추가한다.

### H1-H9. mutation 뒤 예정 일정 목록이 갱신되지 않는다

추가·수정·삭제 성공 시 `HealthBloc`은 `records`만 갱신하고
`upcomingAlerts`는 그대로 둔다. 삭제의 optimistic 단계도 예정 목록에서는 항목을
제거하지 않는다.

권고:

- 성공한 mutation 뒤 같은 pet의 예정 일정을 서버 정본으로 다시 조회하거나,
  하나의 검증된 due-date projector로 records와 upcoming을 함께 갱신한다.
- 실패 rollback은 records와 upcoming 모두 원래 상태로 복원한다.
- 늦은 mutation 결과가 다른 pet 상태에 적용되지 않도록 pet/request identity를 확인한다.

### H1-H10. 테스트 알림이 실제 예약 실패에도 성공으로 표시될 수 있다

`HealthAlertSettingsPage._sendTestNotification()`은
`LocalNotificationService.scheduleHealthAlert()` 호출이 예외를 던질 때만 실패를
표시한다. 하지만 service는 스케줄링 예외를 내부에서 로그로만 남기고 정상 반환한다.
초기화 실패, 권한 거부 또는 플러그인 예약 실패가 발생해도 화면은
`5초 뒤 테스트 알림이 도착합니다`라고 안내할 수 있다.

권고:

- 예약 API가 성공·실패를 호출자에게 전달하는 명시적 결과 계약을 사용한다.
- 테스트 화면은 실제 예약 성공이 확인된 경우에만 성공 문구를 표시한다.
- 권한 거부와 예약 실패는 일반화된 안내와 재시도 또는 OS 설정 이동을 제공한다.
- 로그에는 토큰·사용자 건강정보·내부 payload를 남기지 않는다.

### H1-H11. 건강 기록의 `pet_id`와 소유자 일치가 DB에서 보장되지 않는다

`health_records`의 SELECT·INSERT·UPDATE·DELETE RLS는 `auth.uid() = user_id`만
확인한다. `pet_id`가 실제로 같은 사용자의 반려동물인지 확인하는 policy, trigger
또는 복합 FK는 canonical SQL에서 발견되지 않았다. 인증 사용자가 자신의
`user_id`와 다른 사용자의 `pet_id`를 조합한 행을 만들거나 갱신할 수 있어
건강 데이터의 소유 관계가 깨질 수 있다.

권고:

- INSERT와 UPDATE의 새 행은 `pets.id = pet_id AND pets.user_id = auth.uid()`를
  만족해야 한다.
- SELECT·DELETE 및 기존 행의 UPDATE 대상도 같은 소유 관계를 보존한다.
- RLS 보강과 복합 FK/trigger 중 정본 방식을 Claude와 검토하고 migration으로
  분리한다.
- 기존 불일치 행은 운영 migration 전에 읽기 전용 inventory로 확인하고 자동
  수정하지 않는다.

### H1-H12. 수정 화면에서 기존 다음 예정일을 해제할 수 없다

기록 수정 시트는 기존 `nextDate`를 다시 선택하는 날짜 picker만 제공한다.
이미 저장된 다음 예정일을 `null`로 되돌리는 action이 없어, 반복 일정이 끝나거나
잘못 입력된 날짜를 제거할 수 없다. 예정 목록이 `next_date`를 정본에 포함하면
사용자가 없애지 못한 일정이 계속 노출될 수 있다.

권고:

- 다음 예정일이 있을 때 발견 가능한 `예정일 해제` action을 제공한다.
- 해제 저장은 DB의 `next_date = NULL`로 확인한다.
- 입력 보존·pending·실패 복구 계약을 일반 수정과 동일하게 적용한다.
- 해제 성공 뒤 upcoming 목록과 D-day를 즉시 재조정한다.

### H1-M1. 필터 결과 수와 표시 count가 다르다

메인 `n건`은 전체 record 수를 표시하고, 아래 목록은 선택 filter로 좁힌다.

권고:

- `전체 n건`, 또는 선택 상태에서는 `체중 n건`처럼 현재 결과 의미를 명확히 한다.

### H1-M2. 유형 필터와 카드의 색 사용이 과하다

유형별로 success/accent/highlight/secondary/error 등 여러 강한 색을 선택 배경과
카드에 반복해 UI가 기능보다 장식 중심으로 보일 수 있다.

권고:

- 선택 상태는 브랜드 action color 하나로 통일한다.
- 유형은 아이콘·라벨의 약한 tint만 사용한다.
- 삭제·오류 외의 유형에 error 의미색을 사용하지 않는다.
- 새 hardcoded red를 추가하지 않는다.

### H1-M3. 접근성과 터치 계약이 불명확하다

- 필터 `_typeChip`은 `GestureDetector`이며 선택 semantics와 최소 44dp가 명시되지 않았다.
- 기록 카드는 `GestureDetector`이고 편집 가능 의미가 TalkBack에 드러나지 않는다.
- swipe 삭제만 알고 있는 사용자를 위해 수정 시트 삭제가 있으나 실패 상태는
  접근 가능한 live region이 아니다.

권고:

- Material interaction, 44dp, selected/button semantics, tooltip을 적용한다.
- pending/success/failure를 screen reader가 구분하게 한다.

### H1-M4. 감정 추이 위젯이 실패를 빈 상태로 합친다

`EmotionTrendMiniChart`는 repository failure를 빈 포인트로 바꿔
`아직 분석 기록이 없어요`를 표시한다.

권고:

- 실제 empty와 load failure를 분리하고 안전한 재시도를 제공한다.
- AI 분석 화면·emotion presentation 코드는 수정하지 않는다.
- health 소속 adapter/widget 범위에서만 연결을 정돈한다.

### H1-M5. 메인과 PDF가 presentation에서 service locator를 직접 사용한다

메인 PDF export와 감정 추이 위젯이 `sl<EmotionRepository>()`를 직접 읽는다.
기존 코드의 기술 부채이며 새 presentation→Supabase 직접 접근은 아니지만
widget test와 상태 일관성을 어렵게 한다.

권고:

- 선택적 repository/loader 주입 또는 BLoC/controller 경계로 이동한다.
- 전역 DI 개편은 하지 않는다.

### H1-M6. 공유 PDF의 AI 감정 요약이 영문 키와 비율을 그대로 노출한다

`HealthPdfGenerator._analysisSection()`은 `dominantEmotion`의 내부 영문 키와
`positiveRatio`를 `대표 감정: happiness · 긍정도 75%` 형태로 공유 PDF에 넣는다.
한국어 건강 요약서의 정보 체계와 맞지 않고, 맥락 없는 AI 비율이 임상적 수치처럼
오인될 수 있다.

권고:

- health 소속 adapter에서 승인된 한국어 감정 라벨만 사용한다.
- 공유 PDF에서는 맥락 없는 AI 비율을 제거하고 분석일·대표 감정 정도로 제한한다.
- AI 분석 화면이나 `features/emotion/presentation/**`는 수정하지 않는다.
- 추가 고지가 필요하면 새 문구를 만들지 않고 승인된 정본을 사용한다.

### H1-L1. 미사용 하드코딩 건강 알림 카드가 존재한다

`HealthAlertCard`는 `예방접종 D-37`, `2026.04.15`를 하드코딩하지만 사용처가 없다.

권고:

- 미사용이 확정되면 삭제하거나 실제 entity 입력을 받는 컴포넌트로 교체한다.
- 하드코딩 샘플을 제품 화면에 연결하지 않는다.

## 3. 보존할 현재 계약

- 기록 유형: 백신·검진·체중·투약·수술
- 유형별 validation/data composition 순수 함수
- 선택 pet 기준 기록 조회와 record entity 의미
- filter, weight trend, emotion trend의 기본 기능
- empty pet CTA `/pets`
- PDF 생성·미리보기·공유 기능
- 자동 건강 알림은 아직 제공되지 않는다는 정직한 disabled 상태
- D-day 일정은 서버 record 정본에서 계산
- 수의학적 진단·치료 권고로 오인되는 문구를 추가하지 않음

## 4. H1 공동 목업 후보 4화면

1. 건강관리 메인 — 기록 있음
   - 반려동물 identity, 요약, 예정 일정, 기록 필터와 목록
2. 건강관리 메인 — pet 없음/기록 없음/오류
   - 상태별 CTA와 재시도
3. 기록 추가·수정 시트
   - 유형 선택, 동적 필드, 날짜, pending·failure
4. 건강 알림·PDF 보조 흐름
   - 알림 미제공 경계와 테스트 알림
   - PDF 준비/오류/미리보기 진입

최종 목업은 Codex 초안 → Claude Fable 5 우선 리뷰 → 한도 시 Opus 4.8
→ 양쪽 합의 → 사용자 승인 순서로 만든다.

## 5. 다음 공동 리뷰에 포함할 최소 소스

### 제품 소스

- `pjh/lib/features/health/data/repositories/health_repository_impl.dart`
- `pjh/lib/features/health/data/models/health_record_model.dart`
- `pjh/lib/features/health/domain/entities/health_record.dart`
- `pjh/lib/features/health/domain/repositories/health_repository.dart`
- `pjh/lib/features/health/domain/usecases/get_health_records.dart`
- `pjh/lib/features/health/domain/usecases/get_upcoming_records.dart`
- `pjh/lib/features/health/presentation/bloc/health_bloc.dart`
- `pjh/lib/features/health/presentation/bloc/health_event.dart`
- `pjh/lib/features/health/presentation/bloc/health_state.dart`
- `pjh/lib/features/health/presentation/pages/health_main_page.dart`
- `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
- `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_card.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_data.dart`
- `pjh/lib/features/health/presentation/widgets/health_pdf_data.dart`
- `pjh/lib/features/health/presentation/widgets/emotion_trend_mini_chart.dart`
- `pjh/lib/features/health/presentation/widgets/weight_trend_chart.dart`
- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/core/services/local_notification_service.dart`
- `pjh/lib/config/injection_container.dart`
- `pjh/lib/features/pets/domain/entities/pet.dart`
- `pjh/lib/features/emotion/domain/entities/emotion_analysis.dart`

### 테스트·계약

- `pjh/test/features/health/domain/usecases/health_usecases_test.dart`
- `pjh/test/features/health/presentation/health_record_data_test.dart`
- `pjh/test/features/health/presentation/weight_trend_test.dart`
- `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`
- `pjh/test/features/health/presentation/health_pdf_data_test.dart`
- `supabase/petspace_setup.sql`의 health_records/RLS/trigger 관련 구간

이 목록은 review manifest 후보이며 implementation manifest가 아니다.

## 6. 공동 리뷰 질문

1. pet 변경 stale state와 사용자 전체 upcoming 조회를 blocker/high로 봐야 하는가?
2. 예정 일정 정본을 `next_date`와 미래 `record_date` 중 어떻게 결합할 것인가?
3. mutation sheet를 repository 성공까지 유지할지, 닫은 뒤 전역 상태로 결과를
   전달할지 어느 패턴이 키보드·실패 복구에 더 안전한가?
4. 자동 예약 미제공 상태에서 알림 설정 진입점을 노출하는 것이 정직한가, 아니면
   테스트 알림만 별도 개발/진단 표면으로 분리해야 하는가?
5. 감정 추이는 건강관리 핵심 정보인가, 보조 카드인가? AI 분석 화면 보호 범위를
   건드리지 않으면서 failure/empty를 어떻게 구분할 것인가?
6. PDF에 포함되는 보호자·반려동물·건강 기록의 개인정보 안내가 필요한가?
7. 4화면 목업 후보와 review manifest가 충분한가?
8. 서버 schema/RLS 변경 없이 닫을 수 있는 범위와 별도 운영 gate는 무엇인가?

## 7. 현재 판정

- H1 구현 승인: 없음
- H1 목업 사용자 승인: 없음
- Claude 공동 리뷰: 미실행
- Flutter 소스 변경: 없음
- 다음 행동: Feed F2를 먼저 마감한 뒤 이 감사 문서를 current-source snapshot과
  함께 Claude가 검토하고, 합의된 작업지시서·목업을 사용자에게 제시
