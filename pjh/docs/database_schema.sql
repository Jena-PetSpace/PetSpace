-- 멍냥다이어리 Supabase 데이터베이스 스키마
-- 실행 순서대로 작성됨

-- 1. Users 테이블 확장 (auth.users는 Supabase에서 자동 생성)
-- Users 프로필 테이블 생성
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  provider TEXT, -- 'google', 'kakao'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS (Row Level Security) 활성화
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 프로필만 보고 수정할 수 있음
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- 인증된 사용자는 자신의 프로필을 생성할 수 있음
CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- 2. Pets 테이블 (반려동물 정보)
CREATE TABLE IF NOT EXISTS public.pets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('dog', 'cat')),
  breed TEXT,
  birth_date DATE,
  gender TEXT CHECK (gender IN ('male', 'female')),
  avatar_url TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 활성화
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 반려동물만 관리할 수 있음
CREATE POLICY "Users can manage own pets" ON public.pets
  FOR ALL USING (auth.uid() = user_id);

-- 모든 사용자는 다른 사용자의 반려동물을 볼 수 있음 (소셜 기능용)
CREATE POLICY "Users can view all pets" ON public.pets
  FOR SELECT USING (true);

-- 3. Emotion Analyses 테이블 (감정 분석 결과)
CREATE TABLE IF NOT EXISTS public.emotion_analyses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  happiness FLOAT NOT NULL CHECK (happiness >= 0 AND happiness <= 1),
  sadness FLOAT NOT NULL CHECK (sadness >= 0 AND sadness <= 1),
  anger FLOAT NOT NULL CHECK (anger >= 0 AND anger <= 1),
  fear FLOAT NOT NULL CHECK (fear >= 0 AND fear <= 1),
  surprise FLOAT NOT NULL CHECK (surprise >= 0 AND surprise <= 1),
  analysis_text TEXT,
  ai_provider TEXT DEFAULT 'gemini',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 활성화
ALTER TABLE public.emotion_analyses ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 감정 분석 결과만 관리할 수 있음
CREATE POLICY "Users can manage own emotion analyses" ON public.emotion_analyses
  FOR ALL USING (auth.uid() = user_id);

-- 4. Social Posts 테이블 (소셜 기능)
CREATE TABLE IF NOT EXISTS public.social_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE,
  emotion_analysis_id UUID REFERENCES public.emotion_analyses(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 활성화
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 포스트만 수정/삭제할 수 있음
CREATE POLICY "Users can manage own posts" ON public.social_posts
  FOR ALL USING (auth.uid() = user_id);

-- 모든 사용자는 공개 포스트를 볼 수 있음
CREATE POLICY "Users can view public posts" ON public.social_posts
  FOR SELECT USING (is_public = true OR auth.uid() = user_id);

-- 5. Post Likes 테이블
CREATE TABLE IF NOT EXISTS public.post_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.social_posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

-- RLS 활성화
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 좋아요만 관리할 수 있음
CREATE POLICY "Users can manage own likes" ON public.post_likes
  FOR ALL USING (auth.uid() = user_id);

-- 6. Post Comments 테이블
CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.social_posts(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 활성화
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 댓글만 수정/삭제할 수 있음
CREATE POLICY "Users can manage own comments" ON public.post_comments
  FOR ALL USING (auth.uid() = user_id);

-- 모든 사용자는 공개 포스트의 댓글을 볼 수 있음
CREATE POLICY "Users can view comments on public posts" ON public.post_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.social_posts
      WHERE id = post_id AND (is_public = true OR user_id = auth.uid())
    )
  );

-- 7. Storage 버킷 생성 (이미지 저장용)
-- Supabase Dashboard에서 실행:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('pet-photos', 'pet-photos', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('emotion-images', 'emotion-images', true);

-- 8. 함수 생성 - 좋아요 수 업데이트
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.social_posts
    SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.social_posts
    SET likes_count = likes_count - 1
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_update_post_likes_count ON public.post_likes;
CREATE TRIGGER trigger_update_post_likes_count
  AFTER INSERT OR DELETE ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- 9. 함수 생성 - 댓글 수 업데이트
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.social_posts
    SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.social_posts
    SET comments_count = comments_count - 1
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_update_post_comments_count ON public.post_comments;
CREATE TRIGGER trigger_update_post_comments_count
  AFTER INSERT OR DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- 10. 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_analyses_user_id ON public.emotion_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_analyses_pet_id ON public.emotion_analyses(pet_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_user_id ON public.social_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_created_at ON public.social_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_posts_is_public ON public.social_posts(is_public);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_post ON public.post_likes(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id);

-- 11. 사용자 프로필 자동 생성 함수
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, display_name, provider)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'provider', 'email')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성 - 새 사용자 등록시 프로필 자동 생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();