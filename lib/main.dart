import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/app/app.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/core/services/location_service.dart';
import 'package:hsro/core/services/secure_auth_storage.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/auth/view/taxi_auth_gate_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_availability_service.dart';
import 'package:hsro/features/taxi/services/taxi_push_messaging.dart';
import 'package:hsro/features/taxi/services/taxi_push_service.dart';
import 'package:hsro/features/taxi/widgets/taxi_push_banner.dart';
import 'package:hsro/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        reviewEmails: EnvConfig.authReviewEmails,
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
  // 서버 스위치로 홈의 택시 메뉴를 켜고 끈다. 저장된 값만 읽고 네트워크는 기다리지 않는다.
  Get.put(
    await TaxiAvailabilityService(authService: authService).init(),
    permanent: true,
  );
  await _initTaxiPush(authService);
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

/// 택시팟 푸시 알림. Firebase를 쓸 수 없으면 알림 없이 앱을 그대로 띄운다.
Future<void> _initTaxiPush(AuthService authService) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final service = TaxiPushService(
      messaging: FirebaseTaxiPushMessaging(),
      repository: TaxiRepository(
        client: AuthenticatedApiClient(authService: authService),
      ),
      preferences: await SharedPreferences.getInstance(),
      openTaxi: () => Get.to(() => const TaxiAuthGateView()),
      showBanner: (message, onTap) {
        final overlay = Get.key.currentState?.overlay;
        if (overlay == null) return;
        showTaxiPushBanner(
          overlay,
          title: message.title ?? '택시팟',
          body: message.body ?? '새 알림이 도착했어요.',
          onTap: onTap,
        );
      },
    );
    Get.put<TaxiPushService>(await service.init(), permanent: true);
  } catch (_) {}
}
