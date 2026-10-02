import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    await dotenv.load(fileName: 'assets/.env');
  }

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://hotong.click';
  static String get naverMapClientId => dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';
  static String get supabaseProjectUrl =>
      dotenv.env['SUPABASE_PROJECT_URL']?.trim() ?? '';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
  static Set<String> get authTestEmails =>
      _emailSet('APP_AUTH_TEST_EMAILS');

  /// 앱 심사용 계정. 인증번호 메일 대신 서버가 고정 코드를 인증번호로 바꿔 준다.
  static Set<String> get authReviewEmails =>
      _emailSet('APP_AUTH_REVIEW_EMAILS');

  static Set<String> _emailSet(String key) =>
      dotenv.env[key]
          ?.split(',')
          .map((email) => email.trim().toLowerCase())
          .where((email) => email.isNotEmpty)
          .toSet() ??
      const <String>{};

  static bool get hasSupabaseAuthConfiguration =>
      supabaseProjectUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty;
}
