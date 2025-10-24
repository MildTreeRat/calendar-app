/// Supabase Configuration
///
/// Replace these placeholder values with your actual Supabase credentials.
/// Find these in your Supabase dashboard: Project Settings > API
///
/// ⚠️ SECURITY WARNING:
/// - NEVER commit actual credentials to version control
/// - Use environment variables or flutter_dotenv for production
/// - Only use anon key (never service_role key) in client apps

class SupabaseConfig {
  /// Your Supabase project URL
  /// Example: 'https://abcdefghijklmnop.supabase.co'
  static const String url = 'YOUR_SUPABASE_URL_HERE';

  /// Your Supabase anon (public) key
  /// This is safe to use in client applications with RLS enabled
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
}
