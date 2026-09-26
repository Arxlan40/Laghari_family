import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Supabase Project URL
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vibpzdmwcfszdoctvxkw.supabase.co',
  );

  /// Supabase Anon / Public Key
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_KlEQMdFFaTwctty0B-SjSg_UwZHjrNT',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    try {
      if (isConfigured) {
        final cleanUrl = supabaseUrl
            .replaceAll('/rest/v1/', '')
            .replaceAll('/rest/v1', '')
            .trim();
        await Supabase.initialize(
          url: cleanUrl,
          publishableKey: supabaseAnonKey,
        );
      }
    } catch (e) {
      // Graceful catch if offline or demo credentials
    }
  }
}
