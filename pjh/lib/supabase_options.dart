// Supabase 설정 파일
// 실제 프로젝트에서는 환경변수나 .env 파일을 사용하세요

class SupabaseOptions {
  // 실제 Supabase 프로젝트 정보
  static const String supabaseUrl = 'https://qiioqzhaxqgvxjbfsjnd.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpaW9xemhheHFndnhqYmZzam5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg4NTkwNjgsImV4cCI6MjA3NDQzNTA2OH0.fXnVMcKcAxMKiYj_T5W5FKZfwIv3OGjE2kWXAgQZiWs';

  // ✅ 실제 Supabase 프로젝트로 설정 완료
  // 프로젝트: qiioqzhaxqgvxjbfsjnd.supabase.co

  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL' &&
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
  }
}