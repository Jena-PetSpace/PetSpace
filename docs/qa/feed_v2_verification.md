# 피드 재편 v2 (발견/라운지) 배포·검증 체크리스트

- 작성일: 2026-07-09 / 브랜치: win-android-release (구간 1~6 커밋, push 보류)
- 작업지시서: PetSpace_피드P0_작업지시서_v1 §C (P0-V)
- 표기: 🟦=대시보드 수동 작업, 📱=실기기 검증

## 0. 🟦 선행 — SQL 적용
- [ ] `supabase/manual_sql/history/posts_category.sql` 적용 여부 확인
- [ ] `supabase/manual_sql/history/posts_category_v2.sql`의 COMMENT 반영 여부 확인
  - 신 체계: chat(잡담)/brag(자랑)/qa(궁금해요)/info(정보). 백필 없음(설계 결정).

## 1. 📱 딥링크 신구 호환 (5종)
- [ ] `/feed?tab=community&category=magazine` → 라운지 '전체' 진입 (매거진 섹션 상단 노출)
- [ ] `/feed?tab=following` → 발견 탭 진입 (회귀 기준: "발견 탭 진입" — 팔로잉 하위탭은 재편 전에도 미동작이었음)
- [ ] 홈 핫토픽 태그 칩 → `/hashtag/:tag` 해시태그 피드 진입 (구: 라운지 오폴백)
- [ ] `/feed?tab=lounge&category=qa` → 라운지 '궁금해요' 칩 선택 상태
- [ ] `/feed` (파라미터 없음) → 발견 탭
- [ ] MY 작성글 빈 상태 '커뮤니티 가기' → 라운지 / 홈 매거진 '더보기' → 라운지

## 2. 📱 뒤로가기·탭 규칙
- [ ] 피드 첫 페이지에서 뒤로가기 → 홈 (main_navigation PopScope 규칙)
- [ ] 하단 탭 '피드' 하이라이트 정상 (발견/라운지 어느 탭이든)

## 3. 📱 라운지
- [ ] 카테고리 칩 5종(전체/잡담/자랑/궁금해요/정보) 필터 동작
- [ ] 글 작성: 4종 선택 가능, 기본값 '잡담', 저장 후 현재 카테고리 새로고침
- [ ] 구 카테고리 글(quiz/careguide 등)은 '전체'에서만 노출 + 라벨 정상 표기
- [ ] 매거진 섹션: '전체'에서만 상단 노출, 다른 칩에서 미노출

## 4. 📱 발견
- [ ] 유저 포스트 4개당 운영 카드 1개 인터리브 (운영 콘텐츠 부족 시 있는 만큼만)
- [ ] 운영 카드 탭 → 글 상세(/post/:id)
- [ ] 좋아요 낙관적 업데이트 회귀 없음 (인터리브 상태에서 좋아요/취소)
- [ ] 무한스크롤: **21번째 카드 로드 확인** (기불능 상태 부활 검증 — 이번에 신규 배선, 기존엔 첫 20건 고정)
- [ ] 콜드스타트: 추천 결과 0건 계정에서 최신 전체 피드 폴백 표시
- [ ] 사진 그리드 토글: 그리드에는 운영 카드 미노출(사진 전용)

## 5. 📱 검색 스모크
- [ ] 피드 앱바 검색 → /search 진입, 해시태그·사용자 검색 정상 (카테고리 무관 확인)

## 6. 구간 7 — 새 글 운영자 알림 배포·검증 (⛔ pg_net 활성화 이후)

함수 코드는 커밋 완료(`supabase/functions/notify-admin-new-post/index.ts`).
Supabase Database Webhook은 pg_net 기반이므로, **웹훅 등록과 E2E 검증은
배포 직전 체크리스트의 "pg_cron/pg_net 활성화" 항목과 같은 타이밍에 수행**
(미활성 상태에서 등록하면 "검증 통과"가 거짓 신호가 됨 — 승인지시서).

- [ ] 🟦 ① pg_net 활성화 (pg_cron purge 배치 활성화와 동일 타이밍)
- [ ] 🟦 ② `supabase functions deploy notify-admin-new-post` — verify_jwt 유지(⛔ `--no-verify-jwt` 금지)
- [ ] 🟦 ③ `ADMIN_USER_IDS` 시크릿 설정 (콤마 구분 운영자 UUID)
- [ ] 🟦 ④ Dashboard → Database → Webhooks: posts INSERT →
      `/functions/v1/notify-admin-new-post`, HTTP Headers에
      `Authorization: Bearer <service_role>` 첨부
- [ ] 📱 ⑤ 검증 3종: 테스트 계정 글 작성 → 운영자 기기 푸시 + notifications 행 확인 /
      운영자 글 작성 → 미발송 / emotion 자동 글 → 미발송
- ⚠️ **SOP 명기(승인지시서 D1)**: '펫페이스 지기' 등 운영 계정 신규 생성 절차에
  "해당 UUID를 ADMIN_USER_IDS 시크릿에 추가" 단계를 포함할 것
- 참고: adminNewPost 푸시 탭 시 앱 라우팅은 기본 경로(알림 목록)로 동작
  (fcm_service switch에 전용 케이스 없음 — 필요 시 후속에서 /post/:id 직행 추가)

## 7. 이관·후속 (이번 범위 외 — 인계 메모)
1. HomeQuestCard 부활 시 /feed 라우팅 재검토
2. MY 커뮤니티 글 탭 스텁(my_posts_page) 미구현 부채
3. §4.4 pill·이모지 전역 제거 → AppTheme v2 구간
4. iOS 딥링크 표면 → mac 세션
5. app_settings 테이블 신설 → P1 (인터리브 간격 원격화)
6. FeedBloc 추천/폴백 상태 공유 긴장 → 팔로잉 칩 도입(P1) 시 재설계
7. **운영자 식별 체계 정비 — 출시 후**: users.is_admin 컬럼 신설 + 앱 isAdmin의
   `authorName=='관리자'` 문자열 비교 청산 (승인지시서 부채 등록)
