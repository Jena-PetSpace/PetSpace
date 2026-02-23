# Supabase SQL 파일 구조

이 폴더는 Supabase 설정을 체계적으로 관리하기 위한 3가지 카테고리로 구성되어 있습니다.

## 📁 폴더 구조

```
supabase/
├── database/              # 데이터베이스 (테이블, 함수, 트리거 등)
│   ├── run_all_database.sql           ← 이 파일 실행!
│   ├── 001_initial_schema.sql
│   ├── 002_rls_policies.sql
│   ├── 003_social_features_extension.sql
│   ├── 004_social_features_rls.sql
│   ├── 005_post_likes_functions.sql
│   ├── 006_add_missing_user_columns.sql
│   ├── 007_update_pets_table.sql
│   ├── add_missing_columns_only.sql
│   ├── complete_migration.sql
│   └── drop_all_tables.sql
│
├── storage_buckets/       # Storage 버킷 설정
│   ├── run_all_storage_buckets.sql     ← 이 파일 실행!
│   └── 01_create_images_bucket.sql
│
└── policies/              # Storage RLS 정책
    ├── run_all_storage_policies.sql    ← 이 파일 실행!
    ├── 01_profile_images_policies.sql
    ├── 02_pet_images_policies.sql
    └── 03_post_images_policies.sql
```

## 🚀 사용 방법

### Supabase SQL Editor에서 실행

**반드시 이 순서대로 실행하세요:**

#### 1단계: Database 설정
```
Supabase Dashboard → SQL Editor → New query
→ database/run_all_database.sql 파일 내용 복사 & 붙여넣기
→ Run 버튼 클릭
```
- ✅ 모든 테이블 생성
- ✅ 인덱스 생성
- ✅ 트리거 생성
- ✅ 함수 생성
- ✅ 데이터베이스 RLS 정책 설정

#### 2단계: Storage Buckets 생성
```
SQL Editor → New query
→ storage_buckets/run_all_storage_buckets.sql 파일 내용 복사 & 붙여넣기
→ Run 버튼 클릭
```
- ✅ `images` 버킷 생성 (public)

#### 3단계: Storage RLS Policies 설정
```
SQL Editor → New query
→ policies/run_all_storage_policies.sql 파일 내용 복사 & 붙여넣기
→ Run 버튼 클릭
```
- ✅ 프로필 이미지 정책
- ✅ 반려동물 이미지 정책
- ✅ 게시물 이미지 정책

## 📝 각 폴더 설명

### 1. database/
**데이터베이스 스키마 및 로직**

- `run_all_database.sql`: 전체 데이터베이스 설정 통합 파일
- `001~007_*.sql`: 순차적 마이그레이션 파일들
  - 테이블 생성
  - RLS 정책
  - 함수 및 트리거
- `add_missing_columns_only.sql`: 임시 마이그레이션
- `complete_migration.sql`: 이전 통합 파일 (참고용)
- `drop_all_tables.sql`: 개발용 테이블 초기화

### 2. storage_buckets/
**Storage 버킷 생성**

- `run_all_storage_buckets.sql`: 모든 버킷 생성 통합 파일
- `01_create_images_bucket.sql`: images 버킷 생성 (프로필/반려동물/게시물 이미지)

### 3. policies/
**Storage RLS 정책**

- `run_all_storage_policies.sql`: 모든 Storage RLS 정책 통합 파일
- `01_profile_images_policies.sql`: 프로필 이미지 정책 (profiles/{user_id}/)
- `02_pet_images_policies.sql`: 반려동물 이미지 정책 (pets/{user_id}/{pet_id}/)
- `03_post_images_policies.sql`: 게시물 이미지 정책 (posts/{user_id}/)

## 🎯 Storage 파일 경로 구조

```
images/
├── profiles/{user_id}/
│   └── profile_xxxxx.jpg
├── pets/{user_id}/{pet_id}/
│   └── pet_xxxxx.jpg
└── posts/{user_id}/
    └── post_xxxxx.jpg
```

## 🔄 업데이트 방법

### 개별 파일 수정 시
1. 해당 폴더의 개별 파일 수정
2. `run_all_*.sql` 통합 파일에도 동일하게 수정
3. Supabase SQL Editor에서 통합 파일 실행

### 새로운 마이그레이션 추가 시
1. `database/` 폴더에 새 파일 추가 (예: `008_xxx.sql`)
2. `database/run_all_database.sql` 파일 하단에 추가
3. Supabase SQL Editor에서 실행

### 새로운 Storage 정책 추가 시
1. `policies/` 폴더에 새 파일 추가 (예: `04_xxx_policies.sql`)
2. `policies/run_all_storage_policies.sql` 파일에 추가
3. Supabase SQL Editor에서 실행

## ⚠️ 주의사항

1. **실행 순서 중요**: database → storage_buckets → policies 순서로 실행
2. **DROP POLICY IF EXISTS**: 기존 정책을 안전하게 삭제 후 재생성
3. **백업 권장**: 프로덕션 DB에서 실행 전 백업 필수
4. **테스트**: 로컬 환경에서 먼저 테스트 후 프로덕션 적용

## ✅ 실행 완료 확인 방법

### Database
```sql
-- 테이블 확인
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- 함수 확인
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public';
```

### Storage Buckets
```
Supabase Dashboard → Storage
→ 'images' 버킷 존재 확인
```

### Storage Policies
```
Supabase Dashboard → Storage → Policies
→ storage.objects 테이블에서 12개 정책 확인
```

## 📞 문제 발생 시

1. **SQL 실행 오류**: 에러 메시지 확인 후 해당 파일 검토
2. **정책 중복**: `DROP POLICY IF EXISTS` 먼저 실행
3. **권한 오류**: Dashboard에서 직접 실행 (CLI가 아닌)

---

**문의사항이 있으시면 이슈 트래커에 등록해주세요!**
