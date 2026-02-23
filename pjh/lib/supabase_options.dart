// Supabase 설정 파일
// 실제 프로젝트에서는 환경변수나 .env 파일을 사용하세요

class SupabaseOptions {
  // 실제 Supabase 프로젝트 정보
  static const String supabaseUrl = 'https://juukbctqzlrxfnivhgqe.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dWtiY3RxemxyeGZuaXZoZ3FlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MDUyOTEsImV4cCI6MjA4NzM4MTI5MX0.0vZi_Mx2O61WALdpc3nOLIOzBlMA3UB0-LBbz2oz3gI';

  // ✅ 실제 Supabase 프로젝트로 설정 완료 (Jena-PetSpace 회사 계정)
  // 프로젝트: juukbctqzlrxfnivhgqe.supabase.co

  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL' &&
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
  }
}