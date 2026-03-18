# PetSpace 개발 세션 종합 정리

> 기준일: 2026-03-18  
> 최신 커밋: `215f4c8`  
> 전체 커밋 수: 29개 (이번 세션 기준)

---

## 1. 보안 처리 완료

### Google API 키 노출 사고 대응

**발생**: GitHub Secret scanning이 `api_config.dart`, `.env.example`에서 API 키 4건 감지

| Alert # | 키 접두사 | 파일 | 처리 |
|---------|---------|------|------|
| #1 | `AIzaSyAG9...` | `api_config.dart` | 히스토리 삭제 + Revoked ✅ |
| #2 | `AIzaSyC98...` | `.env.example` | 히스토리 삭제 + Revoked ✅ |
| #3 | `AIzaSyCSV...` | `api_config.dart` | 히스토리 삭제 + Revoked ✅ |
| #4 | `AIzaSyCvd...` | `api_config.dart` | 히스토리 삭제 + Revoked ✅ |

**처리 방법**:
1. `git filter-repo --replace-text`로 전체 히스토리에서 키 교체
2. `git push --force --all`로 원격 히스토리 재작성
3. Google AI Studio에서 노출 키 폐기 (정현 완료)
4. 새 Gemini API 키 `AIzaSyBc6Q5SJV4FgER-6RWzRNyh70qvGuX3rVE` 발급

**현재 키 관리 구조**:
```
secrets.dart (gitignore ← 절대 커밋 금지)
├── supabaseUrl
├── supabaseAnonKey
├── geminiApiKey = 'AIzaSyBc6Q5SJV4FgER-6RWzRNyh70qvGuX3rVE'  ← 로컬만
└── kakaoNativeKey

firebase_options.dart (git 추적)
└── apiKey = 'AIzaSyBc6Q5SJV4FgER-6RWzRNyh70qvGuX3rVE'  ← Firebase Android
```

---

## 2. CI/CD 수정 히스토리

| 문제 | 원인 | 수정 커밋 |
|------|------|---------|
| test job secrets.dart 없음 | build-android job에만 생성 단계 존재 | `fa8f803` |
| 소괄호 불균형 컴파일 에러 | main_navigation, emotion_analysis_page 괄호 오류 | `1032753` |
| dart format 실패 | `--set-exit-if-changed` 포맷 불일치 감지 | `3ff0a00` |

**현재 CI 구조** (`.github/workflows/ci.yml`):
```yaml
jobs:
  test:
    permissions: contents: write   # dart format 자동 커밋용
    steps:
      1. Flutter SDK 설치
      2. secrets.dart 생성 (더미)
      3. flutter pub get
      4. dart format lib/ test/    # 자동 적용 후 [skip ci] 커밋
      5. flutter analyze --no-pub
      6. flutter test (5개 파일, 51케이스)

  build-android: (main push 시만)
      1~4. 동일
      5. flutter build apk --release
      6. APK artifact 업로드 (7일 보관)
```

---

## 3. 기능 개발 완료 목록

### Phase 1~4 (출시 준비 → 코드 품질)

| Phase | 주요 내용 |
|-------|---------|
| Phase 1 | 탭 순서, Health UseCase, MY 프로필 실데이터 |
| Phase 2 | 감정분석 → 피드 공유, 감정 히스토리 캘린더 |
| Phase 3 | 북마크, Realtime 배선, 멀티이미지 뷰어 |
| Phase 4 | emotion_result_page 분리, BLoC 테스트, CI/CD |

### 코드 리뷰 기반 개선 (10년차 관점)

| 카테고리 | 처리 항목 |
|---------|---------|
| 크래시 수정 | EmotionAnalysisBloc registerFactory→LazySingleton |
| 메모리 누수 | FeedBloc StreamSubscription close() override |
| 이미지 업로드 | ImageUploadService auth:null 파라미터 제거 |
| 딥링크 | FCMService _routeFromData + setupInteractedMessage |
| 데드코드 삭제 | HomeBloc, SocialPost, social/User 등 6개 파일 |

### P1~P3 기능 완성

**P1 — 앱 안정성**
- 댓글/팔로우 알림 발송 (PushNotificationService 연결)
- 차단 사용자 피드 필터링 (user_blocks JOIN)
- 커뮤니티 포스트 글쓰기 UI (CreateCommunityPostPage)

**P2 — UX 완성**
- PostDetailPage: 게시글 본문+이미지+댓글 통합
- 피드 탭 검색 버튼 추가
- 프로필 편집 후 캐시 자동 갱신
- 댓글 Realtime 구독 (insert/delete 이벤트)
- 팔로우 알림 발송 이름 전달

**P3 — 품질/최적화**
- 다크모드 전면 완성 (4줄 → 170줄, 17개 컴포넌트)
- Semantics 접근성 6개 화면 적용
- 이미지 캐시 50MB 제한
- FeedBloc 테스트 12케이스 추가

### 추가 기능

| 기능 | 내용 |
|------|------|
| FCM Edge Function | `supabase/functions/send-notification/` |
| 커뮤니티 탭 | 더미 → community_posts 실데이터 |
| 팔로잉 피드 | followingOnly 파라미터 전체 계층 전파 |
| 유저 차단 | user_blocks CRUD + PostCard 차단/해제 |
| Play Store 준비 | build.gradle 릴리즈 서명, proguard-rules.pro |
| Firebase 초기화 | Firebase.initializeApp + 백그라운드 핸들러 |

---

## 4. 테스트 현황

| 파일 | 케이스 |
|------|------|
| `auth_bloc_test.dart` | 11 |
| `emotion_analysis_bloc_test.dart` | 11 |
| `health_usecases_test.dart` | 9 |
| `bookmark_usecases_test.dart` | 8 |
| `feed_bloc_test.dart` | 12 |
| **합계** | **51케이스** |

---

## 5. Supabase 설정 (정현이 직접 필요)

```sql
-- Supabase SQL Editor에서 실행
-- 1. petspace_setup.sql 전체 실행 (또는 아래만 추가)
CREATE TABLE IF NOT EXISTS saved_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own saved posts" ON saved_posts
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- community_posts 테이블 (커뮤니티 글쓰기용)
CREATE TABLE IF NOT EXISTS community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    category VARCHAR(30) NOT NULL,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view" ON community_posts FOR SELECT USING (true);
CREATE POLICY "Author can manage" ON community_posts FOR ALL USING (auth.uid() = author_id);
```

**Edge Function Secrets** (Supabase Dashboard → Settings → Edge Functions):
```
FCM_SERVER_KEY      = Firebase Service Account JSON 문자열
FIREBASE_PROJECT_ID = project-5e5638c5-de70-498d-8f2
```

---

## 6. Play Store 출시 체크리스트

| # | 작업 | 담당 |
|---|------|------|
| ☐ | Supabase SQL 실행 | 정현 |
| ☐ | Edge Function Secret 등록 | 정현 |
| ☐ | `AndroidManifest.xml` POST_NOTIFICATIONS 권한 + FCM 서비스 등록 | 정현 |
| ☐ | 릴리즈 서명 키 생성 → `android/key.properties` 작성 | 정현 |
| ☐ | Google Play Console 계정 ($25) | 정현 |
| ☐ | `flutter build appbundle --release` | 정현 |
| ☐ | Play Store 제출 (스크린샷/설명/개인정보처리방침) | 정현 |

---

## 7. 현재 앱 완성도

| 영역 | 완성도 | 비고 |
|------|--------|------|
| 인증 (카카오/구글/이메일) | 95% | 이메일 인증 비활성화 중 |
| 감정 분석 AI | 100% | Gemini API 연동 완료 |
| 피드 & 소셜 | 98% | 전 기능 구현 완료 |
| 건강관리 | 95% | 데이터 연결 완료 |
| 북마크 | 90% | Supabase 테이블 생성 필요 |
| 채팅 | 90% | 기능 완성, E2E 테스트 필요 |
| 푸시 알림 | 70% | Edge Function Secret 등록 필요 |
| 커뮤니티 | 95% | community_posts 테이블 생성 필요 |
| 다크모드 | 95% | 일부 하드코딩 색상 잔여 |
| Play Store 배포 | 70% | 서명 키 + 제출 필요 |
