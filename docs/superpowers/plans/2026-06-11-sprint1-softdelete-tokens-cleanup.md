# Sprint 1 정비 (STEP 0~4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 펫페이스 출시 차단 요소 해소 — 재분석 버튼 숨김, 계정 30일 soft delete, 디자인 토큰 정의, 하드코딩 색 치환, 죽은 코드 삭제 (커밋 8개).

**Architecture:** Clean Architecture 유지. soft delete는 `users.deleted_at` + RLS 차단 + Edge Function(`request-account-deletion`/`purge-deleted-accounts`) + AuthBloc 신규 상태(`AuthAccountDeleted`)로 구성. 색 치환은 STEP 2에서 추가한 AppTheme 토큰 기준 "정확 일치만 치환, 애매하면 보고" 원칙.

**Tech Stack:** Flutter 3.41.6 / flutter_bloc + mocktail + bloc_test / Supabase (PostgreSQL RLS, Edge Functions Deno) / dartz Either.

---

## ⚠️ 절대 수정 금지 파일 (모든 Task 공통)

```
pjh/lib/features/home/**
pjh/lib/features/social/presentation/pages/home_page.dart
pjh/lib/features/emotion/presentation/pages/emotion_loading_page.dart
pjh/lib/features/emotion/presentation/pages/health_loading_page.dart
pjh/lib/features/emotion/presentation/widgets/ai_analysis_loading_widget.dart
pjh/lib/features/emotion/presentation/widgets/emotion_loading_widget.dart
```

- **이 plan은 위 파일을 하나도 수정하지 않는다.** (조사 결과 STEP 4의 `/ai-history` 중복 라우트 삭제도 `app_router.dart`만 수정 — 홈 위젯들이 쓰는 `/ai-history-page` 라우트는 유지하므로 홈 파일 무변경)
- 각 커밋 직전 `git status --short` 로 금지 경로 포함 여부 확인. 포함 시 즉시 중단·보고.

## 📋 Plan 단계에서 발견된 사항 (승인 시 확인 요청)

1. **`profiles` 테이블이 존재하지 않음.** 실제 사용자 테이블은 `public.users` (petspace_setup.sql:37). 지시서의 `profiles.deleted_at`은 **`users.deleted_at`** 으로 적용한다.
2. **기존 hard delete 경로 존재**: `delete_user_account()` RPC(petspace_setup.sql:927)가 auth.users+public.users 즉시 삭제. 앱은 이를 더 이상 호출하지 않게 변경하되, RPC 자체 삭제는 범위 외(보고만).
3. **Apple token revoke는 현 구조에서 구현 불가**: 앱이 Apple refresh token을 저장하지 않아 revoke API 호출 불가. iOS 출시 트랙(맥)에서 Apple 토큰 저장과 함께 처리 필요 → **이 plan에서 제외, 인계 항목**.
4. **재인증 방식 구체화**: Supabase는 RPC 호출에 재인증을 요구하지 않으므로, 탈퇴 다이얼로그에 **"탈퇴" 문구 입력 확인**으로 대체 (모든 로그인 provider 공통 동작).
5. **콘텐츠 차단 범위**: posts·comments는 RLS로 타인 조회 차단. **chat_messages는 유지**(대화 무결성) + 표시명 "탈퇴한 사용자" fallback은 *방침 문서화만* — 앱 측 author-null fallback 구현이 필요해 보이면 발견 시 보고(범위 확장 금지).
6. **STEP 3 색 치환**: 대상 파일의 색 다수가 AppTheme/신규 토큰과 **정확 일치하지 않음**(파스텔 타일 배경 9종, 경고 갈색 계열 등). 규칙 ②에 따라 정확 일치·명백한 케이스만 치환하고 나머지는 보고 목록으로 제출한다 (아래 Task 6·7의 매핑 표 참조).
7. **하네스 부재**: `.claude/agents/`에 21-code-reviewer·19-database-architect 하네스 없음(harness-100 모바일/스타트업 팀만 설치됨) → 코드 리뷰는 superpowers:requesting-code-review, DB 설계 검증은 qa-engineer 서브에이전트로 대체.

---

### Task 0: STEP 0 — 재분석 버튼 숨김 (커밋 1)

**Files:**
- Modify: `pjh/lib/features/emotion/presentation/widgets/result/next_action_card.dart:24-29`
- Modify: `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart:135-140, 251`

배경: 재분석 버튼은 BottomActionBar가 아니라 **NextActionCard**의 조건부 첫 항목("10분 뒤 다시 분석하기")이다. `onReanalyze`가 nullable이므로 null 가드를 추가하면 페이지에서 콜백을 빼는 것만으로 항목이 사라진다. 남은 항목 2개(건강 분석·기록하기)로 카드 레이아웃은 깨지지 않는다.

- [ ] **Step 1: next_action_card.dart — null 가드 추가**

```dart
  /// 재분석 노출 조건: 콜백 연결 + (부정 감정 60% 이상 또는 스트레스 70+)
  bool get _showReanalyze {
    if (onReanalyze == null) return false; // TODO(재분석): prefill 구현 후 콜백 연결 시 자동 복원
    final e = analysis.emotions;
    final negSum = e.anxiety + e.sadness + e.fear + e.discomfort;
    return negSum >= 0.6 || e.stressLevel >= 70;
  }
```

- [ ] **Step 2: emotion_result_page.dart — 핸들러·연결 제거**

135-140행의 `_onReanalyze` 메서드 전체를 삭제하고 아래 주석으로 대체:

```dart
  // TODO(재분석): 입력 페이지 prefill(이미지·petId 전달) 구현 후
  // NextActionCard에 onReanalyze 콜백을 다시 연결해 복원한다.
```

251행 `onReanalyze: _onReanalyze,` 줄 삭제 (NextActionCard 호출부에서 인자 제거).

- [ ] **Step 3: 검증**

```bash
cd pjh
flutter analyze        # 기대: No issues found (unused 경고 0)
flutter test           # 기대: 기존 51케이스 전체 통과
```

`rg "준비 중" pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart` → 기대: 0건

- [ ] **Step 4: 금지 파일 확인 후 커밋**

```bash
git status --short     # 변경 2파일만, 금지 경로 없음 확인
git add pjh/lib/features/emotion/presentation/widgets/result/next_action_card.dart pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart
git commit -F .git/COMMIT_MSG_TMP   # 내용: "Sprint1-STEP0: 재분석 버튼 숨김 및 '준비 중' SnackBar 제거"
```

(멀티라인/한글 커밋은 메시지 파일 `-F` 사용 — 프로젝트 규칙)

- [ ] **Step 5: STEP 0 보고 후 사용자 확인 대기** (변경 파일·analyze·test 결과 포함)

---

### Task 1: STEP 1-A — 계정 삭제 영향도 조사 보고 (커밋 없음, 대기)

조사 완료된 결과를 아래 형식으로 보고하고 **사용자 확인을 기다린다**:

- 기존 구현: UI(`my_settings_page.dart:234-250` 다이얼로그 — 현재 닫기만 하고 실제 동작 없음, `settings_bottom_sheet.dart:120-127` 동일), BLoC(`AuthDeleteAccountRequested` → `auth_bloc.dart:223-234` → `repository.deleteAccount()`), Repository(`auth_repository_impl.dart:656-682` — Storage 정리 + **hard delete RPC** `delete_user_account` 호출)
- 사용자 연관 테이블(전부 ON DELETE CASCADE): pets, posts(author_id), emotion_history, comments, follows, likes, notifications, user_devices, comment_likes, reports, user_blocks, health_records, saved_posts, bookmark_collections, chat_rooms(created_by), chat_participants, chat_messages(sender_id), pet_mbti_results(pet 경유)
- users RLS 현황: SELECT `USING (true)` (전체 공개), UPDATE/INSERT/DELETE 본인만
- 위 "Plan 단계 발견 사항" 1·2·3·5 항목 재안내

---

### Task 2: STEP 1-B — DB·백엔드 (커밋 2)

**Files:**
- Create: `supabase/migrations/G1_account_soft_delete.sql`
- Create: `supabase/functions/request-account-deletion/index.ts`
- Create: `supabase/functions/purge-deleted-accounts/index.ts`
- Modify: `supabase/petspace_setup.sql` (커밋용 동기화만 — 실행 금지)

> ⚠️ **migration은 작성만 한다. 절대 실행하지 않는다** (사용자가 대시보드에서 수동 실행).

- [ ] **Step 1: migration 작성** — `supabase/migrations/G1_account_soft_delete.sql`

```sql
-- ================================================================
-- G-1: 계정 30일 soft delete
-- 실행: Supabase Dashboard SQL Editor에서 수동 실행 (CI/CLI 자동 실행 금지)
-- 정책:
--   * 탈퇴 = users.deleted_at 기록. 30일 내 재로그인 시 복구 가능.
--   * deleted_at NOT NULL 계정: 본인 외 프로필 조회 차단, posts/comments 타인 조회 차단.
--   * chat_messages는 대화 무결성을 위해 유지 — 앱에서 작성자 미조회 시
--     "탈퇴한 사용자"로 표시 (앱 fallback, 별도 트랙).
--   * 30일 경과분은 pg_cron → Edge Function purge-deleted-accounts 가 영구 삭제.
-- ================================================================

-- 1) users.deleted_at 컬럼
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at
    ON users(deleted_at) WHERE deleted_at IS NOT NULL;

-- 2) RLS: 탈퇴 계정 프로필은 본인만 조회 (복구 안내용)
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON users;
CREATE POLICY "Authenticated users can view all profiles" ON users
    FOR SELECT TO authenticated
    USING (deleted_at IS NULL OR auth.uid() = id);

-- 3) RLS: 탈퇴 계정의 posts/comments 타인 조회 차단
--    (기존 정책명은 petspace_setup.sql PART 6 확인 후 동일 명칭으로 재생성)
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;
CREATE POLICY "Posts are viewable by everyone" ON posts
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = posts.author_id AND u.deleted_at IS NOT NULL
        )
    );

DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments
    FOR SELECT USING (
        deleted_at IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = comments.author_id AND u.deleted_at IS NOT NULL
        )
    );

-- 4) soft delete RPC (Edge Function 장애 시 폴백 겸 단일 경로)
CREATE OR REPLACE FUNCTION request_account_deletion()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NOW()
    WHERE id = auth.uid() AND deleted_at IS NULL;
END;
$$;

-- 5) 복구 RPC (SECURITY DEFINER — RLS 우회하여 본인 deleted_at 해제)
CREATE OR REPLACE FUNCTION restore_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET deleted_at = NULL
    WHERE id = auth.uid() AND deleted_at IS NOT NULL;
END;
$$;

-- 6) 기존 hard delete RPC 제거 (승인 조건 — 2026-06-12)
--    SECURITY DEFINER 즉시 삭제 함수가 남으면 30일 soft delete 정책 우회 경로가 공존.
--    앱 호출처는 1-C에서 제거됨, 그 외 호출처 0건 확인 후 DROP.
--    (petspace_setup.sql:927-937 확인 결과: 인자 없음·auth.uid() 기준 → 시그니처 일치)
DROP FUNCTION IF EXISTS delete_user_account();

-- 7) pg_cron 일배치 등록 (대시보드에서 수동 실행 — URL·시크릿 치환 필요)
-- 매일 03:00 KST(18:00 UTC) purge Edge Function 호출:
-- SELECT cron.schedule(
--   'purge-deleted-accounts-daily', '0 18 * * *',
--   $$ SELECT net.http_post(
--        url := 'https://<PROJECT_REF>.supabase.co/functions/v1/purge-deleted-accounts',
--        headers := jsonb_build_object('x-purge-secret', '<PURGE_SHARED_SECRET>')
--      ) $$
-- );
```

- [ ] **Step 2: 기존 정책·컬럼 검증 (승인 조건 1)**
  1. `rg "viewable by everyone" supabase/petspace_setup.sql` 로 posts/comments SELECT 정책의 **실제 명칭과 원래 USING 조건 전문**을 확인.
  2. `rg "deleted_at" supabase/petspace_setup.sql` 로 posts·comments 테이블 **자체 deleted_at 컬럼 존재 여부** 확인 (참고: `soft_delete_post`/`soft_delete_comment` 함수가 각각 `posts.deleted_at`·`comments.deleted_at`을 UPDATE하므로 존재 예상 — 반드시 CREATE TABLE 정의에서 재확인).
  3. 신규 정책은 **기존 정책의 원래 조건을 그대로 보존한 뒤 작성자 deleted 차단 조건을 AND로 추가**하는 방식으로 작성. 자체 deleted_at 컬럼이 없는 테이블이면 해당 `deleted_at IS NULL` 조건을 migration에서 제거.
  4. 확인 결과에 따라 Step 1의 migration SQL을 수정하고, 수정 내용을 STEP 1-B 보고에 포함.

- [ ] **Step 3: Edge Function 작성** — `supabase/functions/request-account-deletion/index.ts`

```typescript
// supabase/functions/request-account-deletion/index.ts
// 계정 soft delete: users.deleted_at 기록 + 전 기기 세션 무효화
// 호출: POST /functions/v1/request-account-deletion (사용자 JWT 필요)
// 참고: Apple token revoke는 앱이 Apple 토큰을 저장하지 않아 미구현 — iOS 트랙 인계

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!jwt) {
      return new Response(JSON.stringify({ error: "인증 토큰이 없습니다." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "유효하지 않은 사용자입니다." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1) soft delete 기록 (이미 탈퇴 상태면 no-op)
    const { error: updateError } = await admin
      .from("users")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", user.id)
      .is("deleted_at", null);
    if (updateError) throw updateError;

    // 2) 전 기기 세션 무효화 (복구는 재로그인으로만 가능)
    await admin.auth.admin.signOut(jwt, "global");

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
```

- [ ] **Step 4: purge Edge Function 작성** — `supabase/functions/purge-deleted-accounts/index.ts`

```typescript
// supabase/functions/purge-deleted-accounts/index.ts
// 30일 경과 탈퇴 계정 영구 삭제 배치 (pg_cron이 일 1회 호출)
// 가드: x-purge-secret 헤더 == PURGE_SHARED_SECRET (collect-news 공유 시크릿 패턴)
// 처리: Storage 정리 → auth.users 삭제 → public.users 삭제(CASCADE로 연관 데이터 정리)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GRACE_DAYS = 30;
const STORAGE_FOLDERS = ["profiles", "pets", "posts", "emotion_analysis", "chat"];

serve(async (req) => {
  if (req.headers.get("x-purge-secret") !== Deno.env.get("PURGE_SHARED_SECRET")) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const cutoff = new Date(Date.now() - GRACE_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data: targets, error } = await admin
    .from("users")
    .select("id")
    .lt("deleted_at", cutoff);
  if (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }

  const results: { id: string; ok: boolean; error?: string }[] = [];
  for (const { id } of targets ?? []) {
    try {
      // 1) Storage 정리 (폴더별 재귀 삭제, 실패해도 계속)
      const storage = admin.storage.from("images");
      for (const folder of STORAGE_FOLDERS) {
        await removeFolder(storage, `${folder}/${id}`).catch(() => {});
      }
      // 2) auth.users 삭제
      await admin.auth.admin.deleteUser(id);
      // 3) public.users 삭제 (FK CASCADE로 연관 데이터 정리)
      await admin.from("users").delete().eq("id", id);
      results.push({ id, ok: true });
    } catch (e) {
      results.push({ id, ok: false, error: String(e) });
    }
  }

  return new Response(JSON.stringify({ purged: results }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

// 하위 폴더 포함 재귀 삭제 (Supabase Storage list는 1depth 반환)
async function removeFolder(
  storage: ReturnType<ReturnType<typeof createClient>["storage"]["from"]>,
  path: string
): Promise<void> {
  const { data: items } = await storage.list(path);
  if (!items || items.length === 0) return;

  const files = items.filter((i) => i.id !== null).map((i) => `${path}/${i.name}`);
  if (files.length > 0) await storage.remove(files);

  const folders = items.filter((i) => i.id === null);
  for (const f of folders) {
    await removeFolder(storage, `${path}/${f.name}`);
  }
}
```

- [ ] **Step 5: petspace_setup.sql 커밋용 동기화** (실행 아님)
  - `CREATE TABLE users` (37-52행)에 `deleted_at TIMESTAMP WITH TIME ZONE` 컬럼 추가
  - users SELECT 정책(1073-1075행)을 migration과 동일 조건으로 갱신
  - posts/comments SELECT 정책에 작성자 deleted 차단 조건 반영
  - PART 4 함수 섹션에 `request_account_deletion()`·`restore_my_account()` 추가 (위 migration과 동일 본문)
  - **`delete_user_account()` 함수 정의(927-937행) 삭제** (승인 조건 — DROP과 동기화). 삭제 전 `rg "delete_user_account" pjh supabase` 로 호출처가 auth_repository_impl.dart(1-C에서 제거 예정) 외 0건인지 재확인, 발견 시 보류·보고

- [ ] **Step 6: 검증·커밋**

```bash
# SQL 문법 빠른 검토: 정책명·테이블명이 setup과 일치하는지 diff 육안 확인
git status --short    # supabase/ 4파일만
git add supabase/migrations/G1_account_soft_delete.sql supabase/functions/request-account-deletion supabase/functions/purge-deleted-accounts supabase/petspace_setup.sql
git commit -F <메시지파일>   # "Sprint1-STEP1B: 계정 30일 soft delete 마이그레이션·Edge Functions 작성"
```

배포 안내(보고에 포함, 실행은 사용자): `supabase functions deploy request-account-deletion`, `supabase functions deploy purge-deleted-accounts --no-verify-jwt` + 대시보드에서 `PURGE_SHARED_SECRET` 설정 + migration 수동 실행 + pg_cron 등록.

---

### Task 3: STEP 1-C — 앱 (커밋 3) · TDD

**Files:**
- Create: `pjh/lib/features/auth/domain/services/account_deletion_policy.dart`
- Create: `pjh/test/features/auth/domain/services/account_deletion_policy_test.dart`
- Modify: `pjh/lib/features/auth/domain/entities/user.dart`
- Modify: `pjh/lib/features/auth/data/models/user_model.dart`
- Modify: `pjh/lib/features/auth/domain/repositories/auth_repository.dart`
- Modify: `pjh/lib/features/auth/data/repositories/auth_repository_impl.dart:655-728`
- Modify: `pjh/lib/features/auth/presentation/bloc/auth_bloc.dart`, `auth_event.dart`, `auth_state.dart`
- Modify: `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart`
- Modify: `pjh/lib/features/my/presentation/pages/my_settings_page.dart:234-250`
- Modify: `pjh/lib/features/my/presentation/widgets/settings_bottom_sheet.dart` (`_confirmDelete`)
- Modify: `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- Modify: `pjh/lib/core/navigation/auth_guard.dart:17-31`
- Modify: `CLAUDE.md` (테스트 기재 "5개 파일, 51케이스" → 실제 250케이스로 1줄 정정 — 승인 조건)

> **테스트 베이스라인 (2026-06-12 A안 승인):** 사전 존재 실패 18건 중 auth_bloc_test 실패는 **이 Task에서 테스트 코드 수정으로만 수리** (신규 `_stateForUser` 스펙 기준으로 기대 시퀀스 갱신, 통과 목적의 프로덕션 코드 변경 금지, 프로덕션 버그로 판단되면 수정 말고 보고). health_usecases_test·feed_bloc_test 실패는 베이스라인(232/250)으로 동결 — Sprint 5 인계. 이후 모든 STEP 검증 기준: **신규 실패 0 + auth_bloc_test 전체 그린**.

#### 3-1. 정책 헬퍼 (TDD)

- [ ] **Step 1: 실패하는 테스트 작성** — `pjh/test/features/auth/domain/services/account_deletion_policy_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/auth/domain/services/account_deletion_policy.dart';

void main() {
  group('AccountDeletionPolicy', () {
    final deletedAt = DateTime(2026, 6, 1, 12, 0);

    test('삭제 직후 잔여일은 30일', () {
      expect(AccountDeletionPolicy.remainingDays(deletedAt, deletedAt), 30);
    });

    test('29.5일 경과 시 잔여일은 1일 (올림)', () {
      final now = deletedAt.add(const Duration(days: 29, hours: 12));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 1);
    });

    test('정확히 30일 경과 시 0일', () {
      final now = deletedAt.add(const Duration(days: 30));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 0);
    });

    test('30일 초과 경과 시 음수 아닌 0', () {
      final now = deletedAt.add(const Duration(days: 31));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 0);
    });

    test('purgeAt은 deletedAt + 30일', () {
      expect(AccountDeletionPolicy.purgeAt(deletedAt), DateTime(2026, 7, 1, 12, 0));
    });
  });
}
```

- [ ] **Step 2: 실패 확인** — `cd pjh; flutter test test/features/auth/domain/services/account_deletion_policy_test.dart` → 기대: 컴파일 에러(파일 없음)로 FAIL

- [ ] **Step 3: 구현** — `pjh/lib/features/auth/domain/services/account_deletion_policy.dart`

```dart
/// 계정 soft delete 30일 유예 정책 (서버 purge 배치와 동일 기준).
class AccountDeletionPolicy {
  const AccountDeletionPolicy._();

  static const int gracePeriodDays = 30;

  static DateTime purgeAt(DateTime deletedAt) =>
      deletedAt.add(const Duration(days: gracePeriodDays));

  /// 영구 삭제까지 남은 일수 (올림, 최소 0).
  static int remainingDays(DateTime deletedAt, DateTime now) {
    final remaining = purgeAt(deletedAt).difference(now);
    if (remaining.isNegative || remaining == Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }
}
```

- [ ] **Step 4: 통과 확인** — 같은 명령 → 기대: 5케이스 PASS

#### 3-2. 엔티티·모델

- [ ] **Step 5: User 엔티티에 deletedAt 추가** — `user.dart`

생성자에 `this.deletedAt,` 추가, 필드·getter 추가:

```dart
  final DateTime? deletedAt; // soft delete 시각 (null이면 정상 계정)

  bool get isDeleted => deletedAt != null;
```

`copyWith`에 `DateTime? deletedAt` 파라미터 + `deletedAt: deletedAt ?? this.deletedAt,` 추가, `props` 리스트에 `deletedAt` 추가.

- [ ] **Step 6: UserModel 파싱 추가** — `user_model.dart`

생성자에 `super.deletedAt,` 추가. `fromJson`/`fromMap`의 `emailConfirmedAt` 파싱 바로 아래에 동일 패턴으로:

```dart
      deletedAt: data['deleted_at'] != null
          ? DateTime.parse(data['deleted_at'])
          : null,
```

(`fromMap`은 `map['deleted_at']`) — `fromEntity`에 `deletedAt: user.deletedAt,`, `toMap`에 `'deleted_at': deletedAt?.toIso8601String(),`, `copyWith`에도 동일 추가.

#### 3-3. Repository

- [ ] **Step 7: 인터페이스에 restoreAccount 추가** — `auth_repository.dart:16` 아래

```dart
  Future<Either<Failure, void>> restoreAccount();
```

- [ ] **Step 8: 구현 교체** — `auth_repository_impl.dart`

`deleteAccount()`(656-682행)를 soft delete로 교체:

```dart
  @override
  Future<Either<Failure, void>> deleteAccount() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user != null) {
        // 30일 유예 soft delete — Storage 정리·영구 삭제는
        // purge-deleted-accounts 배치가 30일 후 수행
        await supabaseClient.functions.invoke('request-account-deletion');
        await supabaseClient.auth.signOut();

        // 로컬 저장소 초기화 (가이드 표시 기록 등)
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      return Left(
          GeneralFailure(message: '계정 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> restoreAccount() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      await supabaseClient.rpc('restore_my_account');
      return const Right(null);
    } catch (e) {
      return Left(
          GeneralFailure(message: '계정 복구 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }
```

이제 미사용이 된 `_cleanupUserStorageFiles`·`_deleteStorageFolder`(686-728행) 삭제 (purge Edge Function으로 책임 이전). 삭제 후 `rg "_cleanupUserStorageFiles|_deleteStorageFolder" pjh/lib` → 0건 확인.

#### 3-4. AuthBloc (TDD)

- [ ] **Step 9: 실패하는 bloc 테스트 작성** — `auth_bloc_test.dart`에 그룹 추가 (기존 fixture 패턴 재사용, `tUser.copyWith(deletedAt: ...)` 형태로 탈퇴 유저 생성)

```dart
  group('계정 soft delete', () {
    blocTest<AuthBloc, AuthState>(
      'deletedAt 있는 유저가 AuthUserChanged로 들어오면 AuthAccountDeleted',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(AuthUserChanged(
          tUser.copyWith(deletedAt: DateTime(2026, 6, 1)))),
      expect: () => [isA<AuthAccountDeleted>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthDeleteAccountRequested 성공 → [Loading, Unauthenticated]',
      build: () {
        when(() => mockAuthRepository.deleteAccount())
            .thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AuthDeleteAccountRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthRestoreAccountRequested 성공 → [Loading, Authenticated]',
      build: () {
        when(() => mockAuthRepository.restoreAccount())
            .thenAnswer((_) async => const Right(null));
        when(() => mockAuthRepository.getCurrentUser())
            .thenAnswer((_) async => Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AuthRestoreAccountRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthRestoreAccountRequested 실패 → [Loading, AuthError]',
      build: () {
        when(() => mockAuthRepository.restoreAccount()).thenAnswer(
            (_) async => const Left(GeneralFailure(message: '복구 실패')));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AuthRestoreAccountRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });
```

(테스트 파일의 실제 mock 변수명·bloc 생성 헬퍼명은 기존 파일 컨벤션에 맞춰 조정. `tUser` fixture가 없으면 기존 테스트의 User 생성부를 재사용해 정의.)

- [ ] **Step 10: 실패 확인** — `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart` → 기대: `AuthAccountDeleted`/`AuthRestoreAccountRequested` 미정의 컴파일 에러

- [ ] **Step 11: 상태·이벤트·핸들러 구현**

`auth_state.dart` 말미:

```dart
class AuthAccountDeleted extends AuthState {
  final User user;

  const AuthAccountDeleted(this.user);

  @override
  List<Object?> get props => [user];
}
```

`auth_event.dart` 말미:

```dart
class AuthRestoreAccountRequested extends AuthEvent {}
```

`auth_bloc.dart`:

```dart
    on<AuthRestoreAccountRequested>(_onRestoreAccountRequested); // 생성자 등록부에 추가

  /// 유저 상태 → AuthState 매핑 단일 지점 (탈퇴 > 이메일 미인증 > 정상 순)
  AuthState _stateForUser(User user) {
    if (user.isDeleted) return AuthAccountDeleted(user);
    if (!user.isEmailConfirmed) return AuthEmailVerificationRequired(user);
    return AuthAuthenticated(user);
  }

  void _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(_stateForUser(event.user!));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRestoreAccountRequested(
    AuthRestoreAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.restoreAccount();
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (_) async {
        final refreshed = await _authRepository.getCurrentUser();
        refreshed.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => user != null
              ? emit(AuthAuthenticated(user))
              : emit(AuthUnauthenticated()),
        );
      },
    );
  }
```

4개 소셜/이메일 로그인 핸들러의 성공 분기를 `emit(AuthAuthenticated(user))` → `emit(_stateForUser(user))`로 교체하고, 탈퇴 계정엔 푸시 토큰을 등록하지 않도록 가드 (4곳 동일 패턴, google 예시):

```dart
      (user) {
        if (!user.isDeleted) {
          AnalyticsService.instance.logLogin(method: 'google');
          NotificationService().registerToken(user.id);
        }
        emit(_stateForUser(user));
      },
```

`_onDeleteAccountRequested`(223행)에 푸시 토큰 비활성화 추가 (signOut 핸들러 200-201행과 동일 패턴):

```dart
    emit(AuthLoading());

    // 탈퇴 전 토큰 비활성화 (실패해도 탈퇴 계속)
    await NotificationService().deactivateToken();

    final result = await _authRepository.deleteAccount();
```

- [ ] **Step 12: 통과 확인** — `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart` → 기대: 신규 4케이스 포함 전체 PASS

#### 3-5. UI 연결

- [ ] **Step 13: 탈퇴 다이얼로그 교체** — `my_settings_page.dart:234-250`의 `_confirmDelete`를 아래로 교체 (`settings_bottom_sheet.dart`의 `_confirmDelete`도 동일 본문 적용, 단 BottomSheet은 다이얼로그 열기 전 `Navigator.pop(context)`로 시트를 먼저 닫는 기존 패턴 유지):

```dart
  void _confirmDelete(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('회원탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '탈퇴 후 30일이 지나면 모든 데이터가 영구 삭제됩니다.\n'
                '그 전까지는 다시 로그인하면 계정을 복구할 수 있어요.',
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: "계속하려면 '탈퇴'를 입력하세요",
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: controller.text.trim() == '탈퇴'
                  ? () {
                      Navigator.pop(ctx);
                      authBloc.add(AuthDeleteAccountRequested());
                    }
                  : null,
              child:
                  const Text('탈퇴', style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 14: 로그인 페이지 복구 다이얼로그** — `onboarding_login_page.dart`

기존 AuthBloc listener(BlocListener/BlocConsumer — 파일 열어 실제 구조 확인)에 분기 추가:

```dart
        if (state is AuthAccountDeleted) {
          _showRestoreDialog(context, state.user);
        }
```

페이지 `initState`(StatefulWidget인 경우)에 이미 탈퇴 상태로 진입한 케이스 처리:

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthBloc>().state;
      if (state is AuthAccountDeleted && mounted) {
        _showRestoreDialog(context, state.user);
      }
    });
```

다이얼로그 메서드 (import: `account_deletion_policy.dart`, auth `User` 엔티티):

```dart
  void _showRestoreDialog(BuildContext context, User user) {
    final days =
        AccountDeletionPolicy.remainingDays(user.deletedAt!, DateTime.now());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 복구'),
        content: Text(
          '탈퇴 처리된 계정입니다.\n'
          '$days일 후 모든 데이터가 영구 삭제될 예정이에요.\n'
          '계정을 복구할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthRestoreAccountRequested());
            },
            child: const Text('복구하기'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 15: AuthGuard 분기** — `auth_guard.dart:19-21`의 listener에 추가 (탈퇴 상태로 앱 내부 진입 시 로그인으로 회수):

```dart
        if (state is AuthUnauthenticated || state is AuthAccountDeleted) {
          context.go('/login');
        } else if (state is AuthAuthenticated) {
```

- [ ] **Step 16: 전체 검증·커밋**

```bash
cd pjh
flutter analyze    # 기대: No issues found
flutter test       # 기대: 기존 + 신규(policy 5, bloc 4) 전체 PASS
```

`git status --short` 금지 경로 확인 → 커밋 `"Sprint1-STEP1C: 계정 soft delete 앱 연결(복구 다이얼로그·AuthBloc 상태 추가)"`

- [ ] **Step 17: superpowers:requesting-code-review로 커밋 2·3 교차 리뷰** (21-code-reviewer 하네스 부재 대체) → 결과 보고

---

### Task 4: STEP 1-D — 검증 문서 (커밋 4)

**Files:**
- Create: `docs/qa/account_soft_delete_e2e.md`

- [ ] **Step 1: E2E 시나리오 문서 작성** — 아래 내용으로 작성 (migration 수동 실행 후 사용자가 실기기로 수행):

```markdown
# 계정 soft delete E2E 검증 시나리오

## 사전 조건
- [ ] G1_account_soft_delete.sql 대시보드 실행 완료
- [ ] request-account-deletion / purge-deleted-accounts Edge Function 배포 완료
- [ ] PURGE_SHARED_SECRET 설정, pg_cron 등록

## 시나리오 1: 탈퇴 → 재로그인 복구
1. 계정 A로 로그인 → 설정 → 회원탈퇴 → "탈퇴" 입력 → 탈퇴
   - 기대: 로그아웃되어 로그인 화면 이동
   - SQL 확인: SELECT deleted_at FROM users WHERE email='<A>'; → NOT NULL
2. 같은 계정으로 재로그인
   - 기대: "계정 복구" 다이얼로그 (잔여 30일 표시)
3. [복구하기]
   - 기대: 홈 진입, SQL 확인 deleted_at IS NULL

## 시나리오 2: 탈퇴 → 타인 시점 콘텐츠 비노출
1. 계정 A가 게시물·댓글 작성 후 탈퇴
2. 계정 B로 로그인 → 피드/검색/게시물 상세 확인
   - 기대: A의 프로필·게시물·댓글 미노출
   - 기대: A와의 기존 채팅방 메시지는 유지 (작성자명 누락 시 표시 확인 — 이슈 시 보고)

## 시나리오 3: 탈퇴 직후 세션 무효화
1. 기기 2대에 계정 A 로그인 → 기기1에서 탈퇴
   - 기대: 기기2도 다음 API 호출/재시작 시 로그인 화면으로 이동

## 시나리오 4: 30일 경과 영구 삭제 (스테이징)
1. SQL로 deleted_at을 31일 전으로 조작:
   UPDATE users SET deleted_at = NOW() - INTERVAL '31 days' WHERE email='<테스트계정>';
2. purge 함수 수동 호출:
   curl -X POST https://<REF>.supabase.co/functions/v1/purge-deleted-accounts -H "x-purge-secret: <SECRET>"
   - 기대: auth.users·public.users·연관 데이터·Storage 폴더 삭제
   - 기대: 탈퇴자의 chat_messages도 FK CASCADE로 함께 영구 삭제됨
     — **의도된 동작** (30일 유예 기간에만 대화 유지, purge 후에는 미보존)
```

- [ ] **Step 2: 최종 검증·커밋**

```bash
cd pjh; flutter analyze; flutter test   # 기대: 전체 PASS 유지
git add docs/qa/account_soft_delete_e2e.md
git commit -F <메시지파일>   # "Sprint1-STEP1D: soft delete E2E 검증 시나리오 문서"
```

- [ ] **Step 3: STEP 1 종합 보고 후 사용자 확인 대기** (변경 파일, analyze/test 결과, 수동 배포 절차 안내 포함)

---

### Task 5: STEP 2 — AppTheme 시맨틱 토큰 (커밋 5)

**Files:**
- Modify: `pjh/lib/shared/themes/app_theme.dart` (104-108행 "시맨틱 컬러" 블록 아래)

참고: 기존에 `successColor/errorColor/warningColor/infoColor`가 이미 있으나, 지시서가 확정한 토큰 블록을 **그대로** 추가한다(이름 충돌 없음: `success` vs `successColor`). 기존 상수 통폐합은 범위 외.

- [ ] **Step 1: 토큰 블록 추가** — `infoColor` 선언(108행) 바로 아래에 지시서 코드 그대로 삽입:

```dart
  // === Semantic Tokens ===
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger  = Color(0xFFE53935);
  static const Color info    = accentColor;

  static const Color featureEmotion = Color(0xFFFF6F61);
  static const Color featureHealth  = Color(0xFF1E3A5F);
  static const Color featurePlay    = Color(0xFF7E57C2);
  static const Color featureFortune = Color(0xFFFFB300);
  static const Color featureQuiz    = Color(0xFF0077B6);
  static const Color featureWalk    = Color(0xFF26A69A);

  static const Color surfaceWarm = Color(0xFFFFF8E8);
  static const Color surfaceCool = Color(0xFFF8F9FA);
```

- [ ] **Step 2: 파스텔 타일 토큰 9종 추가 (승인 조건 2 — 파스텔 팔레트 승격 확정)** — 위 블록 바로 아래에 삽입:

```dart
  // 파스텔 타일/뱃지 배경 팔레트 (settings·my 타일 색 승격 — 2026-06-12 확정)
  static const Color tilePastelBlue     = Color(0xFFE6F1FB);
  static const Color tilePastelGreen    = Color(0xFFEAF3DE);
  static const Color tilePastelPeach    = Color(0xFFFAECE7);
  static const Color tilePastelSand     = Color(0xFFF1EFE8);
  static const Color tilePastelPink     = Color(0xFFFBEAF0);
  static const Color tilePastelRose     = Color(0xFFFCEBEB);
  static const Color tilePastelMint     = Color(0xFFE1F5EE);
  static const Color tilePastelLavender = Color(0xFFEEEDFE);
  static const Color tilePastelPurple   = Color(0xFFE9E3F5);
```

- [ ] **Step 3: 검증·커밋**

```bash
cd pjh; flutter analyze; flutter test   # 기대: PASS
git add pjh/lib/shared/themes/app_theme.dart
git commit -F <메시지파일>   # "Sprint1-STEP2: AppTheme 시맨틱·feature 토큰 추가"
```

---

### Task 6: STEP 3 커밋 6 — my·profile 계열 색 치환

**Files:**
- Modify: `pjh/lib/features/my/presentation/widgets/settings_bottom_sheet.dart`
- Modify: `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- Modify: `pjh/lib/features/my/presentation/widgets/user_badges_section.dart`
- Modify: `pjh/lib/features/my/presentation/pages/my_page.dart:159`

**치환 규칙**: ① 토큰과 **값 정확 일치**만 치환 (파스텔 9종 포함 — 승인 조건 2) ② 값 불일치 항목은 치환하지 말고 목록 보고 ③ 홈·로딩 위젯 불가침 ④ **EmotionResultTokens 수정 금지**.

- [ ] **Step 1: 정확 일치 치환 (2건)**

| 파일:라인 | 현재 | 치환 |
|---|---|---|
| settings_bottom_sheet.dart:42 | `Color(0xFFE0E0E0)` | `AppTheme.dividerColor` |
| my_page.dart:159 | `Color(0xFFBDBDBD)` | `AppTheme.lightTextColor` |

(각 파일에 `app_theme.dart` import 이미 존재 — 없으면 추가)

- [ ] **Step 2: 파스텔 타일 토큰 치환 (26곳 — 승인 조건 2)**

값→토큰 매핑 (전 파일 공통):

| 값 | 토큰 |
|---|---|
| 0xFFE6F1FB | `AppTheme.tilePastelBlue` |
| 0xFFEAF3DE | `AppTheme.tilePastelGreen` |
| 0xFFFAECE7 | `AppTheme.tilePastelPeach` |
| 0xFFF1EFE8 | `AppTheme.tilePastelSand` |
| 0xFFFBEAF0 | `AppTheme.tilePastelPink` |
| 0xFFFCEBEB | `AppTheme.tilePastelRose` |
| 0xFFE1F5EE | `AppTheme.tilePastelMint` |
| 0xFFEEEDFE | `AppTheme.tilePastelLavender` |
| 0xFFE9E3F5 | `AppTheme.tilePastelPurple` |

적용 위치:
- settings_bottom_sheet.dart (9곳): 58 Blue · 64 Green · 70 Peach · 80 Sand · 86 Pink · 92 Sand · 98 Sand · 115 Rose · 123 Rose
- my_settings_page.dart (9곳): 43 Blue · 50 Green · 57 Peach · 68 Sand · 75 Pink · 82 Sand · 89 Sand · 104 Rose · 113 Rose
- user_badges_section.dart (8곳): 40 Green · 47 Peach · 54 Blue · 61 Pink · 68 Mint · 75 Lavender · 82 Purple · 149 Sand

치환 후 확인: `rg -n "0xFFE6F1FB|0xFFEAF3DE|0xFFFAECE7|0xFFF1EFE8|0xFFFBEAF0|0xFFFCEBEB|0xFFE1F5EE|0xFFEEEDFE|0xFFE9E3F5" pjh/lib/features/my` → 0건

- [ ] **Step 3: 보고 목록 작성 (치환 보류 — 값 불일치, 승인 조건 2에 따라 보류 유지)**

아래를 STEP 3 보고에 그대로 포함:
- 구분선 근사색 F0F0F0(4곳)·EEEEEE(1곳)·CCCCCC(1곳): dividerColor(E0E0E0)와 값 상이(시각 변화) → 보류
- 회색 텍스트 888888·666666 (user_badges_section): 근사 토큰 없음
- notification_settings_page 경고 배너 6곳 (FFF4E5·FFB266·D97706·7A4500): `warning`(FF9800)과 톤 상이한 디자인 의도색 → 보류

- [ ] **Step 4: 검증·커밋**

```bash
cd pjh; flutter analyze; flutter test
git add pjh/lib/features/my/presentation/widgets/settings_bottom_sheet.dart pjh/lib/features/my/presentation/pages/my_settings_page.dart pjh/lib/features/my/presentation/widgets/user_badges_section.dart pjh/lib/features/my/presentation/pages/my_page.dart
git commit -F <메시지파일>   # "Sprint1-STEP3a: my 계열 하드코딩 색 토큰 치환(파스텔 팔레트 포함)"
```

- [ ] **Step 5: superpowers:requesting-code-review 리뷰 1회** → 결과 첨부

---

### Task 7: STEP 3 커밋 7 — emotion·기타 색 치환 (홈·로딩 제외)

**Files:**
- Modify: `pjh/lib/features/emotion/presentation/pages/ai_history_page.dart:407,1038`
- Modify: `pjh/lib/features/mbti/presentation/theme/mbti_theme.dart:23,26`
- Modify: `pjh/lib/features/social/presentation/pages/location_picker_page.dart:567`
- Modify: `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart:69,314,433`

- [ ] **Step 1: 치환 (정확 일치)**

| 파일:라인 | 현재 | 치환 | 근거 |
|---|---|---|---|
| ai_history_page.dart:407,1038 | `Color(0xFF854F0B)` | `EmotionResultTokens.amberDark` | 값 동일, emotion feature 내부 |
| mbti_theme.dart:23 | `Color(0xFF6B3FA0)` | `AppTheme.fearColor` | 값 동일 (딥 퍼플) |
| mbti_theme.dart:26 | `Color(0xFF2E7D6B)` | `AppTheme.calmColor` | 값 동일 (틸 그린) |
| location_picker_page.dart:567 | `Color(0xFFF5F5F5)` | `AppTheme.subtleBackground` | 값 동일 |

(필요 import 추가: ai_history_page → `../theme/emotion_result_tokens.dart` 기존 import 확인, mbti_theme → `../../../../shared/themes/app_theme.dart`)

- [ ] **Step 2: 카카오 브랜드색 단일화** — kakao_consent_page.dart 3곳의 `Color(0xFFFEE500)`을 클래스 상단 단일 상수로:

```dart
  /// 카카오 브랜드 공식 컬러 — 디자인 토큰 아님 (브랜드 가이드 고정값)
  static const Color _kakaoYellow = Color(0xFFFEE500);
```

3곳 사용부를 `_kakaoYellow`로 교체. (정의 1곳만 남으므로 잔여 grep 1건은 허용 — 보고에 명시)

- [ ] **Step 3: 보고 목록 (치환 보류)**
- chat_bubble.dart:87,115 `FF6B00` (미읽음 카운트): warning(FF9800)과 색감 상이한 의도색
- emotion_chart.dart 186-190 파스텔 3종 (E8F5E9·FCE4EC·F3E5F5): 감정 그룹 배경, 대응 토큰 없음
- emotion_disclaimer_banner.dart 5곳 (FFF8E1·FFD54F·B7791F·7A4500): EmotionResultTokens.amber 계열과 값 상이
- ai_history_page EF9F27(3곳)·FFF5F4·F9F9F9: 부위별 건강 신호색, 일치 토큰 없음
- mbti/fortune 그림자 0x0A000000·0x0F000000 (5곳): 그림자 토큰 미정의
- location_picker EEEEEE(2곳): 근사 토큰 없음
- next_action_card F1EFE8(1곳): `tilePastelSand`와 값 정확 일치하나 승인 범위(3파일) 외 → 보류, 보고 시 치환 여부 문의

- [ ] **Step 4: 잔여 하드코딩 grep 수치 보고**

```bash
rg -c "Color\(0x" pjh/lib --glob "!**/features/home/**" --glob "!**/*loading*" --glob "!**/*.legacy"
```

파일별 카운트 + 총합 보고 (토큰 정의 파일 app_theme.dart·emotion_result_tokens.dart·mbti_theme.dart는 '정의처'로 별도 표기).

- [ ] **Step 5: 검증·커밋**

```bash
cd pjh; flutter analyze; flutter test
git add <변경 4파일>
git commit -F <메시지파일>   # "Sprint1-STEP3b: emotion·기타 하드코딩 색 토큰 치환(홈·로딩 제외)"
```

- [ ] **Step 6: superpowers:requesting-code-review 리뷰 1회 → STEP 3 종합 보고 후 사용자 확인 대기**

---

### Task 8: STEP 4 — 죽은 코드 삭제 (커밋 8)

**Files:**
- Delete: `pjh/lib/features/emotion/presentation/pages/emotion_calendar_page.dart`
- Delete: `pjh/lib/features/emotion/presentation/pages/emotion_history_page.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/pages/health_result_page.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/widgets/result/emotion_result_bottom.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/widgets/result/emotion_result_cards_a.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/widgets/result/emotion_result_cards_b.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/widgets/result/emotion_result_cards_c.dart.legacy`
- Delete: `pjh/lib/features/emotion/presentation/widgets/result/emotion_result_helpers.dart.legacy`
- Modify: `pjh/lib/core/navigation/app_router.dart:44, 620-624, 637-645`

조사 확정 사항: `.legacy` 8개는 참조 0건. `emotion_calendar_page`는 app_router의 import(44행)+라우트(620-624행)만 참조하며 어떤 화면도 `/emotion/calendar`로 이동하지 않음. `/ai-history`(637-645행)는 정의만 있고 호출 0건 — **`/ai-history-page`는 14곳에서 사용 중이므로 유지** (홈 위젯 호출처 무변경), `/emotion/history → /ai-history-page` redirect도 유지(푸시 딥링크 호환).

- [ ] **Step 1: 삭제 직전 참조 재확인 (참조 1곳이라도 발견 시 해당 항목 보류·보고)**

```bash
rg -l "emotion_calendar_page|EmotionCalendarPage" pjh/lib pjh/test pjh/integration_test
# 기대: app_router.dart 1건만
rg -l "\.legacy" pjh/lib pjh/test                 # 기대: 0건 (파일명 자체 제외)
rg -n "'/ai-history'" pjh/lib pjh/test            # 기대: app_router.dart 정의부 1건만
```

- [ ] **Step 2: 파일 9개 삭제 + app_router.dart 수정**
  - 44행 `emotion_calendar_page.dart` import 삭제
  - 620-624행 `GoRoute(path: 'calendar', name: 'emotion-calendar', ...)` 블록 삭제
  - `/ai-history` GoRoute 블록(name: 'ai-history') 삭제 — `/ai-history-page` 블록은 유지

- [ ] **Step 3: 검증·커밋**

```bash
cd pjh; flutter analyze; flutter test   # 기대: PASS
git status --short                      # app_router.dart + 삭제 9건만, 금지 경로 없음
git add -A pjh/lib/features/emotion pjh/lib/core/navigation/app_router.dart
git commit -F <메시지파일>   # "Sprint1-STEP4: 죽은 코드 삭제(emotion_calendar·legacy 8종·중복 라우트 /ai-history)"
```

- [ ] **Step 4: STEP 4 보고**

---

## Sprint 1 완료 기준 (전체 커밋 후 최종 확인)

- [ ] `flutter analyze` 0 error / 테스트: 신규 실패 0 + auth_bloc_test 전체 그린 + 신규(policy 5, bloc 4) 통과 (health·feed 사전 실패 18→auth분 제외 잔여분은 베이스라인 동결)
- [ ] 금지 파일 diff 0줄 증명: `git diff 75e34b1..HEAD --stat -- pjh/lib/features/home pjh/lib/features/social/presentation/pages/home_page.dart pjh/lib/features/emotion/presentation/pages/emotion_loading_page.dart pjh/lib/features/emotion/presentation/pages/health_loading_page.dart pjh/lib/features/emotion/presentation/widgets/ai_analysis_loading_widget.dart pjh/lib/features/emotion/presentation/widgets/emotion_loading_widget.dart` → 출력 없음
- [ ] 재분석 버튼 미노출 (코드 검증 + 1-D 실기기 시나리오)
- [ ] 계정 삭제→복구 E2E 문서 전달 (migration 수동 실행은 사용자)
- [ ] 잔여 `Color(0x` grep 수치 보고 (홈·로딩·legacy·토큰 정의처 제외 기준)
- [ ] 파스텔 토큰 9종 추가 + my 계열 26곳 치환 완료 / 보류 색상 목록 보고

## 별도 트랙 인계 목록 (이번 범위 외 — 최종 보고에 포함)

1. Apple token revoke (Apple 토큰 저장 필요 — iOS/맥 트랙)
2. 탈퇴 사용자 콘텐츠의 앱 측 "탈퇴한 사용자" 표시명 fallback (채팅·피드)
   — 단, 30일 purge 시 chat_messages가 CASCADE로 영구 삭제되는 것은 **의도된 동작** (유예 기간에만 대화 유지)
3. chat_rooms.created_by CASCADE — 탈퇴자 생성 채팅방이 purge 시 통째 소실(잔여 참여자 대화 포함). 현상 유지, **Sprint 5에서 SET NULL 전환 검토**
4. STEP 3 보류 색상 치환 여부 (구분선 근사색·경고 갈색 계열·그림자·FF6B00·emotion_chart 파스텔·next_action_card F1EFE8)
5. 기존 `successColor` 등과 신규 `success` 토큰 통폐합
6. 사전 존재 테스트 실패 잔여분 수리 — health_usecases_test(registerFallbackValue 누락)·feed_bloc_test(Supabase 싱글톤 초기화) → Sprint 5 테스트 정비(24-test-automation)로 인계
