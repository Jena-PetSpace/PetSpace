# PetSpace 건강관리 H1A 작업지시서

## 상태

- Codex 기획: 승인
- Claude Fable 5 기획 검토: 승인
- 기획 검토 manifest:
  `e15e22974110b756f6337af746a591a15669935a8429bc5f2e2b08782c1ad899`
- 실행자: Codex
- 운영 DB migration 적용: 미승인·미실행
- commit, merge, push, deploy: 미실행

## 목표

건강관리 화면을 꾸미기 전에 잘못된 반려동물 기록, 불일치한 예정일,
서버 응답 전 성공 표시를 제거한다. `HealthBloc`을 조회와 mutation의
단일 상태 소유자로 유지하고 UI는 BLoC의 확정 결과만 표시한다.

## 합의된 계약

1. 반려동물 선택이 바뀌면 새 pet ID로 한 번 다시 조회하며, 이전 pet의
   늦은 응답은 현재 화면을 덮지 않는다.
2. 예정 일정은 `userId + petId`로 제한한다.
3. 정본 `dueDate`는 `next_date`를 우선하고, 값이 없는 예정 기록만
   `record_date`를 사용한다. cancelled는 제외하고 record ID로 중복을
   제거한 뒤 `dueDate`로 정렬한다.
4. `HealthRecord` 동등성에는 사용자에게 보이는 수정 가능 필드가 모두
   포함되며 `description`과 `nextDate`를 명시적으로 null로 바꿀 수 있다.
5. 추가·수정·삭제는 operation ID별 pending/outcome을 가지며 중복 제출을
   막는다. 시트는 Repository 성공 뒤에만 닫고 실패하면 입력을 보존한다.
6. mutation 성공 뒤 현재 pet의 예정 목록을 다시 조회한다. 실패 또는
   pet 전환 시 이전 화면 상태를 복원하거나 늦은 결과를 폐기한다.
7. repository의 PostgREST/exception 상세는 UI에 노출하지 않고 고정된
   안전 문구만 반환한다.
8. pet이 없으면 FAB를 숨기고 반려동물 등록 CTA만 제공한다.
9. 수정 화면은 기존 `next_date`를 명시적으로 해제할 수 있다.
10. health record RLS는 `user_id = auth.uid()`와 함께 `pet_id`가 같은
    사용자의 pet인지 확인한다. 로컬 migration과 fresh-setup SQL만
    정렬하며 운영 DB 적용 전 읽기 전용 불일치 inventory와 사람 승인이
    필요하다.

## 정확한 구현 manifest

### 앱 소스 10개

1. `pjh/lib/core/error/error_messages.dart`
2. `pjh/lib/features/health/data/repositories/health_repository_impl.dart`
3. `pjh/lib/features/health/domain/entities/health_record.dart`
4. `pjh/lib/features/health/domain/repositories/health_repository.dart`
5. `pjh/lib/features/health/domain/usecases/get_upcoming_records.dart`
6. `pjh/lib/features/health/presentation/bloc/health_bloc.dart`
7. `pjh/lib/features/health/presentation/bloc/health_event.dart`
8. `pjh/lib/features/health/presentation/bloc/health_state.dart`
9. `pjh/lib/features/health/presentation/pages/health_main_page.dart`
10. `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`

### 테스트 4개

11. `pjh/test/contracts/h1_health_contract_test.dart`
12. `pjh/test/features/health/domain/entities/health_record_test.dart`
13. `pjh/test/features/health/domain/usecases/health_usecases_test.dart`
14. `pjh/test/features/health/presentation/bloc/health_bloc_test.dart`

### 로컬 SQL 2개

15. `supabase/petspace_setup.sql`
16. `supabase/migrations/L1_health_record_owner_contract.sql`

이 문서는 검토 증거로 별도 보관하며 구현 파일 수에는 포함하지 않는다.

## 보호 범위

- `pjh/lib/features/social/presentation/pages/home_page.dart`
- `pjh/lib/features/home/**`
- `pjh/lib/features/emotion/presentation/**`
- `pjh/lib/main_navigation.dart`
- 하단 5탭 UI
- 운영 DB, Edge, 법무 문구

## 검증

- due-date, null clear, entity equality 단위 테스트
- pet 전환 late-response 폐기 테스트
- upcoming pet scope 및 mutation 뒤 재조회 테스트
- mutation 성공·실패·입력 보존 테스트
- RLS fresh setup/migration 정렬 계약 테스트
- 기존 health 테스트
- 전체 `flutter test --no-pub`
- `flutter analyze --no-pub`
- `git diff --check`
- 정확한 manifest 및 보호 hash 검사
- Codex 구현 리뷰와 Claude Fable 5 동일 번들 리뷰

## 다음 wave

H1A가 양쪽 리뷰를 통과한 뒤 H1B에서 승인된 메인 화면 계층, 필터,
빈 상태·오류 상태, 44dp 접근성 및 건강 도구 진입 UI를 구현한다.
