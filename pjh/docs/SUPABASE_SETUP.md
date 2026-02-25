# 🗄️ Supabase 데이터베이스 설정 가이드

펫페이스 앱을 위한 Supabase 데이터베이스 설정 방법입니다.

## 📋 필수 설정 단계

### 1. Supabase 프로젝트 생성
1. [Supabase Dashboard](https://supabase.com/dashboard)에서 새 프로젝트 생성
2. 프로젝트 URL과 Anon Key를 `lib/supabase_options.dart`에 설정

### 2. 데이터베이스 스키마 생성
Supabase Dashboard의 SQL Editor에서 `docs/database_schema.sql` 파일의 내용을 실행하세요.

#### 실행 방법:
1. Supabase Dashboard > SQL Editor 메뉴 이동
2. "New query" 클릭
3. `docs/database_schema.sql` 파일의 전체 내용을 복사하여 붙여넣기
4. "Run" 버튼 클릭하여 실행
5. 오류 없이 완료되면 성공

#### 생성되는 테이블들:
- `users` - 사용자 프로필 정보
- `pets` - 반려동물 정보
- `emotion_analyses` - 감정 분석 결과
- `social_posts` - 소셜 포스트
- `post_likes` - 포스트 좋아요
- `post_comments` - 포스트 댓글

#### ⚠️ RLS 정책 업데이트가 필요한 경우:
이미 테이블을 생성했고 RLS 정책만 업데이트하려면, `supabase/policies/` 폴더의 정책 파일들을 실행하세요:

**Users 테이블 RLS 정책 업데이트:**
1. Supabase Dashboard > SQL Editor
2. `supabase/policies/users_rls_policies.sql` 파일 내용 복사
3. 실행

이 파일은 기존 정책을 자동으로 삭제하고 새로운 정책을 적용합니다.

### 3. Storage 버킷 생성
Supabase Dashboard의 Storage 섹션에서 다음 버킷들을 생성하세요:

```sql
-- Storage 버킷 생성
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('pet-photos', 'pet-photos', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('emotion-images', 'emotion-images', true);
```

### 4. Storage 정책 설정
각 버킷에 대한 RLS 정책을 설정하세요:

```sql
-- avatars 버킷 정책
CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- pet-photos 버킷 정책
CREATE POLICY "Users can upload pet photos" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view pet photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'pet-photos');

CREATE POLICY "Users can update own pet photos" ON storage.objects
  FOR UPDATE USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- emotion-images 버킷 정책
CREATE POLICY "Users can upload emotion images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'emotion-images' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view emotion images" ON storage.objects
  FOR SELECT USING (bucket_id = 'emotion-images');

CREATE POLICY "Users can update own emotion images" ON storage.objects
  FOR UPDATE USING (bucket_id = 'emotion-images' AND auth.uid()::text = (storage.foldername(name))[1]);
```

### 5. Authentication 설정
1. Authentication > Settings에서 Google OAuth 설정
2. **Site URL**: `https://your-app.com` (또는 개발 시 `http://localhost:3000`)
3. **Redirect URLs**: 앱의 딥링크 URL 추가

### 6. RLS (Row Level Security) 확인
모든 테이블에 RLS가 활성화되어 있는지 확인하세요:
- 사용자는 자신의 데이터만 수정/삭제 가능
- 공개 데이터는 모든 사용자가 조회 가능

## 🔧 주요 기능별 데이터 플로우

### 사용자 등록/로그인
1. `auth.users` 테이블에 사용자 생성 (Supabase Auth 자동)
2. `users` 테이블에 프로필 자동 생성 (트리거)

### 반려동물 등록
1. 사용자가 반려동물 정보 입력
2. `pets` 테이블에 저장
3. 아바타 이미지는 `pet-photos` 버킷에 업로드

### 감정 분석
1. 사용자가 반려동물 사진 업로드
2. `emotion-images` 버킷에 이미지 저장
3. Gemini AI API로 감정 분석
4. `emotion_analyses` 테이블에 결과 저장

### 소셜 포스팅
1. 감정 분석 결과를 바탕으로 포스트 생성
2. `social_posts` 테이블에 저장
3. 다른 사용자들이 좋아요/댓글 가능

## 📊 데이터베이스 ERD

```
auth.users (Supabase Auth)
├── users (1:1)
├── pets (1:N)
├── emotion_analyses (1:N)
└── social_posts (1:N)
    ├── post_likes (1:N)
    └── post_comments (1:N)

pets (1:N) → emotion_analyses
emotion_analyses (1:1) → social_posts
```

## 🛡️ 보안 고려사항

1. **RLS 정책**: 모든 테이블에 적절한 RLS 정책 적용
2. **Storage 보안**: 사용자별 폴더 구조로 파일 분리
3. **API 키 보안**: Anon Key는 공개되어도 안전하지만, Service Role Key는 서버에서만 사용
4. **데이터 검증**: 클라이언트와 서버 양쪽에서 데이터 유효성 검증

## 🔍 모니터링 및 성능

1. **인덱스**: 자주 쿼리되는 컬럼에 인덱스 생성됨
2. **실시간 업데이트**: Supabase Realtime으로 실시간 데이터 동기화
3. **쿼리 최적화**: JOIN 쿼리 최소화, 필요한 컬럼만 선택

## 📝 개발 팁

1. **데이터 모델링**: `entities` 폴더의 Dart 클래스들과 DB 스키마 일치
2. **타입 안전성**: Supabase의 TypeScript 타입 생성 기능 활용 가능
3. **로컬 개발**: Supabase CLI로 로컬 개발 환경 구축 가능