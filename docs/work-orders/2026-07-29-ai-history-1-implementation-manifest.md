# AIH-1 AI 분석 기록 구현 manifest

> 기준 브랜치: `feature/ai-history-1`
> 기준 HEAD: `22bad96642624f6128a7840b9a5d82b616236934`
> 승인 기획 SHA-256: `786650f8df07d82494f96d396d312f442a55707ce3698b3139c3316ce833c8c4`
> 승인 범위: 목업 A~D, E-1, S

## 구현 원칙

- 신규 분석 직후 결과, AI API 프롬프트와 응답 필드는 변경하지 않는다.
- 기록에서 연 상세만 `fromHistory=true`로 분기한다.
- 운영 DB/RPC, Edge, 배포는 변경하지 않는다.
- G(소셜 진입점 제거), F0(삭제 안내 수정), E-2(신규 결과 재설계)는 포함하지 않는다.
- 기록 화면의 신규 조회는 Repository를 통하고 Presentation에서 Supabase를 직접 호출하지 않는다.

## 정확한 구현 파일

### 신규

1. `docs/work-orders/2026-07-29-ai-history-1-implementation-manifest.md`
2. `pjh/lib/features/emotion/domain/entities/ai_history.dart`
3. `pjh/lib/features/emotion/presentation/bloc/ai_history_bloc.dart`
4. `pjh/lib/features/emotion/presentation/bloc/emotion_memo_cubit.dart`
5. `pjh/lib/features/emotion/presentation/models/ai_history_presentation.dart`
6. `pjh/lib/features/emotion/presentation/widgets/history/ai_history_filter_sheet.dart`
7. `pjh/lib/features/emotion/presentation/widgets/history/ai_history_record_card.dart`
8. `pjh/lib/features/emotion/presentation/widgets/result/history_result_banner.dart`
9. `pjh/test/features/emotion/ai_history_presentation_test.dart`
10. `pjh/test/features/emotion/ai_history_bloc_test.dart`
11. `pjh/test/features/emotion/emotion_result_loader_page_test.dart`
12. `pjh/test/features/emotion/emotion_timeline_page_test.dart`

### 수정

13. `pjh/lib/features/emotion/domain/entities/health_analysis.dart`
14. `pjh/lib/features/emotion/domain/repositories/emotion_repository.dart`
15. `pjh/lib/features/emotion/data/models/emotion_analysis_model.dart`
16. `pjh/lib/features/emotion/data/models/health_analysis_model.dart`
17. `pjh/lib/features/emotion/data/repositories/emotion_repository_impl.dart`
18. `pjh/lib/features/emotion/presentation/pages/ai_history_page.dart`
19. `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart`
20. `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`
21. `pjh/lib/features/emotion/presentation/pages/health_result_page.dart`
22. `pjh/lib/features/emotion/presentation/pages/emotion_timeline_page.dart`
23. `pjh/lib/core/navigation/app_router.dart`
24. `pjh/lib/features/social/presentation/widgets/create_post_bottom_sheet.dart`
25. `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
26. `pjh/lib/features/emotion/presentation/widgets/result/bottom_action_bar.dart`
27. `pjh/lib/features/emotion/presentation/widgets/result/health_next_action_card.dart`
28. `pjh/lib/features/emotion/presentation/widgets/result/health_score_card.dart`

## 완료 조건

- 기록/흐름 2영역과 펫 범위·유형·기간·건강 확인 필터가 실제 조회에 적용된다.
- 감정과 건강 기록이 하나의 최신순 페이지로 합쳐지고 다음 페이지가 중복 없이 이어진다.
- 선택 모드는 감정 기록만 반환하며 실제 활성 펫 이름을 표시용 복사본에만 주입한다.
- ID loader는 항상 기록 모드로 상세를 열어 신규 분석 INSERT 이벤트를 보내지 않는다.
- 감정 기록 메모는 동일 ID UPDATE 성공 때만 성공 안내를 표시한다.
- 건강 기록 메모는 저장 가능한 것처럼 노출하지 않는다.
- 비소유·삭제 펫 타임라인은 RPC를 호출하지 않고 보호 안내를 표시한다.
- 목록과 흐름에 퍼센트·신뢰도·진단 문구를 새로 노출하지 않는다.
- Flutter format, analyze, 관련 테스트, diff check, 독립 리뷰를 통과한다.
