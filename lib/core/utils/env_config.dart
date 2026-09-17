import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    await dotenv.load(fileName: 'assets/.env');
  }

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  static String get naverMapClientId => dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';
  static String get supabaseProjectUrl =>
      dotenv.env['SUPABASE_PROJECT_URL']?.trim() ?? '';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
  static Set<String> get authTestEmails =>
      dotenv.env['APP_AUTH_TEST_EMAILS']
          ?.split(',')
          .map((email) => email.trim().toLowerCase())
          .where((email) => email.isNotEmpty)
          .toSet() ??
      const <String>{};

  static bool get hasSupabaseAuthConfiguration =>
      supabaseProjectUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty;
}
