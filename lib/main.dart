import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/app/app.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/core/services/location_service.dart';
import 'package:hsro/core/services/secure_auth_storage.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 먼저 로드
  await dotenv.load(fileName: 'assets/.env');

  AuthService authService;
  if (EnvConfig.hasSupabaseAuthConfiguration) {
    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseProjectUrl,
        publishableKey: EnvConfig.supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureAuthStorage(),
          autoRefreshToken: true,
          detectSessionInUri: false,
        ),
      );
      authService = await AuthService(
        Supabase.instance.client,
        allowedTestEmails: EnvConfig.authTestEmails,
      ).init();
    } catch (_) {
      authService = await AuthService.unavailable(
        '인증 설정을 불러오지 못했습니다.',
      ).init();
    }
  } else {
    authService = await AuthService.unavailable(
      'Supabase 인증 설정이 필요합니다.',
    ).init();
  }
  Get.put<AuthService>(authService, permanent: true);
  await FlutterNaverMap().init(
      clientId: EnvConfig.naverMapClientId,
      onAuthFailed: (ex) => switch (ex) {
            NQuotaExceededException(:final message) =>
              print("사용량 초과 (message: $message)"),
            NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException() =>
              print("인증 실패: $ex"),
          });

  print("앱 시작");
  // 위치 서비스 초기화
  await LocationService().initLocationService();
  // 화면 자동 회전 비활성화 - 세로 모드만 허용
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Settings ViewModel 등록
  Get.put(SettingsViewModel(), permanent: true);

  // RouteObserver 등록
  Get.put(RouteObserver<PageRoute>(), permanent: true);

  await BusTimesLoader.updateBusTimesIfNeeded();

  runApp(const MyApp());
  unawaited(BusStaticDataLoader.updateIfNeeded());
}
