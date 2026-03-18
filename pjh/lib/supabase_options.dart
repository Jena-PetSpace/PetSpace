import 'config/secrets.dart';

class SupabaseOptions {
  static String get supabaseUrl => Secrets.supabaseUrl;
  static String get supabaseAnonKey => Secrets.supabaseAnonKey;

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseUrl != 'YOUR_SUPABASE_URL' &&
        supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
  }
}
