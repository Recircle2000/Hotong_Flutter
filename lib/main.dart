import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/app/app.dart';
import 'package:hsro/core/services/location_service.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 먼저 로드
  await dotenv.load(fileName: 'assets/.env');
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
}
