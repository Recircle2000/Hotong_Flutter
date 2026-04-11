import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    await dotenv.load(fileName: 'assets/.env');
  }

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  static String get naverMapClientId => dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';
}
