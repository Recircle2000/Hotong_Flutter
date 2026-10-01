import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
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

  /// 택시 채팅 푸시(FCM)용 Firebase 설정. 값이 하나라도 비어 있으면 null이고,
  /// 그때는 푸시 없이 앱의 나머지 기능만 동작한다.
  static FirebaseOptions? get firebaseOptions {
    String read(String key) => dotenv.env[key]?.trim() ?? '';
    final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
    final apiKey = read('FIREBASE_${platform}_API_KEY');
    final appId = read('FIREBASE_${platform}_APP_ID');
    final senderId = read('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = read('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        senderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }
    final bundleId = read('FIREBASE_IOS_BUNDLE_ID');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: Platform.isIOS && bundleId.isNotEmpty ? bundleId : null,
    );
  }
}
